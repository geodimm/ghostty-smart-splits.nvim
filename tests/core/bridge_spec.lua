---@diagnostic disable: duplicate-set-field
local h = require('tests.helpers')
local mock = h.mock

describe('bridge', function()
  after_each(h.restore)

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
