# aside.nvim

A simple Neovim plugin for creating code annotations. Useful if you are studying or deep diving a codebase but hate cluttering code files with lengthy and dense comments.

## Demo

![Demo](./demo.gif)

## TODO

### High Priority
- [x] Improve storage layer - implement proper indexing, add data validation, consider SQLite migration
- [ ] Better line tracking - implement fuzzy matching when code changes and lines shift
- [ ] Performance optimization - reduce latency when loading/displaying annotations

### Future Features
- [ ] Search across all annotations
- [ ] Export annotations to markdown
- [ ] Annotation categories/tags
- [ ] Git integration for smarter line tracking
- [ ] LSP hover integration

## Features

- Add annotations to any line of code
- SQLite storage with automatic migration from JSON
- Indexed queries for fast lookups
- Visual indicators (virtual text or signs) mark annotated lines
- Toggle indicator visibility
- Global or per-project storage
- Export to JSON for backups

## Requirements

- Neovim 0.9+
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- [sqlite.lua](https://github.com/kkharji/sqlite.lua) (optional, falls back to JSON)
  - Requires sqlite3 binary on your system

## Installation

### lazy.nvim

```lua
{
  'fadli0029/aside.nvim',
  dependencies = {
    'MunifTanjim/nui.nvim',
    'kkharji/sqlite.lua',
  },
  config = function()
    require('aside').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'fadli0029/aside.nvim',
  requires = {
    'MunifTanjim/nui.nvim',
    'kkharji/sqlite.lua',
  },
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
:Aside add          " Add annotation at current line
:Aside view         " View/edit annotation at current line
:Aside list         " List all annotations in current file
:Aside toggle       " Toggle annotation indicators
:Aside export       " Export annotations to JSON (default: storage_path/annotations_export.json)
:Aside export path  " Export annotations to custom path
:Aside info         " Show storage backend info (SQLite or JSON)
```

## Storage

Default storage location is `~/.local/share/nvim/aside/`. With `sqlite.lua` installed, annotations are stored in `annotations.db`. Without it, `annotations.json` is used.

SQLite uses indexed queries and transactions. JSON reads the entire file for each operation.

Existing JSON data migrates to SQLite automatically. A backup is created at `annotations.json.backup`.

For per-project storage, set `storage_path = '.aside'` in config.

## License

MIT
