local h = require('tests.helpers')
local mock = h.mock

describe('v2 setup', function()
  after_each(h.restore)

  it('setup preserves smart-splits options and does not create mappings', function()
    local state = mock()
    local plugin = require('ghostty_smart_splits')
    require('smart-splits').setup({ default_amount = 5 })
    assert.is_true(plugin.setup())
    assert.are.equal('ghostty', state.config.multiplexer_integration)
    assert.are.equal('stop', state.config.at_edge)
    assert.are.equal(5, state.config.default_amount)
    assert.are.equal('', vim.fn.maparg('<C-h>', 'n'))
  end)

  it('unsupported sessions leave smart-splits configuration untouched', function()
    local state = mock()
    state.linux = true
    require('smart-splits').setup({ default_amount = 5 })
    assert.is_false(require('ghostty_smart_splits').setup())
    assert.are.same({ default_amount = 5 }, state.config)
    assert.are.equal(0, #state.calls)
  end)
end)
