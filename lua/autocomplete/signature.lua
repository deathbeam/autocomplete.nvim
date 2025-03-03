local util = require('autocomplete.util')
local methods = vim.lsp.protocol.Methods

local M = {}

M.config = {
    border = nil, -- Signature border style
    width = 80, -- Max width of signature window
    height = 25, -- Max height of signature window
    debounce_delay = 100,
}

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', M.config, config or {})

    local entry = util.entry()
    vim.api.nvim_create_autocmd({ 'CursorMovedI', 'InsertEnter' }, {
        desc = 'Auto show LSP signature help',
        group = vim.api.nvim_create_augroup('autocomplete-signature', {}),
        callback = function(args)
            local line = vim.api.nvim_get_current_line()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            if col == 0 or #line == 0 then
                return
            end

            local client = util.get_client(args.buf, methods.textDocument_signatureHelp)
            if not client then
                return
            end

            local before_line = line:sub(1, col)
            local has_trigger_char = vim.iter(
                client.server_capabilities.signatureHelpProvider.triggerCharacters or {}
            )
                :filter(function(c)
                    return string.find(before_line, '[' .. c .. ']') ~= nil
                end)
                :next() ~= nil

            if not has_trigger_char then
                return
            end

            util.debounce(entry, M.config.debounce_delay, function()
                vim.lsp.buf.signature_help({
                    focusable = false,
                    close_events = { 'CursorMoved', 'CursorMovedI', 'BufLeave', 'BufWinLeave' },
                    border = M.config.border,
                    max_width = M.config.width,
                    max_height = M.config.height,
                    anchor_bias = 'above',
                })
            end)
        end,
    })
end

return M
