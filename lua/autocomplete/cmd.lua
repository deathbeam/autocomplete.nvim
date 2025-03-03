local M = {}

function M.setup()
    local term = vim.api.nvim_replace_termcodes('<C-z>', true, true, true)
    local completing = false

    vim.opt.wildmenu = true
    vim.opt.wildmode = 'noselect:lastused,full'
    vim.opt.wildcharm = vim.fn.char2nr(term)

    vim.keymap.set('c', '<Up>', '<End><C-U><Up>', { silent = true })
    vim.keymap.set('c', '<Down>', '<End><C-U><Down>', { silent = true })

    vim.api.nvim_create_autocmd('CmdlineChanged', {
        desc = 'Auto show command line completion',
        group = vim.api.nvim_create_augroup('autocomplete-cmd', {}),
        pattern = ':',
        callback = function()
            local cmdline = vim.fn.getcmdline()
            local curpos = vim.fn.getcmdpos()
            local last_char = cmdline:sub(-1)

            if
                curpos == #cmdline + 1
                and vim.fn.pumvisible() == 0
                and last_char:match('[%w%/%: ]')
                and not cmdline:match('^%d+$')
            then
                vim.opt.eventignore:append('CmdlineChanged')
                vim.api.nvim_feedkeys(term, 'ti', false)
                vim.schedule(function()
                    local current_cmdline = vim.fn.getcmdline()
                    if current_cmdline:match('\026$') or current_cmdline:match('\x1A$') then
                        vim.fn.setcmdline(cmdline)
                    end
                    vim.opt.eventignore:remove('CmdlineChanged')
                end)
            end
        end,
    })
end

return M
