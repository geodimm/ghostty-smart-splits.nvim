local MiniTest = require('mini.test')
local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

T['health checks prerequisites without Apple Events'] = function()
  local state = require('tests.helpers').mock()
  state.linux = true
  local original = vim.health
  local reports = {}
  MiniTest.finally(function()
    vim.health = original
  end)
  vim.health = setmetatable({}, {
    __index = function(_, level)
      return function(message)
        table.insert(reports, { level, message })
      end
    end,
  })
  require('ghostty_smart_splits.health').check()
  eq(#state.calls, 0)
  local warned = false
  for _, report in ipairs(reports) do
    if report[1] == 'warn' and report[2]:find('Only macOS', 1, true) then
      warned = true
    end
  end
  eq(warned, true)
end

return T
