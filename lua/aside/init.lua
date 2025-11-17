local M = {}

-- Plugin modules
local config = require('aside.config')
local annotations = require('aside.annotations')
local highlights = require('aside.highlights')

-- Setup function called by user
function M.setup(user_config)
  -- Seed random number generator
  math.randomseed(os.time() + vim.loop.hrtime())

  -- Merge user config with defaults
  config.setup(user_config or {})

  -- Run auto-migration from JSON to SQLite
  local migration = require('aside.migration')
  vim.schedule(function()
    migration.auto_migrate()
  end)

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
    local arg = opts.fargs[2]

    if subcommand == 'add' then
      annotations.add_annotation()
    elseif subcommand == 'view' then
      annotations.view_annotation()
    elseif subcommand == 'list' then
      annotations.list_annotations()
    elseif subcommand == 'toggle' then
      annotations.toggle_indicators()
    elseif subcommand == 'export' then
      M.export_to_json(arg)
    elseif subcommand == 'info' then
      M.show_storage_info()
    else
      vim.notify('Unknown subcommand: ' .. (subcommand or 'nil'), vim.log.levels.ERROR)
      vim.notify('Available: add, view, list, toggle, export, info', vim.log.levels.INFO)
    end
  end, {
    nargs = '+',
    complete = function()
      return { 'add', 'view', 'list', 'toggle', 'export', 'info' }
    end,
  })
end

-- Export annotations to JSON
function M.export_to_json(output_path)
  local storage = require('aside.storage')

  if not output_path then
    output_path = vim.fn.expand(require('aside.config').get().storage_path) .. '/annotations_export.json'
  end

  local ok, err = storage.export_to_json(output_path)

  if ok then
    vim.notify('Annotations exported to: ' .. output_path, vim.log.levels.INFO)
  else
    vim.notify('Export failed: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
  end
end

-- Show storage backend info
function M.show_storage_info()
  local storage = require('aside.storage')
  local info = storage.get_info()

  local msg = string.format(
    'Storage backend: %s\nUsing SQLite: %s',
    info.backend_type,
    tostring(info.using_sqlite)
  )

  vim.notify(msg, vim.log.levels.INFO)
end

return M
