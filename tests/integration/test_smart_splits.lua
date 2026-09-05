local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality

T['real smart-splits loads the backend and forwards resize/split actions'] = function()
  local state = require('tests.helpers').mock()
  package.loaded['smart-splits'] = nil
  eq(require('ghostty_smart_splits').setup({ keymaps = false }), true)
  local mux_api = require('smart-splits.mux')
  eq(mux_api.get(), require('ghostty_smart_splits.mux'))
  eq(require('smart-splits.config').at_edge, 'stop')
  eq(mux_api.resize_pane('right', 4), true)
  eq(state.calls[#state.calls][4], 'resize_split:right,40')
  eq(mux_api.split_pane('down', 12), true)
  eq(state.calls[#state.calls][4], 'new_split:down')
end

return T
