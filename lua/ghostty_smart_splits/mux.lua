local M = { type = 'ghostty' }
local script_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h') .. '/scripts/'
local terminal_id

function M.is_in_session()
  return vim.env.TERM_PROGRAM == 'ghostty'
    and vim.fn.has('macunix') == 1
    and vim.fn.executable('osascript') == 1
    and not vim.env.SSH_CONNECTION
    and not vim.env.TMUX
    and not vim.env.ZELLIJ
end

local function run(script, ...)
  if not M.is_in_session() then
    return nil
  end
  local result = vim.system({ 'osascript', script_dir .. script .. '.applescript', ... }, { text = true }):wait()
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

function M.current_pane_id()
  local id = run('focused-terminal-id')
  return id and id ~= '' and id or nil
end

-- Capture once. Actions must not follow focus into an unrelated terminal.
function M.attach()
  terminal_id = terminal_id or M.current_pane_id()
  return terminal_id ~= nil
end

function M.perform(action)
  if not terminal_id then
    return false
  end
  return run('perform-action', terminal_id, action) == 'true'
end

function M.next_pane(direction)
  if require('ghostty_smart_splits.navigation').neighbor_win(direction) then
    return false
  end
  return M.perform('goto_split:' .. direction)
end

function M.resize_pane(direction, amount)
  return M.perform(('resize_split:%s,%d'):format(direction, math.max(10, (amount or 3) * 10)))
end

function M.split_pane(direction)
  return M.perform('new_split:' .. direction)
end

function M.current_pane_at_edge()
  return false
end

function M.current_pane_is_zoomed()
  return false
end

function M.update_mux_layout_details() end

return M
