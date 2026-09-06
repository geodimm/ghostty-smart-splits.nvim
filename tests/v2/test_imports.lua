local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality

for _, suffix in ipairs({ '', '.health' }) do
  T['underscore import warns once and preserves module identity: ' .. suffix] = function()
    local state = require('tests.helpers').mock()
    local canonical = require('ghostty-smart-splits' .. suffix)
    eq(#state.warnings, 0)
    eq(require('ghostty_smart_splits' .. suffix), canonical)
    eq(require('ghostty_smart_splits' .. suffix), canonical)
    eq(#state.warnings, 1)
    eq(state.warnings[1]:find("require('ghostty_smart_splits" .. suffix .. "') is deprecated", 1, true) ~= nil, true)
    eq(state.warnings[1]:find("require('ghostty-smart-splits" .. suffix .. "')", 1, true) ~= nil, true)
    eq(#state.calls, 0)
  end
end

return T
