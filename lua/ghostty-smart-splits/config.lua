local M = {}
local default_key_table = 'nvim'
local key_table = default_key_table
local bridge = false

---@class GhosttySmartSplitsConfig
---@field key_table? string Name of the Ghostty key table used while Neovim is active.
---@field bridge? boolean Prefer the persistent bridge for actions (default false); false uses only osascript.

---@param opts? GhosttySmartSplitsConfig
---@return string
function M.resolve_key_table(opts)
  local name = (opts or {}).key_table
  if name == nil then
    return default_key_table
  end
  assert(type(name) == 'string' and name ~= '', 'key_table must be a non-empty string')
  return name
end

---@param opts? GhosttySmartSplitsConfig
function M.setup(opts)
  local name = M.resolve_key_table(opts)
  local enabled = (opts or {}).bridge
  if enabled == nil then
    enabled = false
  end
  assert(type(enabled) == 'boolean', 'bridge must be a boolean')
  key_table = name
  bridge = enabled
end

---@return boolean
function M.get_bridge()
  return bridge
end

---@return string
function M.get_key_table()
  return key_table
end

return M
