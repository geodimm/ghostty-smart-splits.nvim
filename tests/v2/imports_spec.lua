local h = require('tests.helpers')

describe('v2 module imports', function()
  after_each(h.restore)

  for _, suffix in ipairs({ '', '.health' }) do
    it('underscore import warns once and preserves module identity: ' .. suffix, function()
      local state = h.mock()
      local canonical = require('ghostty-smart-splits' .. suffix)
      assert.are.equal(0, #state.warnings)
      assert.are.equal(canonical, require('ghostty_smart_splits' .. suffix))
      assert.are.equal(canonical, require('ghostty_smart_splits' .. suffix))
      assert.are.equal(1, #state.warnings)
      assert.is_true(
        state.warnings[1]:find("require('ghostty_smart_splits" .. suffix .. "') is deprecated", 1, true) ~= nil
      )
      assert.is_true(state.warnings[1]:find("require('ghostty-smart-splits" .. suffix .. "')", 1, true) ~= nil)
      assert.are.equal(0, #state.calls)
    end)
  end
end)
