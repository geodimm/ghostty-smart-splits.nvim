-- Ghostty operations shared by the smart-splits integration adapters.
local M = {}
local bridge = require('ghostty-smart-splits.bridge')
local config = require('ghostty-smart-splits.config')
local script_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h') .. '/scripts/'
local terminal_id
local attaching = false
local attach_callbacks = {}

function M.detect()
  return vim.env.TERM_PROGRAM == 'ghostty'
    and vim.fn.has('macunix') == 1
    and vim.fn.executable('osascript') == 1
    and not vim.env.SSH_CONNECTION
    and not vim.env.TMUX
    and not vim.env.ZELLIJ
end

local function report_error(result)
  local message = vim.trim(result.stderr or '')
  vim.schedule(function()
    vim.notify_once(
      'ghostty-smart-splits: ' .. (message ~= '' and message or 'AppleScript failed'),
      vim.log.levels.WARN
    )
  end)
end

local function run(script, ...)
  if not M.detect() then
    return nil
  end
  local argv = { 'osascript', script_dir .. script .. '.applescript', ... }
  local ok, result = pcall(function()
    return vim.system(argv, { text = true, timeout = 1000 }):wait()
  end)
  -- :wait() is typed as always returning a result, but it has been seen to
  -- return nil, which would turn a timeout into an indexing error.
  if not ok or type(result) ~= 'table' then
    result = { code = -1, signal = 0, stderr = ok and '' or tostring(result) }
  end
  if result.code ~= 0 then
    report_error(result)
    return nil
  end
  return vim.trim(result.stdout or '')
end

local function run_async(script, callback, ...)
  if not M.detect() then
    callback(nil)
    return false
  end
  local argv = { 'osascript', script_dir .. script .. '.applescript', ... }
  local ok, err = pcall(function()
    vim.system(argv, { text = true, timeout = 1000 }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          report_error(result)
          callback(nil)
        else
          callback(vim.trim(result.stdout or ''))
        end
      end)
    end)
  end)
  if not ok then
    report_error({ stderr = tostring(err) })
    callback(nil)
    return false
  end
  return true
end

-- Prefer the persistent bridge; fall back to osascript when it cannot answer.
-- A bridge that reports an AppleScript failure fails closed rather than retrying.
local function dispatch(request, script, ...)
  if config.bridge then
    local result, handled = bridge.request(request)
    if handled then
      return type(result) == 'string' and result or nil
    end
  end
  return run(script, ...)
end

function M.focused_terminal_id()
  if not M.detect() then
    return nil
  end
  local id = dispatch({ command = 'focused-terminal-id' }, 'focused-terminal-id')
  return id ~= '' and id or nil
end

-- Capture once. Actions must not follow focus into an unrelated terminal.
function M.attach(callback)
  if terminal_id then
    if callback then
      callback(true)
    end
    return true
  end
  if callback then
    table.insert(attach_callbacks, callback)
  end
  if attaching then
    return true
  end
  attaching = true
  local started = run_async('focused-terminal-id', function(id)
    attaching = false
    if id and id ~= '' then
      terminal_id = id
      if config.bridge then
        bridge.start()
      end
    end
    local callbacks = attach_callbacks
    attach_callbacks = {}
    for _, done in ipairs(callbacks) do
      done(terminal_id ~= nil)
    end
  end)
  if not started then
    attaching = false
  end
  return started
end

function M.perform(action)
  if not terminal_id or not M.detect() then
    return false
  end
  return dispatch(
    { command = 'perform', terminalID = terminal_id, action = action },
    'perform-action',
    terminal_id,
    action
  ) == 'true'
end

function M.move(direction)
  return M.perform('goto_split:' .. direction)
end

function M.resize(direction, amount)
  return M.perform(('resize_split:%s,%d'):format(direction, math.max(10, (amount or 3) * 10)))
end

function M.split(direction)
  return M.perform('new_split:' .. direction)
end

return M
