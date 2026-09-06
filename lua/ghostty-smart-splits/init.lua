local M = {}
local ghostty = require('ghostty-smart-splits.ghostty')
local session = require('ghostty-smart-splits.session')

M.claim_keys = session.claim_keys
M.release_keys = session.release_keys

---Attach Ghostty and apply required smart-splits settings. False means unavailable.
---@param opts? GhosttySmartSplitsConfig
---@return boolean
function M.setup(opts)
  if not ghostty.detect() then
    return false
  end
  session.configure(opts)
  local smart_splits = require('smart-splits')
  if not ghostty.attach() then
    return false
  end
  smart_splits.setup({
    multiplexer_integration = 'ghostty',
    at_edge = 'stop',
  })
  return session.activate()
end

return M
