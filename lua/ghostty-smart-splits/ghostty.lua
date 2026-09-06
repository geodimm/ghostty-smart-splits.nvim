-- Ghostty operations shared by the smart-splits integration adapters.
local M = {}
local script_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h') .. '/scripts/'
local terminal_id

function M.detect()
  return vim.env.TERM_PROGRAM == 'ghostty'
    and vim.fn.has('macunix') == 1
    and vim.fn.executable('osascript') == 1
    and not vim.env.SSH_CONNECTION
    and not vim.env.TMUX
    and not vim.env.ZELLIJ
end

local function run(script, ...)
  if not M.detect() then
    return nil
  end
  local argv = { 'osascript', script_dir .. script .. '.applescript', ... }
  local ok, result = pcall(function()
    return vim.system(argv, { text = true, timeout = 1000 }):wait()
  end)
  if not ok then
    result = { code = -1, signal = 0, stderr = tostring(result) }
  end
  if result.code ~= 0 then
    local message = vim.trim(result.stderr or '')
    vim.schedule(function()
      vim.notify_once(
        'ghostty-smart-splits: ' .. (message ~= '' and message or 'AppleScript failed'),
        vim.log.levels.WARN
      )
    end)
    return nil
  end
  return vim.trim(result.stdout or '')
end

function M.focused_terminal_id()
  local id = run('focused-terminal-id')
  return id and id ~= '' and id or nil
end

-- Capture once. Actions must not follow focus into an unrelated terminal.
function M.attach()
  terminal_id = terminal_id or M.focused_terminal_id()
  return terminal_id ~= nil
end

function M.perform(action)
  if not terminal_id then
    return false
  end
  return run('perform-action', terminal_id, action) == 'true'
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
