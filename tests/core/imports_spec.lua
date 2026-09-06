local h = require('tests.helpers')

describe('v2 module imports', function()
  after_each(h.restore)

  for _, suffix in ipairs({ '', '.health' }) do
    it('underscore import warns once and preserves module identity: ' .. suffix, function()
      local warnings = {}
      h.stub(package.loaded, 'ghostty_smart_splits' .. suffix, nil)
      h.stub(vim, 'notify_once', function(message)
        table.insert(warnings, message)
      end)
      local canonical = require('ghostty-smart-splits' .. suffix)
      assert.are.equal(0, #warnings)
      assert.are.equal(canonical, require('ghostty_smart_splits' .. suffix))
      assert.are.equal(canonical, require('ghostty_smart_splits' .. suffix))
      assert.are.equal(1, #warnings)
      assert.is_true(warnings[1]:find("require('ghostty_smart_splits" .. suffix .. "') is deprecated", 1, true) ~= nil)
      assert.is_true(warnings[1]:find("require('ghostty-smart-splits" .. suffix .. "')", 1, true) ~= nil)
    end)
  end
end)
