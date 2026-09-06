---@diagnostic disable: duplicate-set-field
local h = require('tests.helpers')
local mock = h.mock

describe('bridge', function()
  after_each(h.restore)

  it('v2 disables a built bridge and routes actions through osascript', function()
    local state = mock()
    state.bridge_available = true
    local bridge = require('ghostty-smart-splits.bridge')
    h.stub(bridge, 'start', function()
      error('disabled bridge must not be started')
    end)
    h.stub(bridge, 'request', function()
      error('disabled bridge must not receive requests')
    end)
    assert.is_true(require('ghostty-smart-splits').setup())
    assert.is_true(require('ghostty-smart-splits').setup({ bridge = false }))
    h.wait_for_calls(state, 2)
    h.settle(10)
    local ghostty = require('ghostty-smart-splits.ghostty')
    assert.is_true(ghostty.move('right'))
    assert.are.equal(0, #state.bridge_starts)
    assert.are.equal(0, #state.bridge_requests)
    assert.are.equal('goto_split:right', h.last_action(state))
    assert.is_false(bridge.status().running)
  end)

  it('v3 configures before activation and reuses one bridge for actions', function()
    local state = mock()
    state.bridge_available = true
    local backend = require('smart-splits-backend-ghostty')
    backend.setup({ bridge = true })
    assert.are.equal(0, #state.bridge_starts)
    assert.are.equal(0, #state.calls)
    assert.is_true(backend.activate())
    h.wait_for_requests(state, 1)
    assert.is_true(backend.move('right'))
    assert.is_true(backend.resize('left', { amount = 4 }))
    assert.are.equal(1, #state.bridge_starts)
    local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
    assert.are.same(root .. '/bin/ghostty-smart-splits-bridge', state.bridge_starts[1][1])
    assert.are.equal(1, #state.calls) -- Only the initial terminal lookup uses osascript.
    assert.are.equal('activate_key_table:nvim', state.bridge_requests[1].action)
    assert.are.same(
      { command = 'perform', terminalID = 'terminal-1', action = 'goto_split:right' },
      state.bridge_requests[2]
    )
    assert.are.equal('resize_split:left,40', state.bridge_requests[3].action)
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
    assert.are.equal('deactivate_key_table', state.bridge_requests[4].action)
    assert.are.equal(1, #state.bridge_stops)
  end)

  it('disabling stops the bridge immediately and enabling waits for an action', function()
    local state = mock()
    state.bridge_available = true
    local backend = require('smart-splits-backend-ghostty')
    backend.setup({ bridge = true })
    backend.activate()
    h.wait_until(function()
      return #state.bridge_starts == 1
    end, 'the bridge never started')
    backend.setup({ bridge = false })
    assert.are.equal(1, #state.bridge_stops)
    assert.is_false(require('ghostty-smart-splits.bridge').status().running)
    assert.is_true(backend.move('left'))
    assert.are.equal('goto_split:left', h.last_action(state))
    backend.setup({ bridge = true })
    assert.are.equal(1, #state.bridge_starts)
    assert.is_true(backend.move('right'))
    assert.are.equal(2, #state.bridge_starts)
    assert.are.equal('goto_split:right', h.last_request(state).action)
  end)

  it('enabled bridge falls back when missing or unable to start', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.setup({ bridge = true })
    state.bridge_available = true
    assert.is_true(backend.activate())
    h.wait_until(function()
      return #state.bridge_starts == 1
    end, 'the bridge never started')
    require('ghostty-smart-splits.bridge').stop()
    state.bridge_start_failure = true
    assert.is_true(backend.move('right'))
    assert.are.equal(2, #state.bridge_starts)
    assert.are.equal('goto_split:right', h.last_action(state))
  end)

  it('the focused terminal lookup prefers the bridge and falls back to osascript', function()
    local state = mock()
    state.bridge_available = true
    local bridge = require('ghostty-smart-splits.bridge')
    local config = require('ghostty-smart-splits.config')
    local ghostty = require('ghostty-smart-splits.ghostty')

    config.setup({ bridge = true })
    state.id = 'terminal-7'
    assert.are.equal('terminal-7', ghostty.focused_terminal_id())
    assert.are.equal(0, #state.calls)
    assert.are.same({ { command = 'focused-terminal-id' } }, state.bridge_requests)

    -- A bridge that cannot start still answers through osascript.
    bridge.stop()
    state.bridge_available = false
    assert.are.equal('terminal-7', ghostty.focused_terminal_id())
    assert.are.equal(1, #state.bridge_requests)
    assert.are.equal('focused-terminal-id.applescript', h.last_script(state))

    -- A disabled bridge is never consulted.
    state.bridge_available = true
    config.setup({ bridge = false })
    assert.are.equal('terminal-7', ghostty.focused_terminal_id())
    assert.are.equal(1, #state.bridge_requests)
    assert.are.equal(2, #state.calls)
  end)

  -- request() blocks in vim.wait, which pumps the event loop, so a scheduled
  -- callback can land here while a request is outstanding.
  it('a nested bridge request falls back instead of stealing the reply', function()
    local state = mock()
    state.bridge_available = true
    local bridge = require('ghostty-smart-splits.bridge')
    local outer_send = vim.fn.chansend
    local nested_result, nested_handled
    local depth = 0
    h.stub(vim.fn, 'chansend', function(job, data)
      depth = depth + 1
      if depth == 1 then
        nested_result, nested_handled = bridge.request({ command = 'perform', terminalID = 't', action = 'nested' })
      end
      return outer_send(job, data)
    end)

    local result, handled = bridge.request({ command = 'perform', terminalID = 't', action = 'goto_split:left' })
    assert.is_false(nested_handled) -- Nested caller is told to use osascript.
    assert.is_nil(nested_result)
    assert.is_true(handled) -- Outer caller still gets its own reply.
    assert.are.equal('true', result)
    assert.are.equal(1, #state.bridge_requests) -- Only the outer request reached the pipe.
  end)

  it('a burst of bridge output does not desynchronise the next request', function()
    local state = mock()
    state.bridge_available = true
    local bridge = require('ghostty-smart-splits.bridge')
    assert.are.equal('terminal-1', bridge.request({ command = 'focused-terminal-id' }))

    -- Two whole replies plus a partial one, all in a single stdout event.
    local stale = vim.json.encode({ ok = true, result = 'stale' })
    state.bridge_callbacks.on_stdout(1, { stale, stale, '{"ok":true,"resu' })

    local result, handled = bridge.request({ command = 'perform', terminalID = 't', action = 'goto_split:left' })
    assert.is_true(handled)
    assert.are.equal('true', result)
  end)
end)
