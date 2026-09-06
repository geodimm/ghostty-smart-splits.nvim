local MiniTest = require('mini.test')
local T = MiniTest.new_set()
local eq = MiniTest.expect.equality
local mock = require('tests.helpers').mock

local function wait_for_calls(state, count)
  assert(vim.wait(100, function()
    return #state.calls >= count
  end, 1))
end

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
  eq(backend.move('left', { at_edge = 'split' }), false)
  eq(backend.split, nil) -- Core dropped `split` from the protocol.
  eq(#state.calls, 0)
  eq(backend.activate(), true)
  wait_for_calls(state, 2)
  eq(state.calls[#state.calls][4], 'activate_key_table:editor')
  eq(state.config, nil)
end

T['slow threshold follows bridge mode and supports an override'] = function()
  mock()
  local backend = require('smart-splits-backend-ghostty')
  eq(backend.slow_threshold, 150)
  backend.setup({ bridge = true })
  eq(backend.slow_threshold, 100)
  backend.setup({ bridge = false })
  eq(backend.slow_threshold, 150)
  backend.setup({ slow_threshold = 250 })
  eq(backend.slow_threshold, 250)
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
  wait_for_calls(state, 2)
  state.id = 'terminal-2'
  for _, direction in ipairs({ 'left', 'right', 'up', 'down' }) do
    eq(backend.move(direction, { at_edge = 'stop', future = true }), true)
    eq(vim.list_slice(state.calls[#state.calls], 3), { 'terminal-1', 'goto_split:' .. direction })
    eq(backend.resize(direction, { amount = 4, future = true }), true)
    eq(state.calls[#state.calls][4], 'resize_split:' .. direction .. ',40')
  end
  eq(backend.resize('left'), true)
  eq(state.calls[#state.calls][4], 'resize_split:left,30')
  eq(backend.resize('left', {}), true)
  eq(state.calls[#state.calls][4], 'resize_split:left,30')
  eq(state.system_opts.timeout, 1000)
  state.response = { code = 0, stdout = 'false' }
  eq(backend.move('left', { at_edge = 'wrap' }), false)
  eq(backend.resize('left'), false)
  eq(backend.move('left', { at_edge = 'split' }), false)
  state.spawn_error = true
  eq(backend.move('left'), false)
  state.spawn_error = false
  state.response = { code = 124, stderr = 'timed out' }
  eq(backend.move('left'), false)
  vim.env.TERM_PROGRAM = 'other'
  local count = #state.calls
  eq(backend.move('left'), false)
  eq(backend.resize('left'), false)
  eq(backend.move('left', { at_edge = 'split' }), false)
  eq(#state.calls, count)
end

-- Core hands `at_edge` to the backend and only acts on a false return, so the
-- Ghostty split has to happen inside move().
T['at_edge split becomes a Ghostty split and defers to core when it fails'] = function()
  local state = mock()
  local backend = require('smart-splits-backend-ghostty')
  backend.activate()
  wait_for_calls(state, 2)
  state.responses = { ['goto_split:right'] = { code = 0, stdout = 'false' } }

  eq(backend.move('right', { at_edge = 'split' }), true)
  eq(state.calls[#state.calls][4], 'new_split:right')

  -- A move that lands never splits.
  eq(backend.move('left', { at_edge = 'split' }), true)
  eq(state.calls[#state.calls][4], 'goto_split:left')

  -- Every other at_edge stays core's business.
  local count = #state.calls
  eq(backend.move('right', { at_edge = 'stop' }), false)
  eq(backend.move('right', { at_edge = 'wrap' }), false)
  eq(backend.move('right'), false)
  eq(#state.calls, count + 3)

  -- Ghostty refusing the split returns the fallback to core.
  state.responses['new_split:right'] = { code = 0, stdout = 'false' }
  eq(backend.move('right', { at_edge = 'split' }), false)
end

T['failed activation never follows focus during operations'] = function()
  local state = mock()
  local backend = require('smart-splits-backend-ghostty')
  state.id = ''
  eq(backend.activate(), true)
  wait_for_calls(state, 1)
  state.id = 'unrelated-terminal'
  eq(backend.move('right'), false)
  eq(backend.resize('right'), false)
  eq(backend.move('right', { at_edge = 'split' }), false)
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
  wait_for_calls(state, 2)
  for _ = 1, 2 do
    vim.api.nvim_exec_autocmds('VimEnter', {})
    eq(#state.calls, 2 + (_ - 1) * 2)
    state.id = 'unrelated-terminal'
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    eq(vim.list_slice(state.calls[#state.calls], 3), { 'terminal-1', 'deactivate_key_table' })
    local count = #state.calls
    vim.api.nvim_exec_autocmds('VimResume', {})
    wait_for_calls(state, count + 1)
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
