local M = {}
local mux = require('ghostty_smart_splits.mux')
local claimed = false
local key_table = 'nvim'
local directions = { left = true, down = true, up = true, right = true }

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

function M.move(direction)
  assert(directions[direction], 'Invalid direction: ' .. tostring(direction))
  if require('ghostty_smart_splits.navigation').move(direction) then
    return true
  end
  return mux.perform('goto_split:' .. direction)
end

---Configure smart-splits and the Ghostty bridge. False means unsupported/unavailable.
function M.setup(opts)
  opts = opts or {}
  if not mux.is_in_session() then
    return false
  end
  local config = vim.tbl_deep_extend('force', {
    key_table = 'nvim',
    keymaps = { left = '<C-h>', down = '<C-j>', up = '<C-k>', right = '<C-l>' },
    modes = { 'n', 'v', 't' },
    smart_splits = {},
  }, opts)
  assert(type(config.key_table) == 'string' and config.key_table ~= '', 'key_table must be a non-empty string')
  assert(config.keymaps == false or type(config.keymaps) == 'table', 'keymaps must be a table or false')
  if claimed and key_table ~= config.key_table then
    error('Release the active key table before changing key_table')
  end
  local smart_splits = require('smart-splits')
  if not mux.attach() then
    return false
  end
  key_table = config.key_table
  smart_splits.setup(vim.tbl_deep_extend('force', config.smart_splits, {
    multiplexer_integration = 'ghostty',
    disable_multiplexer_nav_when_zoomed = false,
    at_edge = 'stop',
  }))
  if config.keymaps then
    for direction, lhs in pairs(config.keymaps) do
      assert(directions[direction], 'Invalid keymap direction: ' .. direction)
      if lhs then
        vim.keymap.set(config.modes, lhs, function()
          M.move(direction)
        end, { silent = true, desc = 'Navigate ' .. direction .. ' (Neovim/Ghostty)' })
      end
    end
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
