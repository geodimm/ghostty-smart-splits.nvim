local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

T['lifecycle events push once and pop once across repeated resumes'] = function()
  local state = mock()
  local session = require('ghostty-smart-splits.session')
  session.activate()
  session.activate()
  eq(#state.calls, 2)
  for _ = 1, 2 do
    vim.api.nvim_exec_autocmds('VimEnter', {})
    eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    eq(state.calls[#state.calls][4], 'deactivate_key_table')
    local count = #state.calls
    session.release_keys()
    eq(#state.calls, count)
    vim.api.nvim_exec_autocmds('VimResume', {})
    eq(#state.calls, count + 1)
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
  eq(state.calls[#state.calls][4], 'activate_key_table:editor')
  eq(opts.multiplexer_integration, nil)
  state.response = { code = 0, stdout = 'false' }
  eq(session.release_keys(), false)
  state.response = { code = 0, stdout = 'true' }
  eq(session.release_keys(), true)
end

return T
