local M = {}
local config = require('ghostty-smart-splits.config')
local ghostty = require('ghostty-smart-splits.ghostty')
local claimed = false

---@param opts? GhosttySmartSplitsConfig
function M.configure(opts)
  local name = config.resolve_key_table(opts)
  if claimed and config.get_key_table() ~= name then
    error('Release the active key table before changing key_table')
  end
  config.setup(opts)
end

function M.claim_keys()
  if not claimed then
    claimed = ghostty.perform('activate_key_table:' .. config.get_key_table())
  end
  return claimed
end

function M.release_keys()
  if claimed and ghostty.perform('deactivate_key_table') then
    claimed = false
  end
  return not claimed
end

function M.activate()
  if not ghostty.detect() or not ghostty.attach() then
    return false
  end
  local group = vim.api.nvim_create_augroup('GhosttySmartSplits', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume' }, {
    group = group,
    callback = function()
      M.claim_keys()
    end,
  })
  vim.api.nvim_create_autocmd({ 'VimLeavePre', 'VimSuspend' }, {
    group = group,
    callback = function()
      M.release_keys()
    end,
  })
  M.claim_keys()
  return true
end

return M
