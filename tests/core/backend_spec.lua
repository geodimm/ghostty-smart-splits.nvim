local h = require('tests.helpers')
local mock = h.mock

describe('v3 backend', function()
  after_each(h.restore)

  it('configuration and detection have no side effects', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.setup({ key_table = 'editor' })
    backend.setup({ key_table = 'editor' })
    assert.is_true(backend.detect())
    assert.are.equal(0, #state.calls)
    assert.is_false(pcall(vim.api.nvim_get_autocmds, { group = 'GhosttySmartSplits' }))
    assert.is_false(backend.move('left'))
    assert.is_false(backend.resize('left'))
    assert.is_false(backend.move('left', { at_edge = 'split' }))
    assert.is_nil(backend.split) -- Core dropped `split` from the protocol.
    assert.are.equal(0, #state.calls)
    assert.is_true(backend.activate())
    h.wait_for_calls(state, 2)
    assert.are.equal('activate_key_table:editor', h.last_action(state))
  end)

  it('at_edge split becomes a Ghostty split and defers to core when it fails', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.activate()
    h.wait_for_calls(state, 2)
    state.responses = { ['goto_split:right'] = { code = 0, stdout = 'false' } }

    assert.is_true(backend.move('right', { at_edge = 'split' }))
    assert.are.equal('new_split:right', h.last_action(state))

    -- A move that lands never splits.
    assert.is_true(backend.move('left', { at_edge = 'split' }))
    assert.are.equal('goto_split:left', h.last_action(state))

    -- Every other at_edge stays core's business.
    local count = #state.calls
    assert.is_false(backend.move('right', { at_edge = 'stop' }))
    assert.is_false(backend.move('right', { at_edge = 'wrap' }))
    assert.is_false(backend.move('right'))
    assert.are.same(count + 3, #state.calls)

    -- Ghostty refusing the split returns the fallback to core.
    state.responses['new_split:right'] = { code = 0, stdout = 'false' }
    assert.is_false(backend.move('right', { at_edge = 'split' }))
  end)
end)
