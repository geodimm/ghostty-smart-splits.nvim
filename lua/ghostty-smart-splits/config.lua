local M = {}
local default_key_table = 'nvim'
local key_table = default_key_table
local bridge = false
local slow_threshold = 150

---@class GhosttySmartSplitsConfig
---@field key_table? string Name of the Ghostty key table used while Neovim is active.
---@field bridge? boolean Prefer the persistent bridge for actions (default false); false uses only osascript.
---@field slow_threshold? integer Milliseconds before v3 logs a slow-operation warning (default 100 with the bridge, 150 without).

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
  local threshold = (opts or {}).slow_threshold
  if threshold == nil then
    threshold = enabled and 100 or 150
  end
  assert(
    type(threshold) == 'number' and threshold > 0 and threshold % 1 == 0,
    'slow_threshold must be a positive integer'
  )
  key_table = name
  bridge = enabled
  slow_threshold = threshold
end

---@return boolean
function M.get_bridge()
  return bridge
end

---@return string
function M.get_key_table()
  return key_table
end

---@return integer
function M.get_slow_threshold()
  return slow_threshold
end

return M
