local M = {}

-- Default configuration
M.defaults = {
  -- Storage configuration
  -- Default: Global storage at ~/.local/share/nvim/aside/annotations.json
  storage_path = vim.fn.stdpath('data') .. '/aside',

  -- Keybindings
  keymaps = {
    add = '<leader>aa',      -- Add annotation
    view = '<leader>av',     -- View annotation
    delete = '<leader>ad',   -- Delete annotation
    toggle = '<leader>at',   -- Toggle indicators
    list = '<leader>al',     -- List all annotations
  },

  -- UI configuration
  ui = {
    border = 'rounded',
    width = 80,
    height = 20,
  },

  -- Annotation indicators
  indicators = {
    enabled = true,
    style = 'virtual_text',  -- or 'signs'
    icon = '󰍨 ',
    text = ' [note]',
  },

  -- Line tracking
  tracking = {
    search_range = 10,
  },
}

-- Current configuration
M.options = {}

-- Merge user config with defaults
function M.setup(user_config)
  M.options = vim.tbl_deep_extend('force', M.defaults, user_config or {})
  return M.options
end

-- Get current config
function M.get()
  return M.options
end

return M
