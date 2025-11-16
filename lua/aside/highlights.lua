local storage = require('aside.storage')

local M = {}

-- Namespace for virtual text
M.namespace = vim.api.nvim_create_namespace('aside_annotations')

-- Sign name
M.sign_name = 'AsideAnnotation'

-- Setup highlight groups and signs
function M.setup()
  -- Define highlight group for virtual text
  vim.api.nvim_set_hl(0, 'AsideAnnotation', {
    fg = '#61afef',  -- light blue
    italic = true,
  })

  -- Define sign
  vim.fn.sign_define(M.sign_name, {
    text = '󰍨',
    texthl = 'AsideAnnotation',
    linehl = '',
    numhl = 'AsideAnnotation',
  })
end

-- Update highlights for a buffer
function M.update_buffer(bufnr)
  -- Check if buffer is valid
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local config = require('aside.config').get()

  -- Clear existing highlights first
  M.clear_buffer(bufnr)

  -- Don't show if disabled
  if not config.indicators.enabled then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == '' then
    return
  end

  -- Get annotations for this file
  local annotations = storage.get_for_file(file_path)

  if config.indicators.style == 'virtual_text' then
    M._apply_virtual_text(bufnr, annotations, config)
  elseif config.indicators.style == 'signs' then
    M._apply_signs(bufnr, annotations, config)
  end
end

-- Apply virtual text indicators
function M._apply_virtual_text(bufnr, annotations, config)
  for _, annotation in ipairs(annotations) do
    local line = annotation.line - 1  -- 0-indexed for API
    local text = config.indicators.icon .. config.indicators.text

    -- Add virtual text at the end of the line
    vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line, 0, {
      virt_text = { { text, 'AsideAnnotation' } },
      virt_text_pos = 'eol',
      hl_mode = 'combine',
    })
  end
end

-- Apply sign indicators
function M._apply_signs(bufnr, annotations, config)
  for _, annotation in ipairs(annotations) do
    vim.fn.sign_place(0, '', M.sign_name, bufnr, {
      lnum = annotation.line,
      priority = 10,
    })
  end
end

-- Clear all highlights from a buffer
function M.clear_buffer(bufnr)
  -- Check if buffer is valid
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)

  -- Clear signs
  vim.fn.sign_unplace('', { buffer = bufnr })
end

-- Setup autocommands to update highlights
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup('AsideHighlights', { clear = true })

  -- Update highlights when entering a buffer
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = group,
    callback = function(args)
      M.update_buffer(args.buf)
    end,
  })

  -- Update highlights after text changes (debounced)
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    callback = function(args)
      -- Wait 500ms after last change before updating
      if M.update_timer then
        M.update_timer:stop()
      end
      M.update_timer = vim.defer_fn(function()
        M.update_buffer(args.buf)
      end, 500)
    end,
  })
end

return M
