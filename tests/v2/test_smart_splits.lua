local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality

T['real smart-splits loads the backend and forwards actions'] = function()
  local state = require('tests.helpers').mock()
  package.loaded['smart-splits'] = nil
  local splits = require('smart-splits')
  splits.setup({ default_amount = 5 })
  eq(require('ghostty_smart_splits').setup(), true)
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

return T
