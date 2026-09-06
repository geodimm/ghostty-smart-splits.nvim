-- Launch the benchmark in its own Ghostty, so both real transports inherit
-- the correct process ancestry without using any personal terminal panes.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local scratch = vim.fn.tempname()
local process

local function options()
  local opts = { pairs = 10, warmup = 2 }
  for i = 1, #arg, 2 do
    local flag, value = arg[i], arg[i + 1]
    if flag == '--help' then
      print('make bench BENCH_ARGS="--pairs 10 --warmup 2 --json /tmp/ghostty-bench.json"')
      print('Counts are right/left pairs per transport. Requires macOS, Ghostty, and Xcode Command Line Tools.')
      print('Launches an isolated Ghostty window and closes it afterward.')
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

local function report(message)
  io.stdout:write(message, '\n')
  io.stdout:flush()
end

local function ghostty(operation, ...)
  local result = vim
    .system({
      'osascript',
      '-l',
      'JavaScript',
      root .. '/tests/ghostty.js',
      root .. '/scripts/ghostty.js',
      tostring(process.pid),
      operation,
      ...,
    }, { text = true, timeout = 5000 })
    :wait()
  assert(result.code == 0, result.stderr or 'Ghostty automation failed')
  return vim.trim(result.stdout or '')
end

local function wait_for(message, predicate, timeout)
  local last_error
  local ok = vim.wait(timeout or 10000, function()
    local success, result = pcall(predicate)
    if not success then
      last_error = result
    end
    return success and result
  end, 100)
  assert(ok, message .. (last_error and '\n' .. tostring(last_error) or ''))
end

local function main()
  local opts = options()
  if not opts then
    return
  end
  local app = '/Applications/Ghostty.app'
  assert(vim.fn.has('macunix') == 1, 'benchmark requires macOS and a graphical session')
  assert(vim.fn.isdirectory(app) == 1, 'Ghostty app not found: ' .. app)
  assert(vim.fn.executable(root .. '/bin/ghostty-smart-splits-bridge') == 1, 'Run make bridge first')
  if opts.json then
    opts.json = vim.fn.fnamemodify(opts.json, ':p')
  end
  vim.fn.mkdir(scratch, 'p')
  vim.fn.writefile({ vim.json.encode(opts) }, scratch .. '/options.json')
  report('Starting isolated Ghostty benchmark. Leave its test window alone until finished.')
  process = vim.system({
    app .. '/Contents/MacOS/ghostty',
    '--config-default-files=false',
    '--config-file=' .. root .. '/tests/e2e/ghostty.conf',
  }, { text = true })
  wait_for('Ghostty did not start', function()
    return ghostty('running') == 'true'
  end)
  local argv = {
    'env',
    '-u',
    'NVIM',
    '-u',
    'TMUX',
    '-u',
    'ZELLIJ',
    '-u',
    'SSH_CONNECTION',
    'NVIM_LOG_FILE=' .. scratch .. '/nvim.log',
    'XDG_STATE_HOME=' .. scratch,
    vim.v.progpath,
    '--headless',
    '-u',
    'NONE',
    '-i',
    'NONE',
    '-l',
    root .. '/tests/bench/worker.lua',
    scratch .. '/options.json',
  }
  vim.fn.writefile({
    '#!/bin/sh',
    table.concat(vim.tbl_map(vim.fn.shellescape, argv), ' ')
      .. ' > '
      .. vim.fn.shellescape(scratch .. '/output')
      .. ' 2>&1',
    [[printf '%s\n' "$?" > ]] .. vim.fn.shellescape(scratch .. '/status'),
    'exec /bin/sh',
  }, scratch .. '/launch.sh')
  ghostty('new', '/bin/sh ' .. vim.fn.shellescape(scratch .. '/launch.sh'))
  wait_for('Benchmark did not finish', function()
    return vim.fn.filereadable(scratch .. '/status') == 1
  end, 10000 + (opts.pairs + opts.warmup) * 20000)
  assert(vim.fn.readfile(scratch .. '/status')[1] == '0', 'Benchmark worker failed (see output above)')
end

local ok, err = xpcall(main, debug.traceback)
if vim.fn.filereadable(scratch .. '/output') == 1 then
  report(table.concat(vim.fn.readfile(scratch .. '/output'), '\n'))
end
local cleaned, cleanup_error = true, nil
if process then
  cleaned, cleanup_error = pcall(function()
    if ghostty('running') == 'true' then
      ghostty('quit')
    end
    wait_for('Benchmark Ghostty did not quit', function()
      return ghostty('running') == 'false'
    end)
  end)
  if not cleaned then
    -- A stuck automation request must not leave our disposable app running.
    process:kill(15)
    process:wait(1000)
  end
end
vim.fn.delete(scratch, 'rf')
if not ok then
  io.stderr:write('Benchmark aborted: ' .. tostring(err) .. '\n')
end
if not cleaned then
  io.stderr:write('Cleanup failed: ' .. tostring(cleanup_error) .. '\n')
end
if not ok or not cleaned then
  vim.cmd('cquit 1')
end
