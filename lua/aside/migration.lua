local M = {}

-- Get the JSON storage path (old format)
function M.get_json_path()
  local config = require('aside.config').get()
  local storage_dir = vim.fn.expand(config.storage_path)
  return storage_dir .. '/annotations.json'
end

-- Get the JSON backup path
function M.get_json_backup_path()
  local config = require('aside.config').get()
  local storage_dir = vim.fn.expand(config.storage_path)
  return storage_dir .. '/annotations.json.backup'
end

-- Get the migration marker path
function M.get_migration_marker_path()
  local config = require('aside.config').get()
  local storage_dir = vim.fn.expand(config.storage_path)
  return storage_dir .. '/.migrated_to_sqlite'
end

-- Check if migration has already been performed
function M.is_migrated()
  local marker = M.get_migration_marker_path()
  return vim.fn.filereadable(marker) == 1
end

-- Mark migration as complete
function M.mark_migrated()
  local marker = M.get_migration_marker_path()
  local file = io.open(marker, 'w')
  if file then
    file:write(os.date('%d %B %Y, %H:%M:%S'))
    file:close()
    return true
  end
  return false
end

-- Load annotations from JSON file
function M.load_from_json()
  local json_path = M.get_json_path()

  -- If file doesn't exist, return empty table
  if vim.fn.filereadable(json_path) == 0 then
    return nil, 'JSON file not found'
  end

  -- Read file contents
  local file = io.open(json_path, 'r')
  if not file then
    return nil, 'Failed to open JSON file'
  end

  local content = file:read('*all')
  file:close()

  if not content or content == '' then
    return nil, 'JSON file is empty'
  end

  -- Parse JSON
  local ok, annotations = pcall(vim.json.decode, content)
  if not ok then
    return nil, 'Failed to parse JSON file'
  end

  return annotations or {}
end

-- Backup JSON file
function M.backup_json()
  local json_path = M.get_json_path()
  local backup_path = M.get_json_backup_path()

  if vim.fn.filereadable(json_path) == 0 then
    return true -- No file to backup
  end

  -- Read original file
  local file = io.open(json_path, 'r')
  if not file then
    return false, 'Failed to read JSON file for backup'
  end

  local content = file:read('*all')
  file:close()

  -- Write backup
  local backup_file = io.open(backup_path, 'w')
  if not backup_file then
    return false, 'Failed to create backup file'
  end

  backup_file:write(content)
  backup_file:close()

  return true
end

-- Perform migration from JSON to SQLite
function M.migrate_to_sqlite()
  local storage_sqlite = require('aside.storage_sqlite')

  -- Check if SQLite is available
  if not storage_sqlite.is_available() then
    return false, 'sqlite.lua is not available. Cannot migrate to SQLite.'
  end

  -- Check if already migrated
  if M.is_migrated() then
    return true, 'already_migrated'
  end

  -- Load data from JSON
  local annotations, err = M.load_from_json()

  if not annotations then
    -- No JSON file or empty - just mark as migrated
    if err == 'JSON file not found' or err == 'JSON file is empty' then
      M.mark_migrated()
      return true, 'no_data_to_migrate'
    end
    return false, err
  end

  -- Backup JSON file before migration
  local backup_ok, backup_err = M.backup_json()
  if not backup_ok then
    return false, backup_err
  end

  -- Save to SQLite
  local save_ok = storage_sqlite.save_all(annotations)
  if not save_ok then
    return false, 'Failed to save annotations to SQLite database'
  end

  -- Mark migration as complete
  M.mark_migrated()

  return true, string.format('migrated_%d_annotations', #annotations)
end

-- Auto-migration: Run on plugin load
function M.auto_migrate()
  local storage_sqlite = require('aside.storage_sqlite')

  -- Only attempt migration if SQLite is available
  if not storage_sqlite.is_available() then
    return false, 'sqlite_not_available'
  end

  -- Only migrate if not already done
  if M.is_migrated() then
    return true, 'already_migrated'
  end

  -- Check if JSON file exists
  local json_path = M.get_json_path()
  if vim.fn.filereadable(json_path) == 0 then
    -- No JSON file, just mark as migrated to skip future checks
    M.mark_migrated()
    return true, 'no_json_file'
  end

  -- Perform migration
  local ok, result = M.migrate_to_sqlite()

  if ok then
    if result:match('^migrated_(%d+)_annotations$') then
      local count = result:match('(%d+)')
      vim.notify(
        string.format('Aside.nvim: Successfully migrated %s annotations to SQLite', count),
        vim.log.levels.INFO
      )
    end
    return true, result
  else
    vim.notify(
      'Aside.nvim: Migration to SQLite failed: ' .. (result or 'unknown error'),
      vim.log.levels.ERROR
    )
    return false, result
  end
end

-- Manual export from SQLite to JSON (for backup/portability)
function M.export_sqlite_to_json(output_path)
  local storage_sqlite = require('aside.storage_sqlite')

  if not storage_sqlite.is_available() then
    return false, 'SQLite not available'
  end

  return storage_sqlite.export_to_json(output_path or M.get_json_path())
end

return M
