local util = require('autocomplete.util')
local methods = vim.lsp.protocol.Methods

local M = {}

local state = {
    entries = {
        completion = nil,
        info = nil,
    },
}

local function complete(prefix, cmp_start, items)
    if vim.fn.mode() ~= 'i' then
        return
    end

    items = vim.tbl_filter(function(item)
        return #prefix == 0 or #vim.fn.matchfuzzy({ item.word }, prefix) > 0
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

local function text_changed(args)
    if vim.fn.pumvisible() == 1 then
        return
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col == 0 or #line == 0 then
        return
    end

    local prefix, cmp_start = unpack(vim.fn.matchstrpos(line:sub(1, col), [[\k*$]]))

    util.debounce(state.entries.completion, M.config.debounce_delay, function()
        local client = util.get_client(args.buf, methods.textDocument_completion)
        if client and vim.lsp.completion and vim.lsp.completion.trigger then
            vim.lsp.completion.trigger()
        else
            complete_treesitter(args.buf, prefix, cmp_start)
        end
    end)
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
        local completion_item =
            vim.tbl_get(cur_item or {}, 'user_data', 'nvim', 'lsp', 'completion_item')
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
                local docs = vim.tbl_get(result, 'documentation', 'value')
                if not docs or #docs == 0 then
                    return
                end

                local info = vim.fn.complete_info()
                if not info.items or not info.selected or info.selected ~= selected then
                    return
                end

                local wininfo = vim.api.nvim__complete_set(selected, { info = docs })
                if not wininfo.winid or not wininfo.bufnr then
                    return
                end

                vim.api.nvim_win_set_config(wininfo.winid, {
                    border = M.config.border,
                    focusable = false,
                })

                vim.treesitter.start(wininfo.bufnr, 'markdown')
                vim.wo[wininfo.winid].conceallevel = 3
                vim.wo[wininfo.winid].concealcursor = 'niv'
            end,
            args.buf
        )
    end)
end

M.config = {
    border = nil, -- Documentation border style
    entry_mapper = nil, -- Custom completion entry mapper
    debounce_delay = 100,
}

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', M.config, config or {})
    state.entries.completion = util.entry()
    state.entries.info = util.entry()

    local group = vim.api.nvim_create_augroup('LspCompletion', {})

    vim.api.nvim_create_autocmd('TextChangedI', {
        desc = 'Auto show completion',
        group = group,
        callback = text_changed,
    })

    vim.api.nvim_create_autocmd('CompleteChanged', {
        desc = 'Auto show LSP documentation',
        group = group,
        callback = complete_changed,
    })

    vim.api.nvim_create_autocmd('LspAttach', {
        desc = 'Attach completion events',
        group = group,
        callback = function(event)
            local client = util.get_client(event.buf, methods.textDocument_completion)
            if not client then
                return
            end
            if not vim.lsp.completion or not vim.lsp.completion.enable then
                return
            end
            vim.lsp.completion.enable(true, client.id, event.buf, {
                autotrigger = false,
                convert = function(item)
                    local entry = {
                        abbr = item.label,
                        kind = vim.lsp.protocol.CompletionItemKind[item.kind] or 'Unknown',
                        menu = item.detail or '',
                        icase = 1,
                        dup = 0,
                        empty = 0,
                    }

                    if M.config.entry_mapper then
                        return M.config.entry_mapper(entry)
                    end

                    return entry
                end,
            })
        end,
    })
end

return M
