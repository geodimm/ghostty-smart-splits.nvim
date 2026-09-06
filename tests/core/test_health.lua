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
  require('ghostty-smart-splits.health').check()
  eq(#state.calls, 0)
  local warned = false
  for _, report in ipairs(reports) do
    if report[1] == 'warn' and report[2]:find('Only macOS', 1, true) then
      warned = true
    end
  end
  eq(warned, true)
end

T['health reports bridge preference and availability without starting it'] = function()
  local state = require('tests.helpers').mock()
  local original = vim.health
  MiniTest.finally(function()
    vim.health = original
  end)
  local reports
  vim.health = setmetatable({}, {
    __index = function(_, level)
      return function(message)
        table.insert(reports, { level, message })
      end
    end,
  })
  local function check(expected_level, expected_message)
    reports = {}
    require('ghostty-smart-splits.health').check()
    local found = false
    for _, report in ipairs(reports) do
      if report[1] == expected_level and report[2]:find(expected_message, 1, true) then
        found = true
      end
    end
    eq(found, true)
    eq(#state.bridge_starts, 0)
    eq(#state.calls, 0)
  end
  check('info', 'bridge = false: actions use osascript')
  require('smart-splits-backend-ghostty').setup({ bridge = true })
  check('warn', 'bridge = true: binary is missing')
  state.bridge_available = true
  check('info', 'bridge = true: binary is available')
  require('smart-splits-backend-ghostty').setup({ bridge = false })
  check('info', 'bridge = false: actions use osascript')
end

return T
