local M = {}
local bridge = require('ghostty-smart-splits.bridge')
local config = require('ghostty-smart-splits.config')
local ghostty = require('ghostty-smart-splits.ghostty')
local claimed = false
local active = false
local claim_generation = 0

---@param opts? GhosttySmartSplitsConfig
function M.configure(opts)
  local name = config.resolve_key_table(opts)
  if claimed and config.get_key_table() ~= name then
    error('Release the active key table before changing key_table')
  end
  config.setup(opts)
  if not config.get_bridge() then
    bridge.stop()
  end
end

function M.claim_keys()
  if not claimed then
    claimed = ghostty.perform('activate_key_table:' .. config.get_key_table())
  end
  return claimed
end

function M.release_keys()
  claim_generation = claim_generation + 1
  if claimed and ghostty.perform('deactivate_key_table') then
    claimed = false
  end
  return not claimed
end

local function schedule_claim()
  claim_generation = claim_generation + 1
  local generation = claim_generation
  vim.schedule(function()
    if active and generation == claim_generation then
      M.claim_keys()
    end
  end)
end

function M.activate()
  if not ghostty.detect() then
    return false
  end
  active = true
  local group = vim.api.nvim_create_augroup('GhosttySmartSplits', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume' }, {
    group = group,
    callback = function(ev)
      if ev.event == 'VimResume' then
        active = true
      end
      schedule_claim()
    end,
  })
  vim.api.nvim_create_autocmd('VimSuspend', {
    group = group,
    callback = function()
      M.release_keys()
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      active = false
      M.release_keys()
      bridge.stop()
    end,
  })
  return ghostty.attach(function(attached)
    if not active then
      return
    end
    if attached then
      schedule_claim()
    else
      active = false
      pcall(vim.api.nvim_del_augroup_by_name, 'GhosttySmartSplits')
    end
  end)
end

return M
