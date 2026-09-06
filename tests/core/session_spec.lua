local h = require('tests.helpers')
local mock = h.mock

describe('session', function()
  after_each(h.restore)

  it('custom tables and failed release retries', function()
    local state = mock()
    local session = require('ghostty-smart-splits.session')
    local opts = { key_table = 'editor' }
    session.configure(opts)
    session.activate()
    h.wait_for_calls(state, 2)
    assert.are.equal('activate_key_table:editor', h.last_action(state))
    assert.is_nil(opts.multiplexer_integration)
    state.response = { code = 0, stdout = 'false' }
    assert.is_false(session.release_keys())
    state.response = { code = 0, stdout = 'true' }
    assert.is_true(session.release_keys())
  end)

  it('active tables cannot be changed until released', function()
    local state = mock()
    local session = require('ghostty-smart-splits.session')
    local config = require('ghostty-smart-splits.config')
    session.configure({ key_table = 'editor' })
    session.activate()
    h.wait_for_calls(state, 2)
    local ok, message = pcall(session.configure, { key_table = 'other' })
    assert.is_false(ok)
    assert(type(message) == 'string')
    assert.are.equal(
      'Release the active key table before changing key_table',
      message:match('Release the active key table before changing key_table$')
    )
    assert.are.equal('editor', config.key_table)
    assert.is_true(session.release_keys())
    session.configure({ key_table = 'other' })
    session.activate()
    h.wait_for_calls(state, 4)
    assert.are.equal('activate_key_table:other', h.last_action(state))
  end)

  it('a failed attachment recovers when Neovim regains focus', function()
    local state = mock()
    local session = require('ghostty-smart-splits.session')
    local ghostty = require('ghostty-smart-splits.ghostty')
    state.id = ''
    assert.is_true(session.activate())
    h.wait_for_calls(state, 1)
    h.settle()

    -- Inert, and still not following focus into whatever pane is frontmost.
    state.id = 'unrelated-terminal'
    assert.is_false(ghostty.perform('goto_split:left'))
    assert.are.equal(1, #state.calls)

    -- The prompt is answered and focus comes back to our pane.
    state.id = 'terminal-1'
    vim.api.nvim_exec_autocmds('FocusGained', {})
    h.wait_for_calls(state, 3)
    assert.are.equal('activate_key_table:nvim', h.last_action(state))
    assert.is_true(ghostty.perform('goto_split:left'))
    assert.are.same({ 'terminal-1', 'goto_split:left' }, h.last_target(state))
  end)

  it('attachment stops retrying once the failures stop being transient', function()
    local state = mock()
    local session = require('ghostty-smart-splits.session')
    state.id = ''
    assert.is_true(session.activate())
    h.wait_for_calls(state, 1)
    h.settle()
    for _ = 1, 10 do
      vim.api.nvim_exec_autocmds('FocusGained', {})
      h.settle()
    end
    assert.are.equal(5, #state.calls)
    assert.is_false(pcall(vim.api.nvim_get_autocmds, { group = 'GhosttySmartSplits' }))
    assert.are.equal(
      'ghostty-smart-splits: could not reach Ghostty; see :checkhealth ghostty-smart-splits',
      state.warnings[#state.warnings]
    )
  end)

  it('suspending before attachment completes does not claim keys', function()
    local state = mock()
    local session = require('ghostty-smart-splits.session')
    assert.is_true(session.activate())
    assert.are.equal(1, #state.calls) -- Lookup issued; its callback has not run yet.

    vim.api.nvim_exec_autocmds('VimSuspend', {})
    h.settle()
    assert.are.equal(1, #state.calls) -- Nothing claimed while Neovim sits in the background.

    vim.api.nvim_exec_autocmds('VimResume', {})
    h.wait_for_calls(state, 2)
    assert.are.equal('activate_key_table:nvim', h.last_action(state))
  end)
end)
