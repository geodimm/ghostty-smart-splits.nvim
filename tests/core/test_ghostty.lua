local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

local function wait_for_calls(state, count)
  assert(vim.wait(100, function()
    return #state.calls >= count
  end, 1))
  vim.wait(10, function()
    return false
  end, 1)
end

T['unsupported sessions never launch osascript'] = function()
  local state = mock()
  local ghostty = require('ghostty-smart-splits.ghostty')
  state.linux = true
  eq(ghostty.attach(), false)
  eq(#state.calls, 0)
  state.linux = false
  for _, name in ipairs({ 'SSH_CONNECTION', 'TMUX', 'ZELLIJ' }) do
    vim.env[name] = 'active'
    eq(ghostty.detect(), false)
    vim.env[name] = nil
  end
  state.missing = true
  eq(ghostty.detect(), false)
  state.missing = false
  vim.env.TERM_PROGRAM = 'other'
  eq(ghostty.detect(), false)
end

T['actions are separate arguments and retain the captured terminal'] = function()
  local state = mock()
  local ghostty = require('ghostty-smart-splits.ghostty')
  eq(ghostty.perform('goto_split:left'), false)
  eq(ghostty.attach(), true)
  wait_for_calls(state, 1)
  state.id = 'terminal-2'
  eq(ghostty.attach(), true)
  eq(ghostty.focused_terminal_id(), 'terminal-2')
  local action = 'text:spaces "quotes" $shell'
  eq(ghostty.perform(action), true)
  eq(vim.list_slice(state.calls[#state.calls], 3), { 'terminal-1', action })
  eq(ghostty.resize('left', 3), true)
  eq(state.calls[#state.calls][4], 'resize_split:left,30')
  eq(ghostty.split('down'), true)
  eq(state.calls[#state.calls][4], 'new_split:down')
end

T['empty IDs and script failures fail closed'] = function()
  local state = mock()
  local ghostty = require('ghostty-smart-splits.ghostty')
  state.id = ''
  eq(ghostty.attach(), true)
  wait_for_calls(state, 1)
  state.id = '  terminal-1\n'
  eq(ghostty.attach(), true)
  wait_for_calls(state, 2)
  state.response = { code = 0, stdout = 'false' }
  eq(ghostty.perform('goto_split:left'), false)
  state.response = { code = 1, stderr = 'Automation denied' }
  eq(ghostty.perform('goto_split:left'), false)
  vim.wait(100, function()
    return #state.warnings > 0
  end)
  eq(state.warnings[1], 'ghostty-smart-splits: Automation denied')
end

return T
