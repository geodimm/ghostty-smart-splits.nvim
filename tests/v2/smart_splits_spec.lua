local h = require('tests.helpers')

describe('v2 smart-splits integration', function()
  after_each(h.restore)

  it('real smart-splits loads the backend and forwards actions', function()
    local state = h.mock()
    package.loaded['smart-splits'] = nil
    local splits = require('smart-splits')
    splits.setup({ default_amount = 5 })
    assert.is_true(require('ghostty_smart_splits').setup())
    h.wait_for_calls(state, 2)
    local mux_api = require('smart-splits.mux')
    assert.are.equal(require('smart-splits.mux.ghostty'), mux_api.get())
    assert.are.equal('stop', require('smart-splits.config').at_edge)
    assert.are.equal(5, require('smart-splits.config').default_amount)
    state.next_id = 'terminal-2'
    splits.move_cursor_right()
    assert.is_true(vim.tbl_contains(h.actions(state), 'goto_split:right'))
    assert.is_true(mux_api.resize_pane('right', 4))
    assert.are.equal('resize_split:right,40', h.last_action(state))
    assert.is_true(mux_api.split_pane('down', 12))
    assert.are.equal('new_split:down', h.last_action(state))
  end)

  -- v2 brackets every move with a pane lookup, so all three round trips must take
  -- the bridge; routing only the action left two osascript spawns per keypress.
  it('an edge move over the bridge never spawns osascript', function()
    local state = h.mock()
    state.bridge_available = true
    package.loaded['smart-splits'] = nil
    local splits = require('smart-splits')
    splits.setup({})
    assert.is_true(require('ghostty-smart-splits').setup({ bridge = true }))
    h.wait_for_calls(state, 1) -- Attachment is the one osascript call.
    h.settle()

    local spawns, requests = #state.calls, #state.bridge_requests
    state.next_id = 'terminal-2'
    splits.move_cursor_right()
    assert.are.same(spawns, #state.calls)
    local commands = vim.tbl_map(function(request)
      return request.command
    end, vim.list_slice(state.bridge_requests, requests + 1))
    assert.are.same({ 'focused-terminal-id', 'perform', 'focused-terminal-id' }, commands)
  end)
end)
