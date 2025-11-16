-- Prevent loading the plugin twice
if vim.g.loaded_aside then
  return
end
vim.g.loaded_aside = true

-- Plugin loaded. Call require('aside').setup() to configure.
