local M = {}

-- Plugin modules
local config = require('aside.config')
local annotations = require('aside.annotations')
local highlights = require('aside.highlights')

-- Setup function called by user
function M.setup(user_config)
  -- Merge user config with defaults
  config.setup(user_config or {})

  -- Setup highlights and signs
  highlights.setup()

  -- Setup autocommands for highlights
  highlights.setup_autocommands()

  -- Setup keymaps
  M.setup_keymaps()

  -- Setup commands
  M.setup_commands()

  -- Load highlights for currently open buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      highlights.update_buffer(bufnr)
    end
  end
end

-- Setup keymaps
function M.setup_keymaps()
  local opts = config.get()
  local keymaps = opts.keymaps

  -- Add annotation
  vim.keymap.set({ 'n', 'v' }, keymaps.add, function()
    annotations.add_annotation()
  end, { desc = 'Add annotation' })

  -- View annotation
  vim.keymap.set('n', keymaps.view, function()
    annotations.view_annotation()
  end, { desc = 'View annotation' })

  -- Delete annotation (opens view where user can delete)
  vim.keymap.set('n', keymaps.delete, function()
    annotations.view_annotation()
  end, { desc = 'View/Delete annotation' })

  -- Toggle indicators
  vim.keymap.set('n', keymaps.toggle, function()
    annotations.toggle_indicators()
  end, { desc = 'Toggle annotation indicators' })

  -- List annotations
  vim.keymap.set('n', keymaps.list, function()
    annotations.list_annotations()
  end, { desc = 'List annotations in file' })
end

-- Setup user commands
function M.setup_commands()
  -- Create main command
  vim.api.nvim_create_user_command('Aside', function(opts)
    local subcommand = opts.fargs[1]

    if subcommand == 'add' then
      annotations.add_annotation()
    elseif subcommand == 'view' then
      annotations.view_annotation()
    elseif subcommand == 'list' then
      annotations.list_annotations()
    elseif subcommand == 'toggle' then
      annotations.toggle_indicators()
    else
      vim.notify('Unknown subcommand: ' .. (subcommand or 'nil'), vim.log.levels.ERROR)
      vim.notify('Available: add, view, list, toggle', vim.log.levels.INFO)
    end
  end, {
    nargs = 1,
    complete = function()
      return { 'add', 'view', 'list', 'toggle' }
    end,
  })
end

return M
