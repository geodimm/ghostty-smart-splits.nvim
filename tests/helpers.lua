local M = {}

-- Undo actions for the current case, newest first. `restore()` drains them, so
-- specs pair every `mock()`/`stub()` with an `after_each(h.restore)`.
local teardown = {}

local function on_restore(fn)
  table.insert(teardown, fn)
end

---Undo every `mock()` and `stub()` made during the case.
function M.restore()
  for index = #teardown, 1, -1 do
    teardown[index]()
  end
  teardown = {}
end

-- Reset the state used by failure-path tests between cases.
local OWN_MODULES = {
  'ghostty-smart-splits.bridge',
  'ghostty-smart-splits.config',
  'ghostty-smart-splits.ghostty',
  'ghostty-smart-splits.session',
}
local ENV_KEYS = { 'TERM_PROGRAM', 'SSH_CONNECTION', 'TMUX', 'ZELLIJ' }

local function reset_plugin()
  for _, name in ipairs(OWN_MODULES) do
    require(name).reset()
  end
  -- `setup()` is what copies the threshold onto the v3 backend, so resetting
  -- config alone would leave a stale value behind.
  local backend = package.loaded['smart-splits-backend-ghostty']
  if backend then
    backend.slow_threshold = require('ghostty-smart-splits.config').slow_threshold
  end
end

---Install the Ghostty test double and return its recording state. Every
---patched global and environment variable is undone by `restore()`.
function M.mock()
  reset_plugin()
  local state = {
    calls = {},
    warnings = {},
    response = { code = 0, stdout = 'true' },
    id = 'terminal-1',
    bridge_starts = {},
    bridge_requests = {},
    bridge_stops = {},
  }
  local real_has, real_executable = vim.fn.has, vim.fn.executable
  local env = {}
  for _, key in ipairs(ENV_KEYS) do
    env[key] = vim.env[key]
    vim.env[key] = nil
  end
  vim.env.TERM_PROGRAM = 'ghostty'

  M.stub(vim.fn, 'has', function(feature)
    if feature == 'macunix' then
      return state.linux and 0 or 1
    end
    return real_has(feature)
  end)
  M.stub(vim.fn, 'executable', function(name)
    if name:match('ghostty%-smart%-splits%-bridge$') then
      return state.bridge_available and 1 or 0
    end
    return name == 'osascript' and (state.missing and 0 or 1) or real_executable(name)
  end)
  M.stub(vim, 'notify_once', function(message)
    table.insert(state.warnings, message)
  end)
  local bridge_callbacks
  M.stub(vim.fn, 'jobstart', function(argv, opts)
    assert(argv[1]:match('ghostty%-smart%-splits%-bridge$'))
    table.insert(state.bridge_starts, argv)
    bridge_callbacks = opts
    state.bridge_callbacks = opts
    return state.bridge_start_failure and -1 or #state.bridge_starts
  end)
  M.stub(vim.fn, 'jobstop', function(job)
    table.insert(state.bridge_stops, job)
    return 1
  end)
  M.stub(vim.fn, 'chansend', function(job, data)
    local request = vim.json.decode(data)
    table.insert(state.bridge_requests, request)
    local response = state.bridge_response
      or (request.command == 'focused-terminal-id' and { ok = true, result = state.id })
      or { ok = true, result = 'true' }
    bridge_callbacks.on_stdout(job, { vim.json.encode(response), '' })
    return #data
  end)
  M.stub(vim, 'system', function(argv, opts, on_exit)
    table.insert(state.calls, argv)
    state.system_opts = opts
    if state.spawn_error then
      error('osascript failed to start')
    end
    assert(argv[1] == 'osascript')
    assert(vim.fn.filereadable(argv[4]) == 1)
    local response = argv[5] == 'focused-terminal-id' and { code = 0, stdout = state.id }
      or (state.responses or {})[argv[7]]
      or state.response
    if on_exit then
      on_exit(response)
    end
    return {
      wait = function()
        if state.nil_wait then
          return nil
        end
        return response
      end,
    }
  end)

  on_restore(function()
    M.settle(10)
    -- Reset while the doubles are still installed: a leftover bridge job id is
    -- a small integer, and handing one to the real `jobstop` could close an
    -- actual channel.
    reset_plugin()
    for _, key in ipairs(ENV_KEYS) do
      vim.env[key] = env[key]
    end
    vim.cmd('silent! only!')
  end)
  return state
end

---Replace `tbl[key]` for the duration of the case and restore it afterwards.
---Use this rather than assigning directly: modules now keep their identity
---across cases, so an unrestored patch leaks into every later one.
---@param tbl table
---@param key string
---@param value any
function M.stub(tbl, key, value)
  local original = tbl[key]
  on_restore(function()
    tbl[key] = original
  end)
  tbl[key] = value
end

---Give queued callbacks a turn on the event loop.
---@param ms? integer
function M.settle(ms)
  vim.wait(ms or 20, function()
    return false
  end, 1)
end

---Block until `predicate` holds, failing the case with `message` if it never does.
---@param predicate fun(): boolean
---@param message string
function M.wait_until(predicate, message)
  assert(vim.wait(100, predicate, 1), message)
end

---@param state table
---@param count integer
function M.wait_for_calls(state, count)
  assert(
    vim.wait(100, function()
      return #state.calls >= count
    end, 1),
    ('expected %d osascript calls, saw %d'):format(count, #state.calls)
  )
end

---The Ghostty action from the most recent osascript call.
---@param state table
---@return string?
function M.last_action(state)
  local call = state.calls[#state.calls]
  return call and call[7]
end

---The target of the most recent osascript call, as `{ terminal_id, action }`.
---@param state table
---@return table
function M.last_target(state)
  return vim.list_slice(state.calls[#state.calls], 6)
end

return M
