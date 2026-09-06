local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

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

return T
