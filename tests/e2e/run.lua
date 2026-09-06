-- A headless coordinator drives real keys into a separate, visible Ghostty.
-- RPC only prepares layouts and observes state; it never replaces a transport.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local app = '/Applications/Ghostty.app'
local script = root .. '/tests/ghostty.js'
local scratch = vim.fn.tempname()
local socket, editor, neighbors, process
local passed = 0
local osascript_log

local function report(message)
  io.stdout:write(message, '\n')
  io.stdout:flush()
end

local function run(argv)
  local result = vim.system(argv, { text = true, timeout = 5000 }):wait()
  assert(result.code == 0, table.concat(argv, ' ') .. ': ' .. (result.stderr or tostring(result.code)))
  return vim.trim(result.stdout or '')
end

local function ghostty(operation, ...)
  return run({
    'osascript',
    '-l',
    'JavaScript',
    script,
    root .. '/scripts/ghostty.js',
    tostring(process.pid),
    operation,
    ...,
  })
end

local function remote(code)
  local expression = 'json_encode(luaeval(' .. vim.fn.string(code) .. '))'
  return vim.json.decode(run({ vim.v.progpath, '--server', socket, '--remote-expr', expression }))
end

local function command(text)
  remote('vim.cmd(' .. string.format('%q', text) .. ')')
end

local function wait_for(message, predicate)
  local last_error
  local ok = vim.wait(10000, function()
    local success, result = pcall(predicate)
    if not success then
      last_error = result
    end
    return success and result
  end, 100)
  assert(ok, message .. (last_error and '\n' .. tostring(last_error) or ''))
end

local function key(term, name, modifiers)
  ghostty('key', term, name, modifiers or '')
end

local function check(message, predicate)
  wait_for(message, predicate)
  passed = passed + 1
  report('  PASS ' .. message)
end

local function table_claimed()
  local before = remote('vim.g.e2e_probe or 0')
  wait_for('Neovim did not claim its Ghostty key table', function()
    key(editor, 'f12')
    return remote('vim.g.e2e_probe or 0') > before
  end)
end

local directions = {
  { name = 'left', key = 'h', opposite = 'l', start = 'top_right', edge = 'top_left', size = 'width' },
  { name = 'right', key = 'l', opposite = 'h', start = 'top_left', edge = 'top_right', size = 'width' },
  { name = 'up', key = 'k', opposite = 'j', start = 'bottom_left', edge = 'top_left', size = 'height' },
  { name = 'down', key = 'j', opposite = 'k', start = 'top_left', edge = 'bottom_left', size = 'height' },
}

local function screen_size(direction)
  return remote(direction.size == 'width' and 'vim.o.columns' or 'vim.o.lines')
end

local function window_size(direction)
  local expression = direction.size == 'width' and 'vim.api.nvim_win_get_width(0)' or 'vim.api.nvim_win_get_height(0)'
  return remote(expression)
end

local function editor_layout()
  command('only | vsplit | wincmd h | split | wincmd l | split')
  local windows = remote([[(function()
    local result = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local position = vim.api.nvim_win_get_position(win)
      table.insert(result, { id = win, row = position[1], column = position[2] })
    end
    return result
  end)()]])
  assert(#windows == 4, 'Could not create the 2x2 Neovim layout')
  table.sort(windows, function(a, b)
    return a.row == b.row and a.column < b.column or a.row < b.row
  end)
  return {
    top_left = windows[1].id,
    top_right = windows[2].id,
    bottom_left = windows[3].id,
    bottom_right = windows[4].id,
  }
end

local function select_window(win)
  command(('lua vim.api.nvim_set_current_win(%d)'):format(win))
end

local function test_navigation(direction, windows)
  local start = windows[direction.start]
  local edge = windows[direction.edge]
  select_window(start)
  key(editor, direction.key, 'control')
  check(('Ctrl-%s moves %s inside Neovim'):format(direction.key:upper(), direction.name), function()
    return remote('vim.api.nvim_get_current_win()') == edge and ghostty('focused') == editor
  end)
  key(editor, direction.key, 'control')
  check(
    ('Ctrl-%s at the editor edge focuses the %s Ghostty pane'):format(direction.key:upper(), direction.name),
    function()
      return ghostty('focused') == neighbors[direction.name]
    end
  )
  key(neighbors[direction.name], direction.opposite, 'control')
  check(
    ('Ctrl-%s in the shell returns to Neovim from the %s'):format(direction.opposite:upper(), direction.name),
    function()
      return ghostty('focused') == editor
    end
  )
  key(editor, direction.opposite, 'control')
  check(('Ctrl-%s moves back inside Neovim'):format(direction.opposite:upper()), function()
    return remote('vim.api.nvim_get_current_win()') == start and ghostty('focused') == editor
  end)
end

local function test_nvim_resize(direction, windows)
  select_window(windows[direction.start])
  local size = window_size(direction)
  key(editor, direction.key, 'option')
  check(('Alt-%s resizes the Neovim split %s'):format(direction.key:upper(), direction.name), function()
    return window_size(direction) > size
  end)
end

local function test_ghostty_resize(direction)
  local size = screen_size(direction)
  key(editor, direction.key, 'option')
  check(('Alt-%s resizes the Ghostty pane %s'):format(direction.key:upper(), direction.name), function()
    return screen_size(direction) ~= size
  end)
end

local function shell_command(version, bridge, checkout)
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
    'GSS_ROOT=' .. root,
    'GSS_SMART_SPLITS=' .. checkout,
    'GSS_VERSION=' .. version,
    'GSS_BRIDGE=' .. tostring(bridge),
    'XDG_STATE_HOME=' .. scratch,
    'NVIM_LOG_FILE=' .. scratch .. '/nvim.log',
    'GSS_OSASCRIPT_LOG=' .. osascript_log,
    'PATH=' .. scratch .. '/bin:' .. vim.env.PATH,
    vim.v.progpath,
    '--noplugin',
    '-u',
    root .. '/tests/e2e/init.lua',
    '-i',
    'NONE',
    '--listen',
    socket,
  }
  return table.concat(vim.tbl_map(vim.fn.shellescape, argv), ' ')
