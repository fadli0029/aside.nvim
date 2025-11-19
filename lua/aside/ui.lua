local M = {}

-- Check if nui.nvim is available
local has_nui, Popup = pcall(require, 'nui.popup')
local has_nui_input, Input = pcall(require, 'nui.input')
local has_nui_menu, Menu = pcall(require, 'nui.menu')

-- Show confirmation dialog
function M.show_confirm(prompt, callback)
  local config = require('aside.config').get()

  if has_nui_menu then
    local menu = Menu({
      position = '50%',
      size = {
        width = 40,
        height = 4,
      },
      border = {
        style = config.ui.border,
        text = {
          top = ' ' .. prompt .. ' ',
          top_align = 'center',
        },
      },
      win_options = {
        winhighlight = 'Normal:Normal,FloatBorder:Normal',
      },
    }, {
      lines = {
        Menu.item('Yes', { key = 'y' }),
        Menu.item('No', { key = 'n' }),
      },
      max_width = 20,
      keymap = {
        focus_next = { 'j', '<Down>', '<Tab>' },
        focus_prev = { 'k', '<Up>', '<S-Tab>' },
        close = { '<Esc>', 'q' },
        submit = { '<CR>', '<Space>' },
      },
      on_submit = function(item)
        callback(item.text == 'Yes')
      end,
      on_close = function()
        callback(false)
      end,
    })

    menu:mount()
  else
    -- Fallback to vim.ui.select
    vim.ui.select({ 'Yes', 'No' }, {
      prompt = prompt,
    }, function(choice)
      callback(choice == 'Yes')
    end)
  end
end

-- Show create annotation popup
function M.show_create_popup(callback, anchor_text)
  local config = require('aside.config').get()

  if has_nui and has_nui_input then
    M._show_create_nui(callback, anchor_text, config)
  else
    M._show_create_fallback(callback, anchor_text)
  end
end

-- Create annotation popup using nui.nvim
function M._show_create_nui(callback, anchor_text, config)
  -- Sanitize anchor text for border display (no newlines)
  local display_text = anchor_text:gsub('\n', ' ')

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = config.ui.border,
      text = {
        top = ' Add Annotation for: ' .. vim.fn.strcharpart(display_text, 0, 40) .. ' ',
        top_align = 'center',
        bottom = ' <C-s> save | q cancel ',
        bottom_align = 'center',
      },
    },
    position = '50%',
    size = {
      width = config.ui.width,
      height = config.ui.height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
      filetype = 'markdown',
    },
  })

  -- Mount the popup
  popup:mount()

  -- Start in insert mode for easier typing
  vim.schedule(function()
    vim.cmd('startinsert')
  end)

  -- Keymaps
  popup:map('n', 'q', function()
    popup:unmount()
  end, { noremap = true })

  popup:map('n', '<C-s>', function()
    local lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    local content = table.concat(lines, '\n')
    popup:unmount()
    callback(vim.trim(content))
  end, { noremap = true })

  popup:map('i', '<C-s>', function()
    local lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    local content = table.concat(lines, '\n')
    popup:unmount()
    callback(vim.trim(content))
  end, { noremap = true })
end

-- Fallback create popup using vim.ui.input
function M._show_create_fallback(callback, anchor_text)
  vim.ui.input({
    prompt = 'Annotation for "' .. vim.fn.strcharpart(anchor_text, 0, 30) .. '": ',
    default = '',
  }, function(input)
    if input then
      callback(input)
    end
  end)
end

-- Show view/edit annotation popup
function M.show_view_popup(annotation, callback)
  local config = require('aside.config').get()

  if has_nui then
    M._show_view_nui(annotation, callback, config)
  else
    M._show_view_fallback(annotation, callback)
  end
end

