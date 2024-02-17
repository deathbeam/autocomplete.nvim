local util = require('autocomplete.util')
local methods = vim.lsp.protocol.Methods

local M = {}

local state = {
    ns = nil,
    signature_window = nil,
}

local function close_signature_window()
    if state.signature_window and vim.api.nvim_win_is_valid(state.signature_window) then
        vim.api.nvim_win_close(state.signature_window, true)
        state.signature_window = nil
    end
end

local function signature_handler(client, result, ctx)
    local triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters
    local ft = vim.bo[ctx.bufnr].filetype
    local lines, hl = vim.lsp.util.convert_signature_help_to_markdown_lines(result, ft, triggers)
    if not lines or vim.tbl_isempty(lines) then
        close_signature_window()
        return
    end
    lines = { unpack(lines, 1, 3) }

    local fbuf, fwin = vim.lsp.util.open_floating_preview(lines, 'markdown', {
        focusable = false,
        close_events = { 'CursorMoved', 'BufLeave', 'BufWinLeave' },
        border = M.config.border,
    })

    if hl then
        vim.api.nvim_buf_add_highlight(fbuf, state.ns, 'PmenuSel', vim.startswith(lines[1], '```') and 1 or 0, unpack(hl))
    end

    state.signature_window = fwin
end

local function text_changed(client, bufnr)
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col == 0 or #line == 0 then
        return
    end

    local before_line = line:sub(1, col)

    -- Try to find signature help trigger character in current line
    for _, c in ipairs(client.server_capabilities.signatureHelpProvider.triggerCharacters or {}) do
        if string.find(before_line, "[" .. c .. "]") then
            local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
            params.context = {
                triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
                triggerCharacter = c
            }

            util.debounce('signature', M.config.debounce_delay, function()
                return util.request(client, methods.textDocument_signatureHelp, params, function (err, result, ctx)
                    if err or not result or not vim.api.nvim_buf_is_valid(ctx.bufnr) or not vim.fn.mode() == 'i' then
                        return
                    end

                    signature_handler(client,  result, ctx)
                end, bufnr)
            end)

            return
        end
    end

    close_signature_window()
end

M.config = {
    border = nil, -- Signature border style
    debounce_delay = 100
}

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', M.config, config or {})
    state.ns = vim.api.nvim_create_namespace('LspSignatureHelp')
    local group = vim.api.nvim_create_augroup('LspSignatureHelp', {})

    vim.api.nvim_create_autocmd('CursorMovedI', {
        desc = 'Auto show LSP signature help',
        group = group,
        callback = util.with_client(text_changed, methods.textDocument_signatureHelp)
    })
end

return M
