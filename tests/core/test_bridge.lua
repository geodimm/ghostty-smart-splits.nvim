---@diagnostic disable: duplicate-set-field
local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

local function wait_for_bridge_requests(state, count)
  assert(vim.wait(100, function()
    return #state.bridge_requests >= count
  end, 1))
end

local function wait_for_calls(state, count)
  assert(vim.wait(100, function()
    return #state.calls >= count
  end, 1))
  vim.wait(10, function()
    return false
  end, 1)
end

T['v2 disables a built bridge and routes actions through osascript'] = function()
  local state = mock()
  state.bridge_available = true
  local bridge = require('ghostty-smart-splits.bridge')
  bridge.start = function()
    error('disabled bridge must not be started')
  end
  bridge.request = function()
    error('disabled bridge must not receive requests')
  end
  eq(require('ghostty-smart-splits').setup(), true)
  eq(require('ghostty-smart-splits').setup({ bridge = false }), true)
  wait_for_calls(state, 2)
  local ghostty = require('ghostty-smart-splits.ghostty')
  eq(ghostty.move('right'), true)
  eq(#state.bridge_starts, 0)
  eq(#state.bridge_requests, 0)
  eq(state.calls[#state.calls][4], 'goto_split:right')
  eq(bridge.status().running, false)
end

T['v3 configures before activation and reuses one bridge for actions'] = function()
  local state = mock()
  state.bridge_available = true
  local backend = require('smart-splits-backend-ghostty')
  backend.setup({ bridge = true })
  eq(#state.bridge_starts, 0)
  eq(#state.calls, 0)
  eq(backend.activate(), true)
  wait_for_bridge_requests(state, 1)
  eq(backend.move('right'), true)
  eq(backend.resize('left', { amount = 4 }), true)
  eq(#state.bridge_starts, 1)
  local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
  eq(state.bridge_starts[1][1], root .. '/bin/ghostty-smart-splits-bridge')
  eq(#state.calls, 1) -- Only the initial terminal lookup uses osascript.
  eq(state.bridge_requests[1].action, 'activate_key_table:nvim')
  eq(state.bridge_requests[2], { command = 'perform', terminalID = 'terminal-1', action = 'goto_split:right' })
  eq(state.bridge_requests[3].action, 'resize_split:left,40')
  vim.api.nvim_exec_autocmds('VimLeavePre', {})
  eq(state.bridge_requests[4].action, 'deactivate_key_table')
  eq(#state.bridge_stops, 1)
end

T['disabling stops the bridge immediately and enabling waits for an action'] = function()
  local state = mock()
  state.bridge_available = true
  local backend = require('smart-splits-backend-ghostty')
  backend.setup({ bridge = true })
  backend.activate()
  assert(vim.wait(100, function()
    return #state.bridge_starts == 1
  end, 1))
  backend.setup({ bridge = false })
  eq(#state.bridge_stops, 1)
  eq(require('ghostty-smart-splits.bridge').status().running, false)
  eq(backend.move('left'), true)
  eq(state.calls[#state.calls][4], 'goto_split:left')
  backend.setup({ bridge = true })
  eq(#state.bridge_starts, 1)
  eq(backend.move('right'), true)
  eq(#state.bridge_starts, 2)
  eq(state.bridge_requests[#state.bridge_requests].action, 'goto_split:right')
end

T['enabled bridge falls back when missing or unable to start'] = function()
  local state = mock()
  local backend = require('smart-splits-backend-ghostty')
  backend.setup({ bridge = true })
  state.bridge_available = true
  eq(backend.activate(), true)
  assert(vim.wait(100, function()
    return #state.bridge_starts == 1
  end, 1))
  require('ghostty-smart-splits.bridge').stop()
  state.bridge_start_failure = true
  eq(backend.move('right'), true)
  eq(#state.bridge_starts, 2)
  eq(state.calls[#state.calls][4], 'goto_split:right')
end

return T
