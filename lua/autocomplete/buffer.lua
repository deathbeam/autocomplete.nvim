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

local function complete(prefix, cmp_start, items)
    items = vim.tbl_filter(function(item)
        return item.kind ~= 'Snippet'
            and (#prefix == 0 or #vim.fn.matchfuzzy({ item.word }, prefix) > 0)
    end, items)

    if M.config.entry_mapper then
        items = vim.tbl_map(M.config.entry_mapper, items)
    end

    vim.fn.complete(cmp_start + 1, items)
end

local function complete_treesitter(bufnr, prefix, cmp_start)
    -- Check if treesitter is available
    local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
    if not ok or not parsers.has_parser() then
        return
    end

    local locals = require('nvim-treesitter.locals')
    local defs = locals.get_definitions_lookup_table(bufnr)
    local ft = vim.bo[bufnr].filetype
    local items = {}

    for id, entry in pairs(defs) do
        -- FIXME: This is not pretty, the format of the ID is not documented and might change, but its fastest way
        local name = id:match('k_(.+)_%d+_%d+_%d+_%d+$')
        local node = entry.node
        local kind = entry.kind
        if node and kind then
            for _, k in ipairs(vim.lsp.protocol.CompletionItemKind) do
                if string.find(k:lower(), kind:lower()) then
                    kind = k
                    break
                end
            end

            local start_line_node, _, _ = node:start()
            local end_line_node, _, _ = node:end_()

            local full_text = vim.trim(
                vim.api.nvim_buf_get_lines(bufnr, start_line_node, end_line_node + 1, false)[1]
                    or ''
            )

            full_text = '```' .. ft .. '\n' .. full_text .. '\n```'
            items[#items + 1] = {
                word = name,
                kind = kind,
                info = full_text,
                icase = 1,
                dup = 0,
                empty = 0,
            }
        end
    end

    complete(prefix, cmp_start, items)
end

local function complete_lsp(bufnr, prefix, cmp_start, client, char)
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
        -- FIXME: Maybe dont use interal lsp functions? Idk why its not exposed and the parent method is marked as deprecated
        local items = vim.lsp.completion._lsp_to_complete_items(result, '')
        complete(prefix, cmp_start, items)
    end, bufnr)
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

    local prefix, cmp_start = unpack(vim.fn.matchstrpos(line:sub(1, col), '\\k*$'))

    util.debounce(state.entries.completion, M.config.debounce_delay, function()
        local client = util.get_client(args.buf, methods.textDocument_completion)
        if client then
            complete_lsp(args.buf, prefix, cmp_start, client, line:sub(col, col))
        else
            complete_treesitter(args.buf, prefix, cmp_start)
        end
    end)
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
    if not string.find(vim.o.completeopt, 'popup') then
        return
    end

    if not vim.v.event or not vim.v.event.completed_item then
        return
    end

    local cur_item = vim.v.event.completed_item
    local cur_info = vim.fn.complete_info()
    local selected = cur_info.selected

    util.debounce(state.entries.info, M.config.debounce_delay, function()
        local completion_item = vim.tbl_get(cur_item, 'user_data', 'nvim', 'lsp', 'completion_item')
        if not completion_item then
            return
        end

        local client = util.get_client(args.buf, methods.completionItem_resolve)
        if not client then
            return
        end

        return util.request(
            client,
            methods.completionItem_resolve,
            completion_item,
            function(result)
                if
                    not result.documentation
                    or not result.documentation.value
                    or #result.documentation.value == 0
                then
                    return
                end

                local info = vim.fn.complete_info()
                if not info.items or not info.selected or not info.selected == selected then
                    return
                end

                local wininfo =
                    vim.api.nvim__complete_set(selected, { info = result.documentation.value })
                if wininfo.winid and wininfo.bufnr then
                    vim.wo[wininfo.winid].conceallevel = 2
                    vim.wo[wininfo.winid].concealcursor = 'niv'
                    vim.bo[wininfo.bufnr].syntax = 'markdown'
                    vim.treesitter.start(wininfo.bufnr, 'markdown')
                end
            end,
            args.buf
        )
    end)
end

M.config = {
    entry_mapper = nil, -- Custom completion entry mapper
    debounce_delay = 100,
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

    vim.api.nvim_create_autocmd('CompleteChanged', {
        desc = 'Auto show LSP documentation',
        group = group,
        callback = complete_changed,
    })
end

return M
