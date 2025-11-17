local storage = require('aside.storage')

local M = {}

-- Create a new annotation at the current cursor position or selection
function M.add_annotation()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)

  -- Check if this is a valid file
  if file_path == '' then
    vim.notify('Cannot annotate unsaved buffer', vim.log.levels.WARN)
    return
  end

  -- Get cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_number = cursor[1]
  local column = cursor[2]

  -- Get the selected text or current line
  local anchor_text = M.get_selected_text()
  if not anchor_text or anchor_text == '' then
    -- No selection, use current line
    local line_content = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
    anchor_text = vim.trim(line_content)
  else
    -- Trim selected text to remove leading/trailing whitespace
    anchor_text = vim.trim(anchor_text)
  end

  -- Check if annotation already exists at this line
  local existing = storage.get_at_location(file_path, line_number)
  if existing then
    vim.notify('Annotation already exists at this line. Use view to edit it.', vim.log.levels.WARN)
    return
  end

  local line_content = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
  local line_hash = storage.hash_line(vim.trim(line_content))

  -- Show UI to create annotation
  local ui = require('aside.ui')
  ui.show_create_popup(function(content)
    if not content or content == '' then
      vim.notify('Annotation content cannot be empty', vim.log.levels.WARN)
      return
    end

    local annotation = {
      file = vim.fn.fnamemodify(file_path, ':p'), -- absolute path
      line = line_number,
      column = column,
      text = anchor_text,
      content = content,
      hash = line_hash,
    }

    if storage.add(annotation) then
      vim.notify('Annotation added', vim.log.levels.INFO)
      M.refresh_highlights(bufnr)
    else
      vim.notify('Failed to save annotation', vim.log.levels.ERROR)
    end
  end, anchor_text)
end

-- View/edit annotation at cursor position
function M.view_annotation()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)

  if file_path == '' then
    vim.notify('Cannot view annotations in unsaved buffer', vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_number = cursor[1]

  -- Find annotation at this line
  local annotation = storage.get_at_location(file_path, line_number)

  if not annotation then
    vim.notify('No annotation found at this line', vim.log.levels.WARN)
    return
  end

  -- Check if line content has changed
  local line_content = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
  local current_hash = storage.hash_line(line_content)

  if current_hash ~= annotation.hash then
    vim.notify('Warning: Line content has changed since annotation was created', vim.log.levels.WARN)
  end

  -- Show UI to view/edit annotation
  local ui = require('aside.ui')
  ui.show_view_popup(annotation, function(action, data)
    if action == 'save' then
      if storage.update(annotation.id, { content = data }) then
        vim.notify('Annotation updated', vim.log.levels.INFO)
        M.refresh_highlights(bufnr)
      else
        vim.notify('Failed to update annotation', vim.log.levels.ERROR)
      end
    elseif action == 'delete' then
      M.delete_annotation(annotation.id, bufnr)
    end
  end)
end

-- Delete annotation
function M.delete_annotation(annotation_id, bufnr)
  if storage.delete(annotation_id) then
    vim.notify('Annotation deleted', vim.log.levels.INFO)
    if bufnr then
      M.refresh_highlights(bufnr)
    end
  else
    vim.notify('Failed to delete annotation', vim.log.levels.ERROR)
  end
end

-- List all annotations for the current file
function M.list_annotations()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)

  if file_path == '' then
    vim.notify('Cannot list annotations in unsaved buffer', vim.log.levels.WARN)
    return
  end

  local annotations = storage.get_for_file(file_path)

  if #annotations == 0 then
    vim.notify('No annotations found in this file', vim.log.levels.INFO)
    return
  end

  -- Show UI with list of annotations
  local ui = require('aside.ui')
  ui.show_list_popup(annotations, function(annotation)
    -- Jump to annotation
    vim.api.nvim_win_set_cursor(0, { annotation.line, annotation.column })
    -- Then view it
    M.view_annotation()
  end)
end

-- Refresh highlights for a buffer
function M.refresh_highlights(bufnr)
  local highlights = require('aside.highlights')
  highlights.update_buffer(bufnr)
end

-- Get selected text in visual mode
function M.get_selected_text()
  -- Save current register
  local reg_save = vim.fn.getreg('"')
  local reg_type_save = vim.fn.getregtype('"')

  -- Try to get visual selection
  vim.cmd('noautocmd normal! "vy')
  local selected = vim.fn.getreg('"')

  -- Restore register
  vim.fn.setreg('"', reg_save, reg_type_save)

  -- If nothing was selected, return nil
  if selected == '' then
    return nil
  end

  return selected
end

-- Toggle indicators visibility
function M.toggle_indicators()
  local config = require('aside.config').get()
  config.indicators.enabled = not config.indicators.enabled

  if config.indicators.enabled then
    vim.notify('Annotation indicators enabled', vim.log.levels.INFO)
    -- Refresh all visible buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        M.refresh_highlights(bufnr)
      end
    end
  else
    vim.notify('Annotation indicators disabled', vim.log.levels.INFO)
    -- Clear all highlights
    local highlights = require('aside.highlights')
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        highlights.clear_buffer(bufnr)
      end
    end
  end
end

return M
