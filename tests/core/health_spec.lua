local h = require('tests.helpers')

describe('health', function()
  after_each(h.restore)

  it('health checks prerequisites without Apple Events', function()
    local state = h.mock()
    state.linux = true
    local reports = {}
    h.stub(
      vim,
      'health',
      setmetatable({}, {
        __index = function(_, level)
          return function(message)
            table.insert(reports, { level, message })
          end
        end,
      })
    )
    require('ghostty-smart-splits.health').check()
    assert.are.equal(0, #state.calls)
    local warned = false
    for _, report in ipairs(reports) do
      if report[1] == 'warn' and report[2]:find('Only macOS', 1, true) then
        warned = true
      end
    end
    assert.is_true(warned)
  end)

  it('health reports bridge preference and availability without starting it', function()
    local state = h.mock()
    local reports
    h.stub(
      vim,
      'health',
      setmetatable({}, {
        __index = function(_, level)
          return function(message)
            table.insert(reports, { level, message })
          end
        end,
      })
    )
    local function check(expected_level, expected_message)
      reports = {}
      require('ghostty-smart-splits.health').check()
      local found = false
      for _, report in ipairs(reports) do
        if report[1] == expected_level and report[2]:find(expected_message, 1, true) then
          found = true
        end
      end
      assert.is_true(found)
      assert.are.equal(0, #state.bridge_starts)
      assert.are.equal(0, #state.calls)
    end
    check('info', 'bridge = false: actions use osascript')
    require('smart-splits-backend-ghostty').setup({ bridge = true })
    check('warn', 'bridge = true: binary is missing')
    state.bridge_available = true
    check('info', 'bridge = true: binary is available')
    require('smart-splits-backend-ghostty').setup({ bridge = false })
    check('info', 'bridge = false: actions use osascript')
  end)
end)
