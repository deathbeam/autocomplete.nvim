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

local function complete_treesitter(bufnr, cmp_start)
    local items = {}
    local ok, locals = pcall(require, 'nvim-treesitter.locals')
    if not ok then
        return items
    end

    local defs = locals.get_definitions(bufnr)

    for _, def in ipairs(defs) do
        local node
        local kind
        for k, cap in pairs(def) do
            if k ~= 'associated' then
                node = cap.node
                kind = k
                break
            end
        end

        local lsp_kind
        for _, k in ipairs(vim.lsp.protocol.CompletionItemKind) do
            vim.print(k)
            if k:lower() == kind:lower() then
                lsp_kind = k
                break
            end
        end

        if not lsp_kind then
            for _, k in ipairs(vim.lsp.protocol.CompletionItemKind) do
                if string.find(k:lower(), kind:lower()) then
                    lsp_kind = k
                    break
                end
            end
        end

        if not lsp_kind then
            lsp_kind = 'Unknown'
        end

        if node then
            items[#items + 1] = {
                word = vim.treesitter.get_node_text(node, 0),
                kind = lsp_kind,
                icase = 1,
                dup = 1,
                empty = 1,
            }
        end
    end

    if M.config.entry_mapper then
        items = vim.tbl_map(M.config.entry_mapper, items)
    end

    if vim.fn.mode() == 'i' then
        vim.fn.complete(cmp_start + 1, items)
    end
end

local function complete_lsp(bufnr, cmp_start, client, char)
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

    local params =
        vim.lsp.util.make_position_params(vim.api.nvim_get_current_win(), client.offset_encoding)
    params.context = context
    return util.request(client, methods.textDocument_completion, params, function(result)
        local items = vim.lsp._completion._lsp_to_complete_items(result, '')
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
end

local function complete_done(args)
    if
        not vim.v
        or not vim.v.completed_item
        or not vim.v.completed_item.user_data
        or not vim.v.completed_item.user_data.nvim
        or not vim.v.completed_item.user_data.nvim.lsp
        or not vim.v.completed_item.user_data.nvim.lsp.completion_item
    then
        return
    end

    local client = util.get_client(args.buf, methods.completionItem_resolve)
    if not client then
        return
    end

    local item = vim.v.completed_item.user_data.nvim.lsp.completion_item

    if vim.tbl_isempty(item.additionalTextEdits or {}) then
        util.debounce(state.entries.edit, M.config.debounce_delay, function()
            return util.request(client, methods.completionItem_resolve, item, function(result)
                if vim.tbl_isempty(result.additionalTextEdits or {}) then
                    return
                end

                vim.lsp.util.apply_text_edits(
                    result.additionalTextEdits,
                    args.buf,
                    client.offset_encoding
                )
            end, args.buf)
        end)
    else
        vim.lsp.util.apply_text_edits(item.additionalTextEdits, args.buf, client.offset_encoding)
    end

    state.skip_next = true
end

local function complete_changed(args)
    if
        not vim.v.event
        or not vim.v.event.completed_item
        or not vim.v.event.completed_item.user_data
        or not vim.v.event.completed_item.user_data.nvim
        or not vim.v.event.completed_item.user_data.nvim.lsp
        or not vim.v.event.completed_item.user_data.nvim.lsp.completion_item
    then
        return
    end

    local client = util.get_client(args.buf, methods.completionItem_resolve)
    if not client then
        return
    end

    local item = vim.v.event.completed_item.user_data.nvim.lsp.completion_item
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

            if result.documentation and result.documentation.value then
                local value = result.documentation.value
                local wininfo = vim.api.nvim_complete_set(selected, { info = value })
                if wininfo.winid and wininfo.bufnr then
                    vim.wo[wininfo.winid].conceallevel = 2
                    vim.wo[wininfo.winid].concealcursor = 'niv'
                    vim.bo[wininfo.bufnr].syntax = 'markdown'
                end
            end
        end, args.buf)
    end)
end

local function text_changed(args)
    if vim.fn.pumvisible() == 1 then
        state.skip_next = false
        return
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col == 0 or #line == 0 then
        return
    end

    local cmp_start = vim.fn.match(line:sub(1, col), '\\k*$')

    util.debounce(state.entries.completion, M.config.debounce_delay, function()
        local client = util.get_client(args.buf, methods.textDocument_completion)
        if client then
            complete_lsp(args.buf, cmp_start, client, line:sub(col, col))
        else
            complete_treesitter(args.buf, cmp_start)
        end
    end)
end

M.config = {
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
        desc = 'Auto show completion',
        group = group,
        callback = text_changed,
    })

    vim.api.nvim_create_autocmd('CompleteDone', {
        desc = 'Auto apply LSP completion edits after selection',
        group = group,
        callback = complete_done,
    })

    if string.find(vim.o.completeopt, 'popup') then
        vim.api.nvim_create_autocmd('CompleteChanged', {
            desc = 'Auto show LSP documentation',
            group = group,
            callback = complete_changed,
        })
    end
end

return M