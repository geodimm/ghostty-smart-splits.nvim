-- smart-splits v3 interface; transport and lifecycle are shared with v2.
local ghostty = require('ghostty-smart-splits.ghostty')
local session = require('ghostty-smart-splits.session')
local M = { name = 'ghostty', protocol_version = 3 }

-- Configuration is inert: only the selected backend may attach or claim keys.
M.setup = session.configure
M.detect = ghostty.detect
M.activate = session.activate

function M.move(direction, _opts)
  -- Ghostty pane wrapping is unsupported. On false, core handles the fallback.
  return ghostty.move(direction)
end

function M.resize(direction, opts)
  return ghostty.resize(direction, (opts or {}).amount)
end

function M.split(direction, _opts)
  return ghostty.split(direction)
end

function M.health()
  require('ghostty-smart-splits.health').report()
  vim.health.info('Ghostty pane wrapping and zoom detection are not implemented; failed moves use the core fallback')
end

return M
