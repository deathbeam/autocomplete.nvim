local util = require('autocomplete.util')
local methods = vim.lsp.protocol.Methods

local M = {}

local state = {
    entry = nil,
    ns = nil,
    window = {
        id = nil,
        bufnr = nil,
    },
}

local function open_win(lines)
    if not state.window.bufnr or not vim.api.nvim_buf_is_valid(state.window.bufnr) then
        state.window.bufnr = vim.api.nvim_create_buf(false, true)
    end

    if not state.window.id or not vim.api.nvim_win_is_valid(state.window.id) then
        local ft = 'markdown'
        local lines_to_set = { unpack(lines, 1, 3) }
        if vim.startswith(lines[1], '```') then
            local found = lines[1]:gsub('```', '')
            if ft ~= '' then
                ft = found
            end
            lines_to_set = { lines[2] }
        end

        local width, height = vim.lsp.util._make_floating_popup_size(lines_to_set, {
            max_width = M.config.width,
            max_height = M.config.height,
        })

        local options = vim.lsp.util.make_floating_popup_options(width, height, {
            focusable = false,
            border = M.config.border,
            anchor_bias = 'above',
        })

        state.window.id = vim.api.nvim_open_win(state.window.bufnr, false, options)
        vim.wo[state.window.id].wrap = true
        vim.wo[state.window.id].linebreak = true
        vim.wo[state.window.id].breakindent = false
        vim.bo[state.window.bufnr].syntax = ft
        vim.api.nvim_buf_set_lines(state.window.bufnr, 0, -1, false, lines_to_set)
    end
end

local function close_win()
    if state.window.id and vim.api.nvim_win_is_valid(state.window.id) then
        vim.api.nvim_win_close(state.window.id, true)
        state.window.id = nil
    end
end

local function signature_handler(client, result, bufnr)
    local triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters
    local ft = vim.bo[bufnr].filetype
    local lines, hl = vim.lsp.util.convert_signature_help_to_markdown_lines(result, ft, triggers)
    if not lines or #lines == 0 then
        close_win()
        return
    end

    open_win(lines)
    if hl then
        vim.api.nvim_buf_add_highlight(state.window.bufnr, state.ns, 'PmenuSel', 0, unpack(hl))
    end
end

local function cursor_moved(client, bufnr)
    close_win()

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col == 0 or #line == 0 then
        return
    end

    local before_line = line:sub(1, col)

    -- Try to find signature help trigger character in current line
    for _, c in ipairs(client.server_capabilities.signatureHelpProvider.triggerCharacters or {}) do
        if string.find(before_line, '[' .. c .. ']') then
            local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
            params.context = {
                triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
                triggerCharacter = c,
            }

            util.debounce(state.entry, M.config.debounce_delay, function()
                return util.request(
                    client,
                    methods.textDocument_signatureHelp,
                    params,
                    function(result)
                        signature_handler(client, result, bufnr)
                    end,
                    bufnr
                )
            end)

            return
        end
    end
end

M.config = {
    border = nil, -- Signature border style
    width = 80, -- Max width of signature window
    height = 25, -- Max height of signature window
    debounce_delay = 100,
}

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', M.config, config or {})
    state.ns = vim.api.nvim_create_namespace('LspSignatureHelp')
    state.entry = util.entry()
    local group = vim.api.nvim_create_augroup('LspSignatureHelp', {})

    vim.api.nvim_create_autocmd('CursorMovedI', {
        desc = 'Auto show LSP signature help',
        group = group,
        callback = util.with_client(cursor_moved, methods.textDocument_signatureHelp),
    })

    vim.api.nvim_create_autocmd('CursorMoved', {
        desc = 'Auto hide LSP signature help',
        group = group,
        callback = close_win,
    })
end

return M
