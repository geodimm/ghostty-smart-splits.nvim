-- Persistent AppleScript process and newline-delimited JSON transport.
local M = {}
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local binary_path = root .. '/bin/ghostty-smart-splits-bridge'
local process_id
local response_queue = {}
local stdout_buffer = ''
local last_exit
local in_flight = false

function M.stop()
  local job = process_id
  process_id = nil
  response_queue = {}
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
      -- Drain every complete line. Keeping only the first would strand the
      -- rest until the next stdout event.
      while true do
        local newline = stdout_buffer:find('\n', 1, true)
        if not newline then
          break
        end
        table.insert(response_queue, stdout_buffer:sub(1, newline - 1))
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
  -- The vim.wait below pumps the event loop, so a scheduled callback can reach
  -- this function while a request is still outstanding. Two callers sharing one
  -- pipe would consume each other's replies, so refuse the nested one and let it
  -- fall back to osascript.
  if in_flight then
    return nil, false
  end
  if not M.start() then
    return nil, false
  end

  -- Requests are serialised, so anything still buffered is a leftover from a
  -- request that already gave up and must not be read as this one's reply.
  response_queue = {}
  stdout_buffer = ''
  in_flight = true
  local ok = pcall(vim.fn.chansend, process_id, vim.json.encode(request) .. '\n')
  if not ok then
    in_flight = false
    M.stop()
    return nil, false
  end

  -- A healthy bridge responds well below the osascript action latency.
  -- Keep a broken/stale bridge from adding a full one-second stall before fallback.
  local completed = vim.wait(250, function()
    return #response_queue > 0 or process_id == nil
  end, 10)
  in_flight = false
  local line = table.remove(response_queue, 1)
  if not completed or not line then
    M.stop()
    return nil, false
  end
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

---Return the bridge to its initial state, including the fields `stop()` keeps
---so `status()` stays meaningful across a restart. Tests call this instead of
---dropping the module from `package.loaded`.
function M.reset()
  M.stop()
  last_exit = nil
  in_flight = false
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
