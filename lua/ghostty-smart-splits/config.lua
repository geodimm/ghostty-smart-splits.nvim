local M = {}
local default_key_table = 'nvim'
local key_table = default_key_table

---@class GhosttySmartSplitsConfig
---@field key_table? string Name of the Ghostty key table used while Neovim is active.

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
  key_table = M.resolve_key_table(opts)
end

---@return string
function M.get_key_table()
  return key_table
end

return M
