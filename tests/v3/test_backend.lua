local MiniTest = require('mini.test')
local T = MiniTest.new_set()
local eq = MiniTest.expect.equality
local mock = require('tests.helpers').mock

T['configuration and detection have no side effects'] = function()
  local state = mock()
  local backend = require('smart-splits-backend-ghostty')
  backend.setup({ key_table = 'editor' })
  backend.setup({ key_table = 'editor' })
  eq(backend.detect(), true)
  eq(#state.calls, 0)
  eq(state.config, nil)
  eq(pcall(vim.api.nvim_get_autocmds, { group = 'GhosttySmartSplits' }), false)
  eq(backend.move('left'), false)
  eq(backend.resize('left'), false)
  eq(backend.split('left'), false)
  eq(#state.calls, 0)
  eq(backend.activate(), true)
  eq(state.calls[#state.calls][4], 'activate_key_table:editor')
  eq(state.config, nil)
end

T['v3 loads independently of the v2 adapter'] = function()
  mock()
  require('smart-splits-backend-ghostty').activate()
  eq(type(package.loaded['ghostty-smart-splits.ghostty']), 'table')
  eq(package.loaded['smart-splits.mux.ghostty'], nil)
end

T['v3 options use the shared transport and captured terminal'] = function()
  local state = mock()
  local backend = require('smart-splits-backend-ghostty')
  backend.activate()
  state.id = 'terminal-2'
  for _, direction in ipairs({ 'left', 'right', 'up', 'down' }) do
    eq(backend.move(direction, { wrap = true, future = true }), true)
    eq(vim.list_slice(state.calls[#state.calls], 3), { 'terminal-1', 'goto_split:' .. direction })
    eq(backend.resize(direction, { amount = 4, future = true }), true)
    eq(state.calls[#state.calls][4], 'resize_split:' .. direction .. ',40')
    eq(backend.split(direction, { future = true }), true)
    eq(state.calls[#state.calls][4], 'new_split:' .. direction)
  end
  eq(backend.resize('left'), true)
  eq(state.calls[#state.calls][4], 'resize_split:left,30')
  eq(backend.resize('left', {}), true)
  eq(state.calls[#state.calls][4], 'resize_split:left,30')
  eq(state.system_opts.timeout, 1000)
  state.response = { code = 0, stdout = 'false' }
  eq(backend.move('left', { wrap = true }), false)
  eq(backend.resize('left'), false)
  eq(backend.split('left'), false)
  state.spawn_error = true
  eq(backend.move('left'), false)
  state.spawn_error = false
  state.response = { code = 124, stderr = 'timed out' }
  eq(backend.move('left'), false)
  vim.env.TERM_PROGRAM = 'other'
  local count = #state.calls
  eq(backend.move('left'), false)
  eq(backend.resize('left'), false)
  eq(backend.split('left'), false)
  eq(#state.calls, count)
end

T['failed activation never follows focus during operations'] = function()
  local state = mock()
  local backend = require('smart-splits-backend-ghostty')
  state.id = ''
  eq(backend.activate(), false)
  state.id = 'unrelated-terminal'
  eq(backend.move('right'), false)
  eq(backend.resize('right'), false)
  eq(backend.split('right'), false)
  eq(#state.calls, 1)
end

T['both module names and interfaces share key-table ownership'] = function()
  local state = mock()
  local legacy = require('ghostty_smart_splits')
  eq(legacy, require('ghostty-smart-splits'))
  eq(require('ghostty_smart_splits.health'), require('ghostty-smart-splits.health'))
  legacy.setup()
  local backend = require('smart-splits-backend-ghostty')
  backend.activate()
  eq(#state.calls, 2)
  for _ = 1, 2 do
    vim.api.nvim_exec_autocmds('VimEnter', {})
    eq(#state.calls, 2 + (_ - 1) * 2)
    state.id = 'unrelated-terminal'
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    eq(vim.list_slice(state.calls[#state.calls], 3), { 'terminal-1', 'deactivate_key_table' })
    vim.api.nvim_exec_autocmds('VimResume', {})
    eq(vim.list_slice(state.calls[#state.calls], 3), { 'terminal-1', 'activate_key_table:nvim' })
  end
  vim.api.nvim_exec_autocmds('VimLeavePre', {})
  local count = #state.calls
  eq(legacy.release_keys(), true)
  eq(#state.calls, count)
end

T['backend health emits no section header or Apple Events'] = function()
  local state = mock()
  state.linux = true
  local original = vim.health
  local reports = {}
  MiniTest.finally(function()
    vim.health = original
  end)
  vim.health = setmetatable({}, {
    __index = function(_, level)
      return function()
        assert(level ~= 'start', 'core owns the health header')
        table.insert(reports, level)
      end
    end,
  })
  require('smart-splits-backend-ghostty').health()
  eq(#reports > 0, true)
  eq(#state.calls, 0)
end

return T
