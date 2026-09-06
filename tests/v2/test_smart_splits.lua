local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality

local function wait_for_calls(state, count)
  assert(vim.wait(100, function()
    return #state.calls >= count
  end, 1))
end

T['real smart-splits loads the backend and forwards actions'] = function()
  local state = require('tests.helpers').mock()
  package.loaded['smart-splits'] = nil
  local splits = require('smart-splits')
  splits.setup({ default_amount = 5 })
  eq(require('ghostty_smart_splits').setup(), true)
  wait_for_calls(state, 2)
  local mux_api = require('smart-splits.mux')
  eq(mux_api.get(), require('smart-splits.mux.ghostty'))
  eq(require('smart-splits.config').at_edge, 'stop')
  eq(require('smart-splits.config').default_amount, 5)
  state.next_id = 'terminal-2'
  splits.move_cursor_right()
  local moved = false
  for _, call in ipairs(state.calls) do
    moved = moved or call[4] == 'goto_split:right'
  end
  eq(moved, true)
  eq(mux_api.resize_pane('right', 4), true)
  eq(state.calls[#state.calls][4], 'resize_split:right,40')
  eq(mux_api.split_pane('down', 12), true)
  eq(state.calls[#state.calls][4], 'new_split:down')
end

-- v2 brackets every move with a pane lookup, so all three round trips must take
-- the bridge; routing only the action left two osascript spawns per keypress.
T['an edge move over the bridge never spawns osascript'] = function()
  local state = require('tests.helpers').mock()
  state.bridge_available = true
  package.loaded['smart-splits'] = nil
  local splits = require('smart-splits')
  splits.setup({})
  eq(require('ghostty-smart-splits').setup({ bridge = true }), true)
  wait_for_calls(state, 1) -- Attachment is the one osascript call.
  vim.wait(20, function()
    return false
  end)

  local spawns, requests = #state.calls, #state.bridge_requests
  state.next_id = 'terminal-2'
  splits.move_cursor_right()
  eq(#state.calls, spawns)
  local commands = vim.tbl_map(function(request)
    return request.command
  end, vim.list_slice(state.bridge_requests, requests + 1))
  eq(commands, { 'focused-terminal-id', 'perform', 'focused-terminal-id' })
end

return T
