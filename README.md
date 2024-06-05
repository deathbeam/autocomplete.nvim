# autocomplete.nvim
Very simple and minimal autocompletion for cmdline and buffer using LSP and Tree-sitter with signature help.  

Originally I made this just for my dotfiles as I did not needed most of stuff existing plugins provided I had
some issues with the ones that were close to what I wanted so as a learning exercise I decided to try and
implement it by myself. Then I just extracted the code to separate plugin in case anyone else wanted to use it too.
Just a warning, there might be some bugs and as this requires Neovim 0.10+ (e.g nightly), that one can also have
bugs by itself.

https://github.com/deathbeam/autocomplete.nvim/assets/5115805/32e59389-baa8-417a-b5cb-26dddeb8786a

## Requirements

Requires **Neovim Nighly/development** version. This version supports stuff like popup menu
for completion menu and closing windows properly from cmdline callbacks.  

For installation instructions/repository go [here](https://github.com/neovim/neovim)

If you want to use Tree-sitter autocompletion (as fallback when you dont have LSP server running) you also need to have
[nvim-treesitter plugin](https://github.com/nvim-treesitter/nvim-treesitter)

## Installation

Just use [lazy.nvim](https://github.com/folke/lazy.nvim) or `:h packages` with git submodules or something else I don't care.
Read the documentation of whatever you want to use.

## Usage

Just require either buffer or cmd module or both and call setup on them.  
**NOTE**: You dont need to provide the configuration, below is just default config, you can just
call setup with no arguments for default.

```lua
-- LSP signature help
require("autocomplete.signature").setup {
    border = nil, -- Signature help border style
    width = 80, -- Max width of signature window
    height = 25, -- Max height of signature window
    debounce_delay = 100
}

-- buffer autocompletion with LSP and Tree-sitter
require("autocomplete.buffer").setup {
    entry_mapper = nil, -- Custom completion entry mapper
    debounce_delay = 100
}

-- cmdline autocompletion
require("autocomplete.cmd").setup {
    mappings = {
        accept = '<C-y>',
        reject = '<C-e>',
        complete = '<C-space>',
        next = '<C-n>',
        previous = '<C-p>',
    },
    border = nil, -- Cmdline completion border style
    columns = 5, -- Number of columns per row
    rows = 0.3, -- Number of rows, if < 1 then its fraction of total vim lines, if > 1 then its absolute number
    close_on_done = true, -- Close completion window when done (accept/reject)
    debounce_delay = 100,
}
```

You also probably want to enable `popup` in completeopt to show documentation preview:

```lua
vim.o.completeopt = 'menuone,noinsert,popup'
```

And you also ideally want to set the capabilities so Neovim will fetch documentation
when resolving completion items:

```lua
-- Here we grab default Neovim capabilities and extend them with ones we want on top
local capabilities = vim.tbl_deep_extend('force', 
    vim.lsp.protocol.make_client_capabilities(), 
    require('autocomplete.capabilities'))

-- Now set capabilities on your LSP servers
require('lspconfig')['<YOUR_LSP_SERVER>'].setup {
    capabilities = capabilities
}
```

If you want to disable `<CR>` to accept completion (as with autocomplete its very annoying) you can do this:

```lua
vim.keymap.set("i", "<CR>", function()
    return vim.fn.pumvisible() ~= 0 and "<C-e><CR>" or "<CR>"
end, { expr = true, replace_keycodes = true })
```

## Similar projects

I used some of this projects as reference and they are also good alternatives:

- https://github.com/nvimdev/epo.nvim
- https://github.com/hrsh7th/nvim-cmp
- https://github.com/smolck/command-completion.nvim
- https://github.com/gelguy/wilder.nvim
