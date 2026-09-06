-- Persistent AppleScript process and newline-delimited JSON transport.
local M = {}
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local binary_path = root .. '/bin/ghostty-smart-splits-bridge'
local process_id
local pending_response
local stdout_buffer = ''
local last_exit

function M.stop()
  local job = process_id
  process_id = nil
  pending_response = nil
  stdout_buffer = ''
  if job then
    pcall(vim.fn.jobstop, job)
  end
end

function M.start()
  if process_id then
    return true
  end
  if vim.fn.executable(binary_path) ~= 1 then
    return false
  end

  last_exit = nil
  local job = vim.fn.jobstart({ binary_path }, {
    in_io = 'pipe',
    out_io = 'pipe',
    err_io = 'pipe',
    on_stdout = function(_, data)
      for index, chunk in ipairs(data) do
        stdout_buffer = stdout_buffer .. chunk
        if index < #data then
          stdout_buffer = stdout_buffer .. '\n'
        end
      end
      local newline = stdout_buffer:find('\n', 1, true)
      if newline then
        pending_response = stdout_buffer:sub(1, newline - 1)
        stdout_buffer = stdout_buffer:sub(newline + 1)
      end
    end,
    on_exit = function(job_id, exit_code)
      if process_id == job_id then
        process_id = nil
        last_exit = exit_code
      end
    end,
  })
  if job <= 0 then
    return false
  end
  process_id = job
  return true
end

-- Returns the response and whether the bridge handled the request.
function M.request(request)
  if not M.start() then
    return nil, false
  end

  pending_response = nil
  local ok = pcall(vim.fn.chansend, process_id, vim.json.encode(request) .. '\n')
  if not ok then
    M.stop()
    return nil, false
  end

  -- A healthy bridge responds well below the osascript action latency.
  -- Keep a broken/stale bridge from adding a full one-second stall before fallback.
  local completed = vim.wait(250, function()
    return pending_response ~= nil or process_id == nil
  end, 10)
  if not completed or not pending_response then
    M.stop()
    return nil, false
  end

  local line = pending_response
  pending_response = nil
  local decoded_ok, response = pcall(vim.json.decode, line)
  if not decoded_ok or type(response) ~= 'table' then
    M.stop()
    return nil, false
  end
  if response.ok ~= true then
    vim.schedule(function()
      vim.notify_once('ghostty-smart-splits: ' .. (response.error or 'bridge failed'), vim.log.levels.WARN)
    end)
    return false, true
  end
  if type(response.result) ~= 'string' then
    M.stop()
    return nil, false
  end
  return response.result, true
end

function M.status()
  return {
    executable = vim.fn.executable(binary_path) == 1,
    last_exit = last_exit,
    path = binary_path,
    running = process_id ~= nil,
  }
end

return M
