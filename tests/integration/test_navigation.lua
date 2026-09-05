local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

T['Neovim neighbors win; only edges reach Ghostty'] = function()
  local state = mock()
  local plugin = require('ghostty_smart_splits')
  eq(plugin.setup(), true)
  eq(state.config.multiplexer_integration, 'ghostty')
  local initial = #state.calls
  vim.cmd('vsplit')
  local left = vim.api.nvim_get_current_win()
  vim.cmd('wincmd l')
  local right = vim.api.nvim_get_current_win()
  vim.fn.maparg('<C-h>', 'n', false, true).callback()
  eq(vim.api.nvim_get_current_win(), left)
  vim.fn.maparg('<C-l>', 'n', false, true).callback()
  eq(vim.api.nvim_get_current_win(), right)
  eq(#state.calls, initial)
  eq(plugin.move('right'), true)
  eq(state.calls[#state.calls][4], 'goto_split:right')
  vim.cmd('only!')
  vim.cmd('split')
  local top = vim.api.nvim_get_current_win()
  vim.cmd('wincmd j')
  local bottom = vim.api.nvim_get_current_win()
  initial = #state.calls
  plugin.move('up')
  eq(vim.api.nvim_get_current_win(), top)
  plugin.move('down')
  eq(vim.api.nvim_get_current_win(), bottom)
  eq(#state.calls, initial)
end

T['lifecycle events push once and pop once across repeated resumes'] = function()
  local state = mock()
  local plugin = require('ghostty_smart_splits')
  plugin.setup({ keymaps = false })
  plugin.setup({ keymaps = false })
  eq(#state.calls, 2)
  for _ = 1, 2 do
    vim.api.nvim_exec_autocmds('VimEnter', {})
    eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    eq(state.calls[#state.calls][4], 'deactivate_key_table')
    local count = #state.calls
    plugin.release_keys()
    eq(#state.calls, count)
    vim.api.nvim_exec_autocmds('VimResume', {})
    eq(#state.calls, count + 1)
    eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
  end
  vim.api.nvim_exec_autocmds('VimLeavePre', {})
  eq(state.calls[#state.calls][4], 'deactivate_key_table')
end

T['custom tables, no keymaps, and failed release retries'] = function()
  local state = mock()
  local plugin = require('ghostty_smart_splits')
  local opts = { keymaps = false, key_table = 'editor', smart_splits = { default_amount = 5 } }
  plugin.setup(opts)
  eq(state.calls[#state.calls][4], 'activate_key_table:editor')
  eq(state.config.default_amount, 5)
  eq(opts.smart_splits.multiplexer_integration, nil)
  eq(vim.fn.maparg('<C-h>', 'n'), '')
  state.response = { code = 0, stdout = 'false' }
  eq(plugin.release_keys(), false)
  state.response = { code = 0, stdout = 'true' }
  eq(plugin.release_keys(), true)
end

T['low-zindex sidebar floats can return to a regular window'] = function()
  mock()
  local plugin = require('ghostty_smart_splits')
  plugin.setup()
  local main = vim.api.nvim_get_current_win()
  vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
    relative = 'editor',
    row = 0,
    col = 0,
    width = 12,
    height = 8,
    zindex = 40,
    style = 'minimal',
  })
  eq(plugin.move('right'), true)
  eq(vim.api.nvim_get_current_win(), main)
end

return T
