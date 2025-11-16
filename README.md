# aside.nvim

A simple Neovim plugin for creating code annotations. Useful if you are studying or deep diving a codebase but hate cluttering code files with lengthy and dense comments.

## TODO

### High Priority
- [ ] Performance optimization - reduce latency when loading/displaying annotations
- [ ] Improve storage layer - implement proper indexing, add data validation, consider SQLite migration
- [ ] Better line tracking - implement fuzzy matching when code changes and lines shift

### Future Features
- [ ] Search across all annotations
- [ ] Export annotations to markdown
- [ ] Annotation categories/tags
- [ ] Git integration for smarter line tracking
- [ ] LSP hover integration

## Features

- Add annotations to any line of code
- Annotations stored externally in JSON format
- Visual indicators (virtual text or signs) mark annotated lines
- Toggle indicator visibility on/off
- Supports global or per-project storage
- Optional nui.nvim integration for better UI

## Installation

### lazy.nvim

```lua
{
  'fadli0029/aside.nvim',
  dependencies = { 'MunifTanjim/nui.nvim' },  -- optional
  config = function()
    require('aside').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'fadli0029/aside.nvim',
  requires = { 'MunifTanjim/nui.nvim' },  -- optional
  config = function()
    require('aside').setup()
  end,
}
```

## Configuration

```lua
require('aside').setup({
  -- Storage path (default: ~/.local/share/nvim/aside)
  storage_path = vim.fn.stdpath('data') .. '/aside',

  -- Keymaps
  keymaps = {
    add = '<leader>aa',
    view = '<leader>av',
    delete = '<leader>ad',
    toggle = '<leader>at',
    list = '<leader>al',
  },

  -- UI settings
  ui = {
    border = 'rounded',
    width = 80,
    height = 20,
  },

  -- Indicators
  indicators = {
    enabled = true,
    style = 'virtual_text',  -- or 'signs'
    icon = '󰍨 ',
    text = ' [note]',
  },
})
```

## Usage

**Add annotation:** Position cursor on a line and press `<leader>aa`. Write content in the popup and save with `<C-s>`. Press `q` in normal mode to cancel.

**View annotation:** Press `<leader>av` on an annotated line to view or edit. In the popup: `<C-s>` to save, `<C-d>` to delete, `q` to close.

**List annotations:** Press `<leader>al` to see all annotations in the current file. Press `<Enter>` to jump to an annotation, `q` to close.

**Toggle indicators:** Press `<leader>at` to hide/show annotation markers.

**Commands:**
```vim
:Aside add
:Aside view
:Aside list
:Aside toggle
```

## Storage

Default storage location is `~/.local/share/nvim/aside/annotations.json`. All annotations from all projects are stored here, indexed by absolute file path.

For per-project storage, set `storage_path = '.aside'` in config. This creates `.aside/annotations.json` in your project root.

## Requirements

- Neovim 0.9+
- nui.nvim (optional, falls back to vim.ui if not available)

## License

MIT
