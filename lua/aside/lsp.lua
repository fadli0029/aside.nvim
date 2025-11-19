local storage = require('aside.storage')

local M = {}

M.original_hover_handler = nil

-- Set up LSP hover integration
function M.setup()
  if M.original_hover_handler then
    return
  end

  M.original_hover_handler = vim.lsp.handlers["textDocument/hover"]

  vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
    local bufnr = vim.api.nvim_get_current_buf()
    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_number = cursor[1]

    local annotation = storage.get_at_location(file_path, line_number)

    if annotation then
      if not result or not result.contents then
        result = M.create_annotation_only_result(annotation)
      else
        result = M.append_annotation(result, annotation)
      end
    end

    if err or not result or not result.contents then
      return M.original_hover_handler(err, result, ctx, config)
    end

    return M.original_hover_handler(err, result, ctx, config)
  end
end

-- Restore original handler
function M.teardown()
  if M.original_hover_handler then
    vim.lsp.handlers["textDocument/hover"] = M.original_hover_handler
    M.original_hover_handler = nil
  end
end

-- Create hover result with annotation only
function M.create_annotation_only_result(annotation)
  return {
    contents = {
      kind = "markdown",
      value = string.format("**Note**\n\n%s", annotation.content)
    }
  }
end

-- Append annotation to hover result
function M.append_annotation(result, annotation)
  local contents = result.contents

  local annotation_text = string.format(
    "\n\n---\n\n**Note**\n\n%s",
    annotation.content
  )

  if type(contents) == "string" then
    result.contents = contents .. annotation_text
  elseif type(contents) == "table" then
    if contents.kind == "markdown" then
      contents.value = contents.value .. annotation_text
    elseif contents.kind == "plaintext" then
      contents.value = contents.value .. annotation_text
    elseif contents.value then
      contents.value = contents.value .. annotation_text
    elseif type(contents[1]) == "string" then
      contents[1] = contents[1] .. annotation_text
    elseif type(contents[1]) == "table" and contents[1].value then
      contents[1].value = contents[1].value .. annotation_text
    end
  end

  return result
end

return M
