---Plugin options, merged additively so a call that names one option leaves the
---rest alone. Read them as fields: `config.bridge`, not `config.get_bridge()`.
---@class GhosttySmartSplitsConfigModule
---@field key_table string Ghostty key table used while Neovim is active.
---@field bridge boolean Whether actions and pane lookups prefer the bridge.
---@field slow_threshold integer Effective v3 slow-operation threshold, in ms.
local M = {}

local BRIDGE_SLOW_MS = 100
local OSASCRIPT_SLOW_MS = 150

---@class GhosttySmartSplitsConfig
---@field key_table? string Name of the Ghostty key table used while Neovim is active.
---@field bridge? boolean Prefer the persistent bridge for actions and pane lookups (default false).
---@field slow_threshold? integer Milliseconds before v3 logs a slow-operation warning (default 100 with the bridge, 150 without).

local defaults = {
  key_table = 'nvim',
  bridge = false,
}

---slow_threshold is absent from `defaults` on purpose: it follows `bridge`
---until someone sets it, so there is no fixed value to store. Listing it here
---is what still makes it a known key.
local validators = {
  key_table = function(value)
    return type(value) == 'string' and value ~= '', 'key_table must be a non-empty string'
  end,
  bridge = function(value)
    return type(value) == 'boolean', 'bridge must be a boolean'
  end,
  slow_threshold = function(value)
    return type(value) == 'number' and value > 0 and value % 1 == 0, 'slow_threshold must be a positive integer'
  end,
}

local options = vim.deepcopy(defaults)

---Validate every option before anything is stored, so a rejected call leaves
---the previous configuration intact.
---@param opts table
local function validate(opts)
  for key, value in pairs(opts) do
    local validator = validators[key]
    assert(validator, ('unknown option `%s`'):format(tostring(key)))
    local ok, message = validator(value)
    assert(ok, message)
  end
end

---Merge over the current options rather than over the defaults. Ghostty holds
---the active key table and the bridge is toggled at runtime, so resetting
---either from a call that never mentioned it would desynchronise the plugin
---from the terminal. Call reset() for a clean slate.
---@param opts? GhosttySmartSplitsConfig
function M.setup(opts)
  opts = opts or {}
  validate(opts)
  options = vim.tbl_extend('force', options, opts)
end

---The key table `opts` would select, without applying it. Lets a caller reject
---a change before any option is stored.
---@param opts? GhosttySmartSplitsConfig
---@return string
function M.resolve_key_table(opts)
  local name = (opts or {}).key_table
  if name == nil then
    return options.key_table
  end
  local ok, message = validators.key_table(name)
  assert(ok, message)
  return name
end

---Restore every option to its default.
function M.reset()
  options = vim.deepcopy(defaults)
end

setmetatable(M, {
  __index = function(_, key)
    if key == 'slow_threshold' then
      return options.slow_threshold or (options.bridge and BRIDGE_SLOW_MS or OSASCRIPT_SLOW_MS)
    end
    return options[key]
  end,
})

return M
