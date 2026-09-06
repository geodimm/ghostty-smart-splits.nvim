local h = require('tests.helpers')
local mock = h.mock

describe('ghostty', function()
  after_each(h.restore)

  it('unsupported sessions never launch osascript', function()
    local state = mock()
    local ghostty = require('ghostty-smart-splits.ghostty')
    state.linux = true
    assert.is_false(ghostty.attach())
    assert.are.equal(0, #state.calls)
    state.linux = false
    for _, name in ipairs({ 'SSH_CONNECTION', 'TMUX', 'ZELLIJ' }) do
      vim.env[name] = 'active'
      assert.is_false(ghostty.detect())
      vim.env[name] = nil
    end
    state.missing = true
    assert.is_false(ghostty.detect())
    state.missing = false
    vim.env.TERM_PROGRAM = 'other'
    assert.is_false(ghostty.detect())
  end)

  it('empty IDs and script failures fail closed', function()
    local state = mock()
    local ghostty = require('ghostty-smart-splits.ghostty')
    state.id = ''
    assert.is_true(ghostty.attach())
    h.wait_for_calls(state, 1)
    h.settle(10)
    state.id = '  terminal-1\n'
    assert.is_true(ghostty.attach())
    h.wait_for_calls(state, 2)
    h.settle(10)
    state.response = { code = 0, stdout = 'false' }
    assert.is_false(ghostty.perform('goto_split:left'))
    state.response = { code = 1, stderr = 'Automation denied' }
    assert.is_false(ghostty.perform('goto_split:left'))
    vim.wait(100, function()
      return #state.warnings > 0
    end)
    assert.are.equal('ghostty-smart-splits: Automation denied', state.warnings[1])
  end)

  it('a missing system result fails closed rather than erroring', function()
    local state = mock()
    local ghostty = require('ghostty-smart-splits.ghostty')
    assert.is_true(ghostty.attach())
    h.wait_for_calls(state, 1)
    h.settle(10)
    state.nil_wait = true
    assert.is_false(ghostty.perform('goto_split:left'))
    assert.is_nil(ghostty.focused_terminal_id())
    state.nil_wait = false
    assert.is_true(ghostty.perform('goto_split:left'))
    state.spawn_error = true
    assert.is_false(ghostty.perform('goto_split:left'))
  end)
end)
