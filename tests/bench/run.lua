-- Run in Ghostty: make bench. Creates and cleans up a temporary right pane.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local bench = dofile(root .. '/tests/bench/init.lua')
local bridge_path = root .. '/bin/ghostty-smart-splits-bridge'
local worker
local original_id, created_id
local timeout = 5000

local function options()
  local opts = { pairs = 10, warmup = 2 }
  for i = 1, #arg, 2 do
    local flag, value = arg[i], arg[i + 1]
    if flag == '--help' then
      print('make bench BENCH_ARGS="--pairs 10 --warmup 2 --json /tmp/ghostty-bench.json"')
      print('Counts are right/left pairs per transport. Requires macOS, Ghostty, and a built bridge.')
      print('Automatically creates a temporary right pane and closes it afterward.')
      return nil
    end
    assert(value, 'missing value for ' .. flag)
    if flag == '--json' then
      opts.json = value
    else
      assert(flag == '--pairs' or flag == '--warmup', 'unknown option: ' .. flag)
      local number = tonumber(value)
      assert(number and number > 0 and number < math.huge and number % 1 == 0, flag .. ' must be a positive integer')
      opts[flag:sub(3)] = number
    end
  end
  return opts
end

local function osascript(script, ...)
  local result = vim
    .system({ 'osascript', '-l', 'JavaScript', root .. '/' .. script .. '.js', ... }, {
      text = true,
      timeout = timeout,
    })
    :wait()
  assert(result.code == 0, 'osascript failed: ' .. (result.stderr or tostring(result.code)))
  return vim.trim(result.stdout or '')
end

local function pane(operation, ...)
  return osascript('tests/ghostty', root .. '/scripts/ghostty.js', 'owner', operation, ...)
end

local function focused()
  local id = osascript('scripts/ghostty', 'focused-terminal-id')
  assert(id ~= '', 'Ghostty returned an empty terminal ID')
  return id
end

local function source_action(id, action)
  assert(
    osascript('scripts/ghostty', 'perform-action', id, action) == 'true',
    action .. ' was not performed; check the pane layout'
  )
end

local function start_worker()
  local buffer, stderr, exited, read_error = '', '', false, nil
  worker = vim.system({ bridge_path }, {
    stdin = true,
    stdout = function(err, data)
      read_error = read_error or err
      buffer = buffer .. (data or '')
    end,
    stderr = function(_, data)
      stderr = stderr .. (data or '')
    end,
  }, function()
    exited = true
  end)
  return function(id, action)
    assert(not exited, 'bridge exited: ' .. stderr)
    worker:write(vim.json.encode({ command = 'perform', terminalID = id, action = action }) .. '\n')
    local completed = vim.wait(timeout, function()
      return buffer:find('\n', 1, true) ~= nil or exited or read_error ~= nil
    end, 1)
    assert(completed, 'bridge timed out; action outcome is unknown')
    assert(not read_error, read_error)
    local newline = buffer:find('\n', 1, true)
    assert(newline, 'bridge exited before replying: ' .. stderr)
    local line = buffer:sub(1, newline - 1)
    buffer = buffer:sub(newline + 1)
    local response = vim.json.decode(line)
    assert(
      type(response) == 'table' and response.ok == true and response.result == 'true',
      'bridge action failed: ' .. line
    )
  end
end

local function main()
  local opts = options()
  if not opts then
    return
  end
  assert(vim.fn.has('macunix') == 1, 'benchmark requires macOS')
  assert(vim.fn.executable(bridge_path) == 1, 'bridge is missing; run make bridge first')
  print('Creating a temporary Ghostty pane on the right. Avoid interacting with Ghostty until finished.')
  original_id = focused()
  created_id = pane('split', original_id)
  assert(created_id ~= '' and created_id ~= original_id, 'Ghostty did not return a new terminal ID')
  local left, right = original_id, created_id
  pane('focus', left)
  source_action(left, 'goto_split:right')
  assert(focused() == right, 'right navigation did not focus the temporary pane')
  source_action(right, 'goto_split:left')
  assert(focused() == left, 'left navigation did not restore focus; simplify the layout')

  local function actions(perform)
    return function(i)
      if i % 2 == 1 then
        perform(left, 'goto_split:right')
      else
        perform(right, 'goto_split:left')
      end
    end
  end
  local cases = {
    { name = 'osascript', run = actions(source_action) },
    { name = 'bridge', run = actions(start_worker()) },
  }
  print(
    ('Warming up %d pairs; measuring %d actions per transport. Keep the layout unchanged.'):format(
      opts.warmup,
      opts.pairs * 2
    )
  )
  local results = bench.compare(cases, { iterations = opts.pairs * 2, warmup = opts.warmup * 2 })
  local speedup = results.osascript.avg / results.bridge.avg
  local reduction = 100 * (1 - results.bridge.avg / results.osascript.avg)
  for _, case in ipairs(cases) do
    bench.print_result(case.name, results[case.name])
  end
  print(('Bridge: %.2fx faster; %.1f%% less latency (average).'):format(speedup, reduction))
  print('Every action returned true. Warmup, bridge startup, and pane setup/cleanup excluded.')
  print('Measures transport round trips, not end-to-end keypress or rendering latency.')
  if opts.json then
    local report = {
      timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
      platform = vim.uv.os_uname(),
      nvim = vim.version(),
      bridge_path = bridge_path,
      pairs = opts.pairs,
      warmup_pairs = opts.warmup,
      transports = results,
      speedup = speedup,
      latency_reduction_percent = reduction,
    }
    assert(vim.fn.writefile({ vim.json.encode(report) }, opts.json) == 0, 'could not save results')
    print('Raw samples saved to ' .. opts.json)
  end
end

local ok, err = xpcall(main, debug.traceback)
if worker then
  -- Closing stdin normally exits the bridge; bound cleanup if a request got stuck.
  pcall(function()
    worker:write(nil)
  end)
  pcall(function()
    worker:wait(1000)
  end)
end
local cleanup_errors = {}
local function cleanup(operation, id, ...)
  local cleaned, message = pcall(pane, operation, id, ...)
  if not cleaned then
    cleanup_errors[#cleanup_errors + 1] = operation .. ' ' .. id .. ': ' .. tostring(message)
  end
end
-- Never infer ownership from focus: only close the ID returned by split.
if created_id and created_id ~= '' and created_id ~= original_id then
  cleanup('close', created_id, original_id)
end
if original_id then
  cleanup('focus', original_id)
end
if #cleanup_errors > 0 then
  io.stderr:write('Pane cleanup failed (check Ghostty):\n' .. table.concat(cleanup_errors, '\n') .. '\n')
end
if not ok then
  io.stderr:write('Benchmark aborted: ' .. tostring(err) .. '\n')
end
if not ok or #cleanup_errors > 0 then
  vim.cmd('cquit 1')
end
