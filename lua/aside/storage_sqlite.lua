local M = {}

-- Current schema version
M.SCHEMA_VERSION = 1

-- Check if sqlite.lua is available
local has_sqlite, db_module = pcall(require, 'sqlite.db')

-- Initialize flag
M.initialized = false
M.db = nil

-- Error tracking to avoid spam
M.init_error_shown = false

-- Get the database path
function M.get_db_path()
  local config = require('aside.config').get()
  local storage_dir = vim.fn.expand(config.storage_path)

  -- Ensure the directory exists
  if vim.fn.isdirectory(storage_dir) == 0 then
    vim.fn.mkdir(storage_dir, 'p')
  end

  return storage_dir .. '/annotations.db'
end

-- Initialize database connection and schema
function M.init()
  if M.initialized then
    return true
  end

  if not has_sqlite then
    return false, 'sqlite.lua not available. Please install it via your plugin manager.'
  end

  local db_path = M.get_db_path()

  -- Open database connection
  local ok, db = pcall(db_module.open, db_module, db_path, {
    keep_open = true,
  })

  if not ok or not db then
    return false, 'Failed to open SQLite database at: ' .. db_path
  end

  M.db = db

  -- Create schema
  local ok, err = M.create_schema()
  if not ok then
    return false, err
  end

  M.initialized = true
  return true
end

-- Create database schema
function M.create_schema()
  if not M.db then
    return false, 'Database not initialized'
  end

  -- Create schema_version table
  local ok1 = pcall(M.db.create, M.db, 'schema_version', {
    version = { type = 'integer', primary = true },
    ensure = true,
  })

  -- Create annotations table
  local ok2 = pcall(M.db.create, M.db, 'annotations', {
    id = { type = 'text', primary = true, required = true },
    file = { type = 'text', required = true },
    line = { type = 'integer', required = true },
    column = 'integer',
    text = 'text',
    content = { type = 'text', required = true },
    hash = 'text',
    created_at = { type = 'text', required = true },
    updated_at = { type = 'text', required = true },
    ensure = true,
  })

  if not ok1 or not ok2 then
    return false, 'Failed to create database schema'
  end

  -- Create indexes
  local idx_ok = pcall(function()
    M.db:eval([[
      CREATE INDEX IF NOT EXISTS idx_annotations_file ON annotations(file);
      CREATE INDEX IF NOT EXISTS idx_annotations_file_line ON annotations(file, line);
    ]])
  end)

  if not idx_ok then
    vim.notify('Aside.nvim: Failed to create database indexes', vim.log.levels.WARN)
  end

  -- Check/set schema version
  local version_result = M.db:select('schema_version', { where = { version = M.SCHEMA_VERSION } })

  if not version_result or #version_result == 0 then
    -- Insert schema version
    M.db:insert('schema_version', { version = M.SCHEMA_VERSION })
  end

  return true
end

-- Load all annotations
function M.load()
  local ok, err = M.init()
  if not ok then
    -- Show init error once per session
    if not M.init_error_shown then
      vim.notify('Aside.nvim SQLite init failed: ' .. (err or 'unknown'), vim.log.levels.ERROR)
      M.init_error_shown = true
    end
    return {}
  end

  local success, result = pcall(function()
    return M.db:select('annotations')
  end)

  if not success then
    vim.notify('Aside.nvim: Failed to load annotations from database', vim.log.levels.ERROR)
    return {}
  end

  return result or {}
end

-- Save all annotations (batch insert - used for migration)
function M.save_all(annotations)
  local ok, err = M.init()
  if not ok then
    vim.notify('SQLite storage error: ' .. (err or 'unknown'), vim.log.levels.ERROR)
    return false
  end

  -- Clear existing data
  local success = pcall(function()
    M.db:execute('DELETE FROM annotations')
  end)

  if not success then
    return false
  end

  -- Insert all annotations
  for _, annotation in ipairs(annotations) do
    local insert_ok = pcall(function()
      M.db:insert('annotations', annotation)
    end)

    if not insert_ok then
      vim.notify('Failed to insert annotation: ' .. annotation.id, vim.log.levels.WARN)
    end
  end

  return true
end

