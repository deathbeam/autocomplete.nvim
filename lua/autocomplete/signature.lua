local util = require('autocomplete.util')
local methods = vim.lsp.protocol.Methods

local M = {}

local state = {
    entry = nil,
    ns = nil,
}

local function signature_handler(client, result, bufnr)
    local triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters
    local ft = vim.bo[bufnr].filetype
    local lines, hl = vim.lsp.util.convert_signature_help_to_markdown_lines(result, ft, triggers)
    if not lines or #lines == 0 then
        return
    end

    lines = { unpack(lines, 1, 3) }
    local fbuf = vim.lsp.util.open_floating_preview(lines, 'markdown', {
        focusable = false,
        close_events = { 'CursorMoved', 'CursorMovedI', 'BufLeave', 'BufWinLeave' },
        border = M.config.border,
        max_width = M.config.width,
        max_height = M.config.height,
        anchor_bias = 'above',
    })

    if hl then
        vim.api.nvim_buf_add_highlight(
            fbuf,
            state.ns,
            'PmenuSel',
            vim.startswith(lines[1], '```') and 1 or 0,
            unpack(hl)
        )
    end
end

local function cursor_moved(client, bufnr)
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
end

return M
