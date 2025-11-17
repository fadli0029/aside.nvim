-- Storage facade: Automatically uses SQLite when available, falls back to JSON
local M = {}

-- Backend selection
M.backend = nil
M.backend_type = nil

-- Initialize storage backend
function M.init_backend()
  if M.backend then
    return M.backend
  end

  -- Try to load SQLite backend first
  local has_sqlite_storage, storage_sqlite = pcall(require, 'aside.storage_sqlite')

  if has_sqlite_storage and storage_sqlite.is_available() then
    M.backend = storage_sqlite
    M.backend_type = 'sqlite'
  else
    -- Fallback to JSON storage
    local storage_json = require('aside.storage_json')
    M.backend = storage_json
    M.backend_type = 'json'

    -- Notify user if SQLite is not available (only once)
    if not M.notified_fallback then
      vim.notify(
        'Aside.nvim: sqlite.lua not found, using JSON storage.',
        vim.log.levels.WARN
      )
      M.notified_fallback = true
    end
  end

  return M.backend
end

-- Get current backend type
function M.get_backend_type()
  M.init_backend()
  return M.backend_type
end

-- Check if using SQLite backend
function M.is_using_sqlite()
  return M.get_backend_type() == 'sqlite'
end

-- Load all annotations
function M.load()
  local backend = M.init_backend()
  return backend.load()
end

-- Get annotations for a specific file
function M.get_for_file(file_path)
  local backend = M.init_backend()
  return backend.get_for_file(file_path)
end

-- Add a new annotation
function M.add(annotation)
  local backend = M.init_backend()
  return backend.add(annotation)
end

-- Update an existing annotation
function M.update(annotation_id, updates)
  local backend = M.init_backend()
  return backend.update(annotation_id, updates)
end

-- Delete an annotation
function M.delete(annotation_id)
  local backend = M.init_backend()
  return backend.delete(annotation_id)
end

-- Get annotation by ID
function M.get_by_id(annotation_id)
  local backend = M.init_backend()
  return backend.get_by_id(annotation_id)
end

-- Get annotation at a specific location (file + line)
function M.get_at_location(file_path, line_number)
  local backend = M.init_backend()
  return backend.get_at_location(file_path, line_number)
end

-- Generate a unique ID
function M.generate_id()
  local backend = M.init_backend()
  return backend.generate_id()
end

-- Calculate hash of a line (for detecting if code changed)
function M.hash_line(line_content)
  local backend = M.init_backend()
  return backend.hash_line(line_content)
end

-- Export to JSON (for backup/portability when using SQLite)
function M.export_to_json(output_path)
  if M.is_using_sqlite() then
    local migration = require('aside.migration')
    return migration.export_sqlite_to_json(output_path)
  else
    vim.notify('Already using JSON storage, no export needed', vim.log.levels.INFO)
    return true
  end
end

-- Get storage info for debugging
function M.get_info()
  M.init_backend()
  return {
    backend_type = M.backend_type,
    using_sqlite = M.backend_type == 'sqlite',
  }
end

return M
