# autocomplete.nvim
Very simple and minimal autocompletion for cmdline and LSP with signature help.  

This was mostly learning exercise and I also did not needed 90% of stuff existing solutions like 
nvim-cmp and wilder provided so yea. Also there might be some bugs and Neovim Nightly also isnt the most
stable thing ever.  

### LSP documentation
![lsp-documentation](/screenshots/lsp-documentation.png)

### LSP signature help
![lsp-signature-help](/screenshots/lsp-signature-help.png)

### cmdline completion
![cmd-completion](/screenshots/cmd-completion.png)

## Requirements

Requires **Neovim Nighly/development** version. This version supports stuff like popup menu
for completion menu and closing windows properly from cmdline callbacks.  

For installation instructions/repository go [here](https://github.com/neovim/neovim)

## Usage

Just require either lsp or cmd module or both and call setup on them (and enable `popup` completeopt).  
**NOTE**: You dont need to provide the configuration, below is just default config, you can just
call setup with no arguments for default.

```lua
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

You also probably want to enable `popup` in completeopt to show documentation preview:

```lua
vim.o.completeopt = 'menuone,noinsert,popup'
```

And you also ideally want to set the capabilities so Neovim will fetch documentation and additional text edits
when resolving completion items:

```lua
-- Here we grab default Neovim capabilities and extend them with ones we want on top
local capabilities = vim.tbl_deep_extend('force', 
    vim.lsp.protocol.make_client_capabilities(), 
    require('completion.lsp').capabilities())

-- Now set capabilities on your LSP servers
require('lspconfig')['<YOUR_LSP_SERVER>'].setup {
    capabilities = capabilities
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
