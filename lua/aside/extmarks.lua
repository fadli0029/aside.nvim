local storage = require('aside.storage')

local M = {}

M.namespace = vim.api.nvim_create_namespace('aside_tracking')
M.tracked_buffers = {}

function M.track_annotations(bufnr, annotations)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  M.untrack_buffer(bufnr)

  local extmarks = {}

  for _, annotation in ipairs(annotations) do
    if annotation.status == 'orphaned' then
      goto continue
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if annotation.line > line_count then
      goto continue
    end

    local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, M.namespace, annotation.line - 1, 0, {
      right_gravity = false,
      end_right_gravity = true,
    })

    if ok then
      extmarks[mark_id] = annotation.id
    end

    ::continue::
  end

  M.tracked_buffers[bufnr] = extmarks
end

function M.untrack_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    M.tracked_buffers[bufnr] = nil
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  M.tracked_buffers[bufnr] = nil
end

function M.sync_positions(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local extmarks = M.tracked_buffers[bufnr]
  if not extmarks then
    return
  end

  for mark_id, annotation_id in pairs(extmarks) do
    local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, M.namespace, mark_id, {})

    if mark and #mark > 0 then
      local new_line = mark[1] + 1

      local annotation = storage.get_by_id(annotation_id)
      if annotation and annotation.line ~= new_line then
        storage.update(annotation_id, { line = new_line })
      end
    end
  end
end

function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup('AsideExtmarks', { clear = true })

  vim.api.nvim_create_autocmd('BufUnload', {
    group = group,
    callback = function(args)
      M.sync_positions(args.buf)
      M.untrack_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      for bufnr, _ in pairs(M.tracked_buffers) do
        M.sync_positions(bufnr)
      end
    end,
  })
end

return M
