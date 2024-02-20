local util = require('autocomplete.util')
local methods = vim.lsp.protocol.Methods

local M = {}

local state = {
    skip_next = false,
    entries = {
        completion = nil,
        info = nil,
        edit = nil,
    },
}

local function complete_done(client, bufnr)
    local item = vim.tbl_get(vim.v, 'completed_item', 'user_data', 'nvim', 'lsp', 'completion_item')
    if not item then
        return
    end

    if vim.tbl_isempty(item.additionalTextEdits or {}) then
        util.debounce(state.entries.edit, M.config.debounce_delay, function()
            return util.request(client, methods.completionItem_resolve, item, function(result)
                if vim.tbl_isempty(result.additionalTextEdits or {}) then
                    return
                end

                vim.lsp.util.apply_text_edits(
                    result.additionalTextEdits,
                    bufnr,
                    client.offset_encoding
                )
            end, bufnr)
        end)
    else
        vim.lsp.util.apply_text_edits(item.additionalTextEdits, bufnr, client.offset_encoding)
    end

    state.skip_next = true
end

local function complete_changed(client, bufnr)
    local item =
        vim.tbl_get(vim.v.event, 'completed_item', 'user_data', 'nvim', 'lsp', 'completion_item')
    if not item then
        return
    end

    local data = vim.fn.complete_info()
    local selected = data.selected

    util.debounce(state.entries.info, M.config.debounce_delay, function()
        return util.request(client, methods.completionItem_resolve, item, function(result)
            local info = vim.fn.complete_info()

            -- FIXME: Preview popup do not auto resizes to fit new content so have to reset it like this
            if info.preview_winid and vim.api.nvim_win_is_valid(info.preview_winid) then
                vim.api.nvim_win_close(info.preview_winid, true)
            end

            if not info.items or not info.selected or not info.selected == selected then
                return
            end

            local value = vim.tbl_get(result, 'documentation', 'value')
            if value then
                local wininfo = vim.api.nvim_complete_set(selected, { info = value })
                if wininfo.winid and wininfo.bufnr then
                    vim.wo[wininfo.winid].conceallevel = 2
                    vim.wo[wininfo.winid].concealcursor = 'niv'
                    vim.bo[wininfo.bufnr].syntax = 'markdown'
                end
            end
        end, bufnr)
    end)
end

local function text_changed(client, bufnr)
    if vim.fn.pumvisible() == 1 then
        state.skip_next = false
        return
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col == 0 or #line == 0 then
        return
    end

    local char = line:sub(col, col)
    local prefix, cmp_start = unpack(vim.fn.matchstrpos(line:sub(1, col), '\\k*$'))
    prefix = M.config.server_side_filtering and '' or prefix

    local context = {
        triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked,
        triggerCharacter = '',
    }

    -- Check if we are triggering completion automatically or on trigger character
    if
        vim.tbl_contains(
            client.server_capabilities.completionProvider.triggerCharacters or {},
            char
        )
    then
        context = {
            triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
            triggerCharacter = char,
        }
    else
        -- We do not want to trigger completion again if we just accepted a completion
        -- We check it here because trigger characters call complete done
        if state.skip_next then
            state.skip_next = false
            return
        end
    end

    util.debounce(state.entries.completion, M.config.debounce_delay, function()
        local params = vim.lsp.util.make_position_params(
            vim.api.nvim_get_current_win(),
            client.offset_encoding
        )
        params.context = context
        return util.request(client, methods.textDocument_completion, params, function(result)
            local items = vim.lsp._completion._lsp_to_complete_items(result, prefix)
            items = vim.tbl_filter(function(item)
                return item.kind ~= 'Snippet'
            end, items)
            if M.config.entry_mapper then
                items = vim.tbl_map(M.config.entry_mapper, items)
            end

            if vim.fn.mode() == 'i' then
                vim.fn.complete(cmp_start + 1, items)
            end
        end, bufnr)
    end)
end

M.config = {
    server_side_filtering = true, -- Use LSP filtering instead of vim's
    entry_mapper = nil, -- Custom completion entry mapper
    debounce_delay = 100,
}

M.capabilities = {
    textDocument = {
        completion = {
            completionItem = {
                -- Fetch additional info for completion items
                resolveSupport = {
                    properties = {
                        'documentation',
                        'detail',
                        'additionalTextEdits',
                    },
                },
            },
        },
    },
}

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', M.config, config or {})
    state.entries.completion = util.entry()
    state.entries.info = util.entry()
    state.entries.edit = util.entry()

    local group = vim.api.nvim_create_augroup('LspCompletion', {})

    vim.api.nvim_create_autocmd('TextChangedI', {
        desc = 'Auto show LSP completion',
        group = group,
        callback = util.with_client(text_changed, methods.textDocument_completion),
    })

    vim.api.nvim_create_autocmd('CompleteDone', {
        desc = 'Auto apply LSP completion edits after selection',
        group = group,
        callback = util.with_client(complete_done, methods.textDocument_completion),
    })

    vim.api.nvim_create_autocmd('CompleteChanged', {
        desc = 'Auto update LSP completion info',
        group = group,
        callback = util.with_client(complete_changed, methods.textDocument_completion),
    })
end

return M
