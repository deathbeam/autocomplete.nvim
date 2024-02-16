# autocomplete.nvim
Very simple and minimal autocompletion for cmdline and LSP with signature help.  

This was mostly learning exercise and I also did not needed 90% of stuff existing solutions like 
nvim-cmp and wilder provided so yea. Also there might be some bugs and Neovim Nightly also isnt the most
stable thing ever.  

## Requirements

Requires **Neovim Nighly/development** version. This version supports stuff like popup menu
for completion menu and closing windows properly from cmdline callbacks.  

For installation instructions/repository go [here](https://github.com/neovim/neovim)

## Usage

Just require either lsp or cmd module or both and call setup on them (and enable `popup` completeopt).  
**NOTE**: You dont need to provide the configuration, below is just default config, you can just
call setup with no arguments for default.

```lua
-- Enable popup in complete opt for LSP documentation preview
vim.o.completeopt = 'menuone,noinsert,popup'

require("autocomplete.lsp").setup {
    window = {
        border = nil, -- Signature border style
    },
    debounce_delay = 100
}

require("autocomplete.cmd").setup {
    window = {
        border = nil,
        columns = 5,
        rows = 0.3
    },
    mappings = {
        accept = '<C-y>',
        reject = '<C-e>',
        complete = '<C-space>',
        next = '<C-n>',
        previous = '<C-p>',
    },
    highlight = {
        selection = true,
        directories = true,
    },
    debounce_delay = 100,
    close_on_done = true, -- Close completion window when done (accept/reject)
}
```

## Features

- LSP autocomplete
- LSP signature help
- LSP documentation
- cmdline autocompletion

## Similar projects

I used some of this projects as reference and they are also good alternatives:

- https://github.com/nvimdev/epo.nvim
- https://github.com/hrsh7th/nvim-cmp
- https://github.com/smolck/command-completion.nvim
- https://github.com/gelguy/wilder.nvim
