> [!WARNING]
> Plugin moved to https://github.com/deathbeam/myplugins.nvim, all development will continue there

# autocomplete.nvim
Very simple and minimal autocompletion for cmdline and buffer using LSP and Tree-sitter with signature help.  

Originally I made this just for my dotfiles as I did not needed most of stuff existing plugins provided I had
some issues with the ones that were close to what I wanted so as a learning exercise I decided to try and
implement it by myself. Then I just extracted the code to separate plugin in case anyone else wanted to use it too.
Just a warning, there might be some bugs and as this requires Neovim 0.10+ (e.g nightly), that one can also have
bugs by itself.

https://github.com/deathbeam/autocomplete.nvim/assets/5115805/32e59389-baa8-417a-b5cb-26dddeb8786a

## Installation

Just use [lazy.nvim](https://github.com/folke/lazy.nvim) or `:h packages` with git submodules or something else I don't care.
Read the documentation of whatever you want to use.

> [!WARNING]
> `cmd` completion requires latest Neovim 0.11+ (e.g nightly)

## Usage

Just require either buffer or cmd module or both and call setup on them.  

> [!NOTE]
> You dont need to provide the configuration, below is just default config, you can just call setup with no arguments for default.

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
    border = nil, -- Documentation border style
    entry_mapper = nil, -- Custom completion entry mapper
    debounce_delay = 100,
}

-- cmdline autocompletion
require("autocomplete.cmd").setup()
```

You also probably want to enable `popup` in completeopt to show documentation preview:

```lua
vim.o.completeopt = 'menuone,noselect,noinsert,popup'
```

And you also ideally want to set the capabilities so Neovim will fetch documentation
when resolving completion items:

```lua
-- Here we grab default Neovim capabilities and extend them with ones we want on top
local capabilities = vim.tbl_deep_extend('force', 
    vim.lsp.protocol.make_client_capabilities(), 
    require('autocomplete.capabilities')
)

-- Now set capabilities on your LSP servers
require('lspconfig')['<YOUR_LSP_SERVER>'].setup {
    capabilities = capabilities
}
```
