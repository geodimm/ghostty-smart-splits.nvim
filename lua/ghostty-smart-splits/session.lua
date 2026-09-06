local M = {}
local bridge = require('ghostty-smart-splits.bridge')
local config = require('ghostty-smart-splits.config')
local ghostty = require('ghostty-smart-splits.ghostty')
local claimed = false
local claim_pending = false
local active = false
local claim_generation = 0
local attach_failures = 0
local attach_pending = false
-- Enough to outlast a permission prompt without pestering a Mac that will
-- never answer; each retry costs one osascript spawn.
local max_attach_failures = 5

---@param opts? GhosttySmartSplitsConfig
function M.configure(opts)
  local name = config.resolve_key_table(opts)
  if claimed and config.key_table ~= name then
    error('Release the active key table before changing key_table')
  end
  config.setup(opts)
  if not config.bridge then
    bridge.stop()
  end
end

function M.claim_keys()
  -- VimResume and FocusGained can overlap while the transport pumps events.
  -- Share the pending claim instead of sending a second activation via fallback.
  if not claimed and not claim_pending then
    claim_pending = true
    claimed = ghostty.perform('activate_key_table:' .. config.key_table)
    claim_pending = false
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

local function give_up()
  active = false
  pcall(vim.api.nvim_del_augroup_by_name, 'GhosttySmartSplits')
  vim.notify_once(
    'ghostty-smart-splits: could not reach Ghostty; see :checkhealth ghostty-smart-splits',
    vim.log.levels.WARN
  )
end

-- Attaching when already attached just re-claims, so this is also the handler
-- for the lifecycle events. ghostty.attach() coalesces concurrent requests and
-- answers every queued callback from the one lookup, so skip while a lookup is
-- in flight rather than counting its single failure once per caller.
local function attach_and_claim()
  if attach_pending then
    return true
  end
  attach_pending = true
  return ghostty.attach(function(attached)
    attach_pending = false
    if not active then
      return
    end
    if attached then
      attach_failures = 0
      schedule_claim()
      return
    end
    attach_failures = attach_failures + 1
    if attach_failures >= max_attach_failures then
      give_up()
    end
  end)
end

function M.activate()
  if not ghostty.detect() then
    return false
  end
  active = true
  attach_failures = 0
  attach_pending = false
  local group = vim.api.nvim_create_augroup('GhosttySmartSplits', { clear = true })
  -- The first Apple Event raises the macOS Automation prompt, which times out
  -- while the dialog waits to be answered, and Ghostty may not be scriptable
  -- yet at startup. Both clear up on their own, so retry on FocusGained: it is
  -- when the user has finished with the dialog, and it is proof that the pane
  -- about to be captured is ours rather than one focus wandered to.
  vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume', 'FocusGained' }, {
    group = group,
    callback = function(ev)
      if ev.event == 'VimResume' then
        active = true
      end
      attach_and_claim()
    end,
  })
  -- Clearing `active` is what makes the VimResume branch above matter: an
  -- attach still in flight when Neovim is suspended would otherwise claim the
  -- key table behind a user who has gone back to their shell.
  vim.api.nvim_create_autocmd('VimSuspend', {
    group = group,
    callback = function()
      active = false
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
  return attach_and_claim()
end

---Drop the lifecycle autocommands and every claim. `claim_generation` is
---bumped rather than zeroed so a `schedule_claim` still on the event loop from
---before the reset sees a stale generation and does nothing.
function M.reset()
  claimed = false
  claim_pending = false
  active = false
  claim_generation = claim_generation + 1
  attach_failures = 0
  attach_pending = false
  pcall(vim.api.nvim_del_augroup_by_name, 'GhosttySmartSplits')
end

return M
