local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

-- Attach callbacks land on the event loop, so give them a turn to run.
local function settle()
  vim.wait(20, function()
    return false
  end)
end

local function wait_for_calls(state, count)
  assert(vim.wait(100, function()
    return #state.calls >= count
  end, 1))
end

T['lifecycle events push once and pop once across repeated resumes'] = function()
  local state = mock()
  local session = require('ghostty-smart-splits.session')
  session.activate()
  session.activate()
  eq(#state.calls, 1)
  for _ = 1, 2 do
    vim.api.nvim_exec_autocmds('VimEnter', {})
    wait_for_calls(state, 2)
    eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    eq(state.calls[#state.calls][4], 'deactivate_key_table')
    local count = #state.calls
    session.release_keys()
    eq(#state.calls, count)
    vim.api.nvim_exec_autocmds('VimResume', {})
    wait_for_calls(state, count + 1)
    eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
  end
  vim.api.nvim_exec_autocmds('VimLeavePre', {})
  eq(state.calls[#state.calls][4], 'deactivate_key_table')
end

T['custom tables and failed release retries'] = function()
  local state = mock()
  local session = require('ghostty-smart-splits.session')
  local opts = { key_table = 'editor' }
  session.configure(opts)
  session.activate()
  wait_for_calls(state, 2)
  eq(state.calls[#state.calls][4], 'activate_key_table:editor')
  eq(opts.multiplexer_integration, nil)
  state.response = { code = 0, stdout = 'false' }
  eq(session.release_keys(), false)
  state.response = { code = 0, stdout = 'true' }
  eq(session.release_keys(), true)
end

T['active tables cannot be changed until released'] = function()
  local state = mock()
  local session = require('ghostty-smart-splits.session')
  local config = require('ghostty-smart-splits.config')
  session.configure({ key_table = 'editor' })
  session.activate()
  wait_for_calls(state, 2)
  local ok, message = pcall(session.configure, { key_table = 'other' })
  eq(ok, false)
  assert(type(message) == 'string')
  eq(
    message:match('Release the active key table before changing key_table$'),
    'Release the active key table before changing key_table'
  )
  eq(config.key_table, 'editor')
  eq(session.release_keys(), true)
  session.configure({ key_table = 'other' })
  session.activate()
  wait_for_calls(state, 4)
  eq(state.calls[#state.calls][4], 'activate_key_table:other')
end

-- The documented runtime toggle: changing bridge must not disturb a claimed
-- key table, nor silently retarget it at the default.
T['toggling the bridge leaves a claimed custom key table alone'] = function()
  local state = mock()
  local session = require('ghostty-smart-splits.session')
  local config = require('ghostty-smart-splits.config')
  session.configure({ key_table = 'editor' })
  session.activate()
  wait_for_calls(state, 2)
  eq(state.calls[#state.calls][4], 'activate_key_table:editor')

  session.configure({ bridge = true })
  eq(config.key_table, 'editor')
  eq(config.bridge, true)
  session.configure({ bridge = false })
  eq(config.key_table, 'editor')

  -- Releasing and re-claiming still uses the table the caller chose.
  eq(session.release_keys(), true)
  session.configure({ slow_threshold = 200 })
  eq(config.key_table, 'editor')
  eq(session.claim_keys(), true)
  eq(state.calls[#state.calls][4], 'activate_key_table:editor')
end

-- The macOS Automation prompt times out the first lookup, so a session that
-- gives up there is dead until Neovim restarts.
T['a failed attachment recovers when Neovim regains focus'] = function()
  local state = mock()
  local session = require('ghostty-smart-splits.session')
  local ghostty = require('ghostty-smart-splits.ghostty')
  state.id = ''
  eq(session.activate(), true)
  wait_for_calls(state, 1)
  settle()

  -- Inert, and still not following focus into whatever pane is frontmost.
  state.id = 'unrelated-terminal'
  eq(ghostty.perform('goto_split:left'), false)
  eq(#state.calls, 1)

  -- The prompt is answered and focus comes back to our pane.
  state.id = 'terminal-1'
  vim.api.nvim_exec_autocmds('FocusGained', {})
  wait_for_calls(state, 3)
  eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
  eq(ghostty.perform('goto_split:left'), true)
  eq(vim.list_slice(state.calls[#state.calls], 3), { 'terminal-1', 'goto_split:left' })
end

T['attachment stops retrying once the failures stop being transient'] = function()
  local state = mock()
  local session = require('ghostty-smart-splits.session')
  state.id = ''
  eq(session.activate(), true)
  wait_for_calls(state, 1)
  settle()
  for _ = 1, 10 do
    vim.api.nvim_exec_autocmds('FocusGained', {})
    settle()
  end
  eq(#state.calls, 5)
  eq(pcall(vim.api.nvim_get_autocmds, { group = 'GhosttySmartSplits' }), false)
  eq(
    state.warnings[#state.warnings],
    'ghostty-smart-splits: could not reach Ghostty; see :checkhealth ghostty-smart-splits'
  )
end

-- Regaining focus while attached must not cost an Apple Event.
T['focus events are free once attached and claimed'] = function()
  local state = mock()
  local session = require('ghostty-smart-splits.session')
  eq(session.activate(), true)
  wait_for_calls(state, 2)
  local count = #state.calls
  for _ = 1, 3 do
    vim.api.nvim_exec_autocmds('FocusGained', {})
    settle()
  end
  eq(#state.calls, count)
end

return T
