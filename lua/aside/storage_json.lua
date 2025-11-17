-- JSON storage fallback
local M = {}

-- Get the storage file path
function M.get_storage_path()
  local config = require('aside.config').get()
  local storage_dir = config.storage_path

  -- Expand ~ and other special characters
  storage_dir = vim.fn.expand(storage_dir)

  -- Ensure the directory exists
  if vim.fn.isdirectory(storage_dir) == 0 then
    vim.fn.mkdir(storage_dir, 'p')
  end

  return storage_dir .. '/annotations.json'
end

-- Read all annotations from storage
function M.load()
  local file_path = M.get_storage_path()

  if vim.fn.filereadable(file_path) == 0 then
    return {}
  end

  local file = io.open(file_path, 'r')
  if not file then
    vim.notify('Aside.nvim: Cannot open JSON file', vim.log.levels.ERROR)
    return {}
  end

  local content = file:read('*all')
  file:close()

  local ok, annotations = pcall(vim.json.decode, content)
  if not ok then
    vim.notify('Aside.nvim: Corrupted JSON file at ' .. file_path, vim.log.levels.WARN)
    return {}
  end

  return annotations or {}
end

-- Save all annotations to storage
function M.save(annotations)
  local file_path = M.get_storage_path()

  -- Convert to JSON
  local ok, json = pcall(vim.json.encode, annotations)
  if not ok then
    vim.notify('Failed to encode annotations to JSON', vim.log.levels.ERROR)
    return false
  end

  -- Write to file
  local file = io.open(file_path, 'w')
  if not file then
    vim.notify('Failed to write annotations file: ' .. file_path, vim.log.levels.ERROR)
    return false
  end

  file:write(json)
  file:close()

  return true
end

-- Get annotations for a specific file
function M.get_for_file(file_path)
  local all_annotations = M.load()
  local file_annotations = {}

  -- Normalize file path to absolute
  local abs_path = vim.fn.fnamemodify(file_path, ':p')

  for _, annotation in ipairs(all_annotations) do
    if annotation.file == abs_path then
      table.insert(file_annotations, annotation)
    end
  end

  return file_annotations
end

-- Add a new annotation
function M.add(annotation)
  local annotations = M.load()

  annotation.id = M.generate_id()
  annotation.created_at = os.date('%d %B %Y, %H:%M:%S')
  annotation.updated_at = annotation.created_at

  table.insert(annotations, annotation)
  return M.save(annotations)
end

-- Update an existing annotation
function M.update(annotation_id, updates)
  local annotations = M.load()

  for i, annotation in ipairs(annotations) do
    if annotation.id == annotation_id then
      for key, value in pairs(updates) do
        annotation[key] = value
      end
      annotation.updated_at = os.date('%d %B %Y, %H:%M:%S')
      annotations[i] = annotation
      return M.save(annotations)
    end
  end

  return false
end

-- Delete an annotation
function M.delete(annotation_id)
  local annotations = M.load()

  for i, annotation in ipairs(annotations) do
    if annotation.id == annotation_id then
      table.remove(annotations, i)
      return M.save(annotations)
    end
  end

  return false
end

-- Get annotation by ID
function M.get_by_id(annotation_id)
  local annotations = M.load()

  for _, annotation in ipairs(annotations) do
    if annotation.id == annotation_id then
      return annotation
    end
  end

  return nil
end

-- Get annotation at a specific location (file + line)
function M.get_at_location(file_path, line_number)
  local file_annotations = M.get_for_file(file_path)

  for _, annotation in ipairs(file_annotations) do
    if annotation.line == line_number then
      return annotation
    end
  end

  return nil
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

return M