-- Get annotations for a specific file
function M.get_for_file(file_path)
  local ok, err = M.init()
  if not ok then
    -- Show init error once per session
    if not M.init_error_shown then
      vim.notify('Aside.nvim SQLite init failed: ' .. (err or 'unknown'), vim.log.levels.ERROR)
      M.init_error_shown = true
    end
    return {}
  end

  -- Normalize file path to absolute
  local abs_path = vim.fn.fnamemodify(file_path, ':p')

  local success, result = pcall(function()
    return M.db:select('annotations', {
      where = { file = abs_path }
    })
  end)

  if not success then
    if not M.query_error_shown then
      vim.notify('Aside.nvim: Database query failed', vim.log.levels.ERROR)
      M.query_error_shown = true
    end
    return {}
  end

  return result or {}
end

-- Add a new annotation
function M.add(annotation)
  local ok, err = M.init()
  if not ok then
    vim.notify('SQLite storage error: ' .. (err or 'unknown'), vim.log.levels.ERROR)
    return false
  end

  -- Generate unique ID
  annotation.id = M.generate_id()
  annotation.created_at = os.date('%d %B %Y, %H:%M:%S')
  annotation.updated_at = annotation.created_at

  local success = pcall(function()
    M.db:insert('annotations', annotation)
  end)

  if not success then
    vim.notify('Failed to add annotation to database', vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Update an existing annotation
function M.update(annotation_id, updates)
  local ok, err = M.init()
  if not ok then
    vim.notify('SQLite storage error: ' .. (err or 'unknown'), vim.log.levels.ERROR)
    return false
  end

  -- Add updated timestamp
  updates.updated_at = os.date('%d %B %Y, %H:%M:%S')

  local success = pcall(function()
    M.db:update('annotations', {
      where = { id = annotation_id },
      set = updates
    })
  end)

  if not success then
    vim.notify('Failed to update annotation in database', vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Delete an annotation
function M.delete(annotation_id)
  local ok, err = M.init()
  if not ok then
    vim.notify('SQLite storage error: ' .. (err or 'unknown'), vim.log.levels.ERROR)
    return false
  end

  local success = pcall(function()
    M.db:delete('annotations', {
      where = { id = annotation_id }
    })
  end)

  if not success then
    vim.notify('Failed to delete annotation from database', vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Get annotation by ID
function M.get_by_id(annotation_id)
  local ok, err = M.init()
  if not ok then
    -- Show init error once per session
    if not M.init_error_shown then
      vim.notify('Aside.nvim SQLite init failed: ' .. (err or 'unknown'), vim.log.levels.ERROR)
      M.init_error_shown = true
    end
    return nil
  end

  local success, result = pcall(function()
    return M.db:select('annotations', {
      where = { id = annotation_id }
    })
  end)

  if not success then
    vim.notify('Aside.nvim: Database query failed', vim.log.levels.ERROR)
    return nil
  end

  if not result or #result == 0 then
    return nil
  end

  return result[1]
end

-- Get annotation at a specific location (file + line)
function M.get_at_location(file_path, line_number)
  local ok, err = M.init()
  if not ok then
    -- Show init error once per session
    if not M.init_error_shown then
      vim.notify('Aside.nvim SQLite init failed: ' .. (err or 'unknown'), vim.log.levels.ERROR)
      M.init_error_shown = true
    end
    return nil
  end

  -- Normalize file path to absolute
  local abs_path = vim.fn.fnamemodify(file_path, ':p')

  local success, result = pcall(function()
    return M.db:select('annotations', {
      where = { file = abs_path, line = line_number }
    })
  end)

  if not success then
    vim.notify('Aside.nvim: Database query failed', vim.log.levels.ERROR)
    return nil
  end

  if not result or #result == 0 then
    return nil
  end

  return result[1]
end

-- Generate a unique ID
function M.generate_id()
  local hrtime = vim.loop.hrtime()
  local rand1 = math.random(0, 0xFFFFFFFF)
  local rand2 = math.random(0, 0xFFFFFFFF)
  return string.format('%x-%x-%x', hrtime, rand1, rand2)
end

-- Calculate hash of a line
function M.hash_line(line_content)
  return vim.fn.sha256(line_content)
end

-- Close database connection
function M.close()
  if M.db and M.db.close then
    M.db:close()
    M.initialized = false
    M.db = nil
  end
end

-- Export annotations to JSON
function M.export_to_json(output_path)
  local ok, err = M.init()
  if not ok then
    return false, err
  end

  local annotations = M.load()

  local success, json = pcall(vim.json.encode, annotations)
  if not success then
    return false, 'Failed to encode annotations to JSON'
  end

  local file = io.open(output_path, 'w')
  if not file then
    return false, 'Failed to open file for writing: ' .. output_path
  end

  file:write(json)
  file:close()

  return true
end

-- Check if SQLite is available
function M.is_available()
  return has_sqlite
end

return M
