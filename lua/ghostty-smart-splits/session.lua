local M = {}
local ghostty = require('ghostty-smart-splits.ghostty')
local claimed = false
local key_table = 'nvim'

function M.configure(opts)
  local name = (opts or {}).key_table
  if name == nil then
    name = 'nvim'
  end
  assert(type(name) == 'string' and name ~= '', 'key_table must be a non-empty string')
  if claimed and key_table ~= name then
    error('Release the active key table before changing key_table')
  end
  key_table = name
end

function M.claim_keys()
  if not claimed then
    claimed = ghostty.perform('activate_key_table:' .. key_table)
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
