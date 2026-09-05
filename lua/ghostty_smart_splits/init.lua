local M = {}
local mux = require('ghostty_smart_splits.mux')
local claimed = false
local key_table = 'nvim'

function M.claim_keys()
  if not claimed then
    claimed = mux.perform('activate_key_table:' .. key_table)
  end
  return claimed
end

function M.release_keys()
  if claimed and mux.perform('deactivate_key_table') then
    claimed = false
  end
  return not claimed
end

---Attach Ghostty and apply required smart-splits settings. False means unavailable.
function M.setup(opts)
  opts = opts or {}
  if not mux.is_in_session() then
    return false
  end
  local config = vim.tbl_deep_extend('force', {
    key_table = 'nvim',
  }, opts)
  assert(type(config.key_table) == 'string' and config.key_table ~= '', 'key_table must be a non-empty string')
  if claimed and key_table ~= config.key_table then
    error('Release the active key table before changing key_table')
  end
  local smart_splits = require('smart-splits')
  if not mux.attach() then
    return false
  end
  key_table = config.key_table
  smart_splits.setup({
    multiplexer_integration = 'ghostty',
    at_edge = 'stop',
  })
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