-- View annotation popup using nui.nvim
function M._show_view_nui(annotation, callback, config)
  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = config.ui.border,
      text = {
        top = ' Annotation (line ' .. annotation.line .. ') ',
        top_align = 'center',
        bottom = ' <C-s> save | <C-d> delete | q close ',
        bottom_align = 'center',
      },
    },
    position = '50%',
    size = {
      width = config.ui.width,
      height = config.ui.height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
      filetype = 'markdown',
    },
  })

  -- Mount the popup
  popup:mount()

  -- Add annotation info and content
  -- Sanitize anchor text (no newlines allowed in buffer lines)
  local anchor_display = annotation.text:gsub('\n', ' ')

  local header_lines = {
    '**Anchor:** ' .. anchor_display,
    '**Created:** ' .. annotation.created_at,
    '**Updated:** ' .. annotation.updated_at,
    '',
    '---',
    '',
  }

  local content_lines = vim.split(annotation.content, '\n')
  local all_lines = vim.list_extend(header_lines, content_lines)

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, all_lines)

  -- Set cursor to content area (scheduled to ensure buffer is ready)
  vim.schedule(function()
    local line_count = vim.api.nvim_buf_line_count(popup.bufnr)
    local target_line = math.min(#header_lines + 1, line_count)
    vim.api.nvim_win_set_cursor(popup.winid, { target_line, 0 })
  end)

  -- Keymaps
  popup:map('n', 'q', function()
    popup:unmount()
  end, { noremap = true })

  popup:map('n', '<C-s>', function()
    local all_lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    local content_start = 0

    -- Find the separator line
    for i, line in ipairs(all_lines) do
      if line == '---' then
        content_start = i + 1  -- Content starts after separator and empty line
        break
      end
    end

    local content_lines = {}
    for i = content_start + 1, #all_lines do
      table.insert(content_lines, all_lines[i])
    end

    local content = table.concat(content_lines, '\n')
    popup:unmount()
    callback('save', vim.trim(content))
  end, { noremap = true })

  popup:map('i', '<C-s>', function()
    local all_lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    local content_start = 0

    -- Find the separator line
    for i, line in ipairs(all_lines) do
      if line == '---' then
        content_start = i + 1  -- Content starts after separator and empty line
        break
      end
    end

    local content_lines = {}
    for i = content_start + 1, #all_lines do
      table.insert(content_lines, all_lines[i])
    end

    local content = table.concat(content_lines, '\n')
    popup:unmount()
    callback('save', vim.trim(content))
  end, { noremap = true })

  popup:map('n', '<C-d>', function()
    popup:unmount()
    M.show_confirm('Delete this annotation?', function(confirmed)
      if confirmed then
        callback('delete')
      end
    end)
  end, { noremap = true })
end

-- Fallback view popup
function M._show_view_fallback(annotation, callback)
  vim.notify('Annotation: ' .. annotation.content, vim.log.levels.INFO)
  vim.ui.select({ 'Edit', 'Delete', 'Cancel' }, {
    prompt = 'What would you like to do?',
  }, function(choice)
    if choice == 'Edit' then
      vim.ui.input({
        prompt = 'Edit annotation: ',
        default = annotation.content,
      }, function(input)
        if input then
          callback('save', input)
        end
      end)
    elseif choice == 'Delete' then
      callback('delete')
    end
  end)
end

-- Show list of annotations
function M.show_list_popup(annotations, callback)
  local config = require('aside.config').get()

  if has_nui then
    M._show_list_nui(annotations, callback, config)
  else
    M._show_list_fallback(annotations, callback)
  end
end

-- List popup using nui.nvim
function M._show_list_nui(annotations, callback, config)
  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = config.ui.border,
      text = {
        top = ' Annotations (' .. #annotations .. ') ',
        top_align = 'center',
        bottom = ' <Enter> jump | q close ',
        bottom_align = 'center',
      },
    },
    position = '50%',
    size = {
      width = config.ui.width,
      height = math.min(config.ui.height, #annotations * 3 + 5),
    },
    buf_options = {
      modifiable = false,
      readonly = true,
      filetype = 'markdown',
    },
  })

  -- Mount the popup
  popup:mount()

  -- Build list
  local lines = { '# Annotations in this file', '' }
  local annotation_map = {}

  for i, annotation in ipairs(annotations) do
    local preview = vim.fn.strcharpart(annotation.content, 0, 60)
    local anchor_display = annotation.text:gsub('\n', ' ')
    table.insert(lines, string.format('**%d.** Line %d: %s', i, annotation.line, anchor_display))
    table.insert(lines, '    ' .. preview:gsub('\n', ' '))
    table.insert(lines, '')
    annotation_map[#lines - 2] = annotation
  end

  -- Temporarily make buffer modifiable to set lines
  vim.api.nvim_buf_set_option(popup.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup.bufnr, 'modifiable', false)

  -- Keymaps
  popup:map('n', 'q', function()
    popup:unmount()
  end, { noremap = true })

  popup:map('n', '<CR>', function()
    local cursor = vim.api.nvim_win_get_cursor(popup.winid)
    local line = cursor[1]

    -- Find the closest annotation entry
    for entry_line, annotation in pairs(annotation_map) do
      if math.abs(entry_line - line) <= 2 then
        popup:unmount()
        callback(annotation)
        return
      end
    end
  end, { noremap = true })
end

-- Fallback list using vim.ui.select
function M._show_list_fallback(annotations, callback)
  local items = {}
  for _, annotation in ipairs(annotations) do
    table.insert(items, string.format('Line %d: %s', annotation.line, annotation.text))
  end

  vim.ui.select(items, {
    prompt = 'Select annotation:',
  }, function(_, idx)
    if idx then
      callback(annotations[idx])
    end
  end)
end

return M
