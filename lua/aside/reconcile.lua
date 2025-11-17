local storage = require('aside.storage')

local M = {}

M.SEARCH_RANGE = 10

function M.reconcile_annotations(bufnr, file_path, annotations)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local updated = {}

  for _, annotation in ipairs(annotations) do
    if annotation.status == 'orphaned' then
      goto continue
    end

    if annotation.line <= #lines then
      local current_line = lines[annotation.line]
      local current_hash = storage.hash_line(vim.trim(current_line))

      if current_hash == annotation.hash then
        goto continue
      end
    end

    local new_line = M.find_line_by_hash(lines, annotation.hash, annotation.line)

    if new_line then
      storage.update(annotation.id, { line = new_line })
      table.insert(updated, { id = annotation.id, old_line = annotation.line, new_line = new_line })
    else
      storage.update(annotation.id, { status = 'orphaned' })
    end

    ::continue::
  end

  return updated
end

function M.find_line_by_hash(lines, target_hash, hint_line)
  local start_line = math.max(1, hint_line - M.SEARCH_RANGE)
  local end_line = math.min(#lines, hint_line + M.SEARCH_RANGE)

  for i = start_line, end_line do
    local line_hash = storage.hash_line(vim.trim(lines[i]))
    if line_hash == target_hash then
      return i
    end
  end

  return nil
end

return M
