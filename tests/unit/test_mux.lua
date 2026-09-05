local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

T['unsupported sessions never launch osascript'] = function()
  local state = mock()
  local mux = require('ghostty_smart_splits.mux')
  state.linux = true
  eq(mux.attach(), false)
  eq(require('ghostty_smart_splits').setup(), false)
  eq(#state.calls, 0)
  state.linux = false
  for _, name in ipairs({ 'SSH_CONNECTION', 'TMUX', 'ZELLIJ' }) do
    vim.env[name] = 'active'
    eq(mux.is_in_session(), false)
    vim.env[name] = nil
  end
  state.missing = true
  eq(mux.is_in_session(), false)
  state.missing = false
  vim.env.TERM_PROGRAM = 'other'
  eq(mux.is_in_session(), false)
end

T['actions are separate arguments and retain the captured terminal'] = function()
  local state = mock()
  local mux = require('ghostty_smart_splits.mux')
  eq(mux.perform('goto_split:left'), false)
  eq(mux.attach(), true)
  state.id = 'terminal-2'
  eq(mux.attach(), true)
  eq(mux.current_pane_id(), 'terminal-2')
  local action = 'text:spaces "quotes" $shell'
  eq(mux.perform(action), true)
  eq(vim.list_slice(state.calls[#state.calls], 3), { 'terminal-1', action })
  eq(mux.resize_pane('left', 3), true)
  eq(state.calls[#state.calls][4], 'resize_split:left,30')
  eq(mux.split_pane('down'), true)
  eq(state.calls[#state.calls][4], 'new_split:down')
  eq(require('smart-splits.mux.ghostty'), mux)
end

T['empty IDs and script failures fail closed'] = function()
  local state = mock()
  local mux = require('ghostty_smart_splits.mux')
  state.id = ''
  eq(mux.attach(), false)
  state.id = '  terminal-1\n'
  eq(mux.attach(), true)
  state.response = { code = 0, stdout = 'false' }
  eq(mux.perform('goto_split:left'), false)
  state.response = { code = 1, stderr = 'Automation denied' }
  eq(mux.perform('goto_split:left'), false)
  vim.wait(100, function()
    return #state.warnings > 0
  end)
  eq(state.warnings[1], 'ghostty-smart-splits: Automation denied')
end

return T