end

local function scenario(version, bridge, checkout)
  report(('RUN %s / %s'):format(version, bridge and 'bridge' or 'osascript'))
  socket = scratch .. '/' .. version .. '-' .. tostring(bridge) .. '.sock'
  osascript_log = socket .. '.osascript'
  editor = ghostty('new')
  ghostty('focus', editor)
  ghostty('text', editor, shell_command(version, bridge, checkout))
  key(editor, 'enter')
  wait_for('Neovim did not start', function()
    return remote('vim.g.e2e_ready') == true
  end)
  table_claimed()
  -- Neovim's terminal UI is a separate parent process; the RPC server keeps
  -- running while the UI is suspended. Observe the process that owns the TTY.
  local nvim_pid = remote('vim.fn.getpid()')
  local pid = run({ 'ps', '-o', 'ppid=', '-p', tostring(nvim_pid) })
  local full_width = remote('vim.o.columns')
  local full_height = remote('vim.o.lines')
  neighbors = {}
  for _, direction in ipairs(directions) do
    neighbors[direction.name] = ghostty('split', editor, direction.name)
  end
  neighbors.top_left = ghostty('split', neighbors.left, 'up')
  neighbors.bottom_left = ghostty('split', neighbors.left, 'down')
  neighbors.top_right = ghostty('split', neighbors.right, 'up')
  neighbors.bottom_right = ghostty('split', neighbors.right, 'down')
  ghostty('focus', editor)
  wait_for('Ghostty did not create the 3x3 pane layout', function()
    return remote('vim.o.columns') < full_width and remote('vim.o.lines') < full_height
  end)

  local windows = editor_layout()
  for _, direction in ipairs(directions) do
    test_navigation(direction, windows)
  end
  for _, direction in ipairs(directions) do
    test_nvim_resize(direction, windows)
  end
  command('only')
  for _, direction in ipairs(directions) do
    test_ghostty_resize(direction)
  end
  check('the selected transport has the expected real bridge process', function()
    local found = false
    for line in run({ 'ps', '-axo', 'pid=,ppid=,comm=' }):gmatch('[^\n]+') do
      local child, parent, executable = line:match('^%s*(%d+)%s+(%d+)%s+(.+)$')
      if tonumber(parent) == nvim_pid and executable == root .. '/bin/ghostty-smart-splits-bridge' then
        found = true
        report('  Bridge PID ' .. child .. ' (Neovim PID ' .. nvim_pid .. ')')
      end
    end
    return found == bridge
  end)

  ghostty('focus', editor)
  key(editor, 'z', 'control')
  wait_for('Ctrl-Z did not suspend Neovim', function()
    return run({ 'ps', '-o', 'state=', '-p', tostring(pid) }):find('T', 1, true) ~= nil
  end)
  key(editor, 'l', 'control')
  check('suspending Neovim releases the Ghostty bindings', function()
    return ghostty('focused') == neighbors.right
  end)
  key(neighbors.right, 'h', 'control')
  ghostty('text', editor, 'fg')
  key(editor, 'enter')
  wait_for('fg did not resume Neovim', function()
    return run({ 'ps', '-o', 'state=', '-p', tostring(pid) }):find('T', 1, true) == nil
  end)
  table_claimed()
  command('vsplit | wincmd h')
  local left = remote('vim.api.nvim_get_current_win()')
  key(editor, 'l', 'control')
  check('resuming Neovim reclaims the bindings', function()
    return remote('vim.api.nvim_get_current_win()') ~= left and ghostty('focused') == editor
  end)

  -- Queue a real quit command; VimLeavePre and shell job control still run.
  remote('vim.api.nvim_input(":qa!\\r")')
  wait_for('Neovim did not exit', function()
    return vim.fn.getftype(socket) == ''
  end)
  key(editor, 'l', 'control')
  check('exiting Neovim restores shell navigation', function()
    return ghostty('focused') == neighbors.right
  end)
  -- The forwarding executable logs real launches, including fallbacks. The
  -- coordinator uses its original PATH and cannot contribute to this log.
  local launches = vim.fn.readfile(osascript_log)
  report(('  Neovim osascript launches: %d'):format(#launches))
  if bridge and #launches ~= 1 then
    report('  Unexpected bridge-session osascript launches:\n    ' .. table.concat(launches, '\n    '))
  end
  check('the full session used the selected transport without fallback', function()
    if bridge then
      return #launches == 1 and launches[1]:match(' focused%-terminal%-id$') ~= nil
    end
    return #launches > 1
  end)
  for _, pane in pairs(neighbors) do
    ghostty('close', pane)
  end
  neighbors = nil
  ghostty('close', editor)
  editor = nil
end

local function main()
  assert(vim.fn.has('macunix') == 1, 'E2E tests require macOS and a logged-in graphical session')
  assert(vim.fn.isdirectory(app) == 1, 'Ghostty app not found: ' .. app)
  assert(vim.fn.executable(root .. '/bin/ghostty-smart-splits-bridge') == 1, 'Run make bridge first')
  vim.fn.mkdir(scratch, 'p')
  -- Observe process launches without replacing either transport: every call
  -- receives the original arguments and runs the installed osascript binary.
  vim.fn.mkdir(scratch .. '/bin', 'p')
  vim.fn.writefile({
    '#!/bin/sh',
    'printf \'%s\\n\' "$*" >> "$GSS_OSASCRIPT_LOG"',
    'exec ' .. vim.fn.shellescape(vim.fn.exepath('osascript')) .. ' "$@"',
  }, scratch .. '/bin/osascript')
  assert(vim.fn.setfperm(scratch .. '/bin/osascript', 'rwxr-xr-x') == 1, 'Could not create osascript launch recorder')
  report('Starting isolated Ghostty. Avoid using its test windows until the run finishes.')
  process = vim.system({
    app .. '/Contents/MacOS/ghostty',
    '--config-default-files=false',
    '--config-file=' .. root .. '/tests/e2e/ghostty.conf',
  }, { text = true })
  wait_for('Ghostty did not start', function()
    return ghostty('running') == 'true'
  end)
  for _, version in ipairs({ 'v2', 'v3' }) do
    local checkout = version == 'v2' and vim.env.SMART_SPLITS_DIR or vim.env.SMART_SPLITS_V3_DIR
    assert(checkout and vim.fn.isdirectory(checkout) == 1, 'Missing smart-splits checkout for ' .. version)
    for _, bridge in ipairs({ false, true }) do
      scenario(version, bridge, checkout)
    end
  end
end

local ok, err = xpcall(main, debug.traceback)
if not ok and socket then
  local focused_ok, focused = pcall(ghostty, 'focused')
  io.stderr:write('Ghostty focus: ' .. tostring(focused_ok and focused) .. ' (editor ' .. tostring(editor) .. ')\n')
  local state_ok, state = pcall(
    remote,
    '{ mode = vim.fn.mode(), win = vim.api.nvim_get_current_win(), wins = vim.api.nvim_list_wins(), columns = vim.o.columns }'
  )
  if state_ok then
    io.stderr:write('Neovim state: ' .. vim.inspect(state) .. '\n')
  end
  local readable, messages = pcall(remote, "vim.api.nvim_exec2('messages', { output = true }).output")
  if readable then
    io.stderr:write('Neovim messages:\n' .. tostring(messages) .. '\n')
  end
end
-- Cleanup addresses the exact process we launched, even with other Ghosttys open.
local cleaned, cleanup_error = true, nil
if process then
  -- Let VimLeavePre finish its Apple Events before closing Ghostty. Otherwise
  -- an exiting Neovim can launch a new, empty Ghostty after we have quit it.
  if socket and vim.fn.getftype(socket) ~= '' then
    pcall(remote, "vim.schedule(function() vim.cmd('qa!') end)")
    cleaned, cleanup_error = pcall(wait_for, 'Neovim did not exit during cleanup', function()
      return vim.fn.getftype(socket) == ''
    end)
  end
  if neighbors then
    for _, pane in pairs(neighbors) do
      pcall(ghostty, 'close', pane)
    end
  end
  if editor then
    pcall(ghostty, 'close', editor)
  end
  local quit_ok, quit_error = pcall(ghostty, 'quit')
  if not quit_ok then
    cleaned, cleanup_error = false, quit_error
  end
  if cleaned then
    cleaned, cleanup_error = pcall(wait_for, 'Ghostty did not quit after cleanup', function()
      return ghostty('running') == 'false'
    end)
  end
end
vim.fn.delete(scratch, 'rf')
if not ok or not cleaned then
  io.stderr:write('E2E failed: ' .. tostring(err) .. '\n')
  if not cleaned then
    io.stderr:write('Cleanup failed: ' .. tostring(cleanup_error) .. '\n')
  end
  vim.cmd('cquit 1')
end
report(('PASS: 4 real sessions, %d checks'):format(passed))
