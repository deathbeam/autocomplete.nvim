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

    local fbuf = vim.lsp.util.open_floating_preview(lines, 'markdown', {
        focusable = false,
        close_events = { 'CursorMoved', 'CursorMovedI', 'BufLeave', 'BufWinLeave' },
        border = M.config.border,
        max_width = M.config.width,
        max_height = M.config.height,
        anchor_bias = 'above',
    })

    -- Highlight the active parameter.
    if hl then
        vim.highlight.range(
            fbuf,
            state.ns,
            'LspSignatureActiveParameter',
            { hl[1], hl[2] },
            { hl[3], hl[4] }
        )
    end
end

local function cursor_moved(args)
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

    -- Try to find signature help trigger character in current line
    for _, c in ipairs(client.server_capabilities.signatureHelpProvider.triggerCharacters or {}) do
        if string.find(before_line, '[' .. c .. ']') then
            local params = vim.lsp.util.make_position_params(
                vim.api.nvim_get_current_win(),
                client.offset_encoding
            )
            params.context = {
                isRetrigger = true,
                triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
                triggerCharacter = c,
            }

            util.debounce(state.entry, M.config.debounce_delay, function()
                return util.request(
                    client,
                    methods.textDocument_signatureHelp,
                    params,
                    function(result)
                        signature_handler(client, result, args.buf)
                    end,
                    args.buf
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

    vim.api.nvim_create_autocmd({ 'CursorMovedI', 'InsertEnter' }, {
        desc = 'Auto show LSP signature help',
        group = group,
        callback = cursor_moved,
    })
end

return M
