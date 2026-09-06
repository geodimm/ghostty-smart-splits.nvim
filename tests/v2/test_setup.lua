local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

T['setup preserves smart-splits options and does not create mappings'] = function()
  local state = mock()
  local plugin = require('ghostty_smart_splits')
  require('smart-splits').setup({ default_amount = 5 })
  eq(plugin.setup(), true)
  eq(state.config.multiplexer_integration, 'ghostty')
  eq(state.config.at_edge, 'stop')
  eq(state.config.default_amount, 5)
  eq(vim.fn.maparg('<C-h>', 'n'), '')
end

T['unsupported sessions leave smart-splits configuration untouched'] = function()
  local state = mock()
  state.linux = true
  require('smart-splits').setup({ default_amount = 5 })
  eq(require('ghostty_smart_splits').setup(), false)
  eq(state.config, { default_amount = 5 })
  eq(#state.calls, 0)
end

return T
