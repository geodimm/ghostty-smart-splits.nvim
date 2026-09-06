local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality

-- Exercise the real runner without opening panes or starting a bridge.
local function run(failure)
  local state = { focus = 'original', closed = {}, commands = {}, errors = '', bridge_stopped = false }
  local function result(stdout, code)
    return {
      wait = function()
        return { code = code or 0, stdout = stdout, stderr = 'injected failure' }
      end,
    }
  end
  local fake_vim = setmetatable({
    fn = setmetatable({
      has = function()
        return 1
      end,
      executable = function()
        return 1
      end,
      writefile = function(lines)
        state.report = vim.json.decode(lines[1])
        return 0
      end,
    }, { __index = vim.fn }),
    cmd = function(command)
      state.commands[#state.commands + 1] = command
    end,
    system = function(argv, opts)
      if argv[1] ~= 'osascript' then
        return {
          write = function(_, data)
            if not data then
              state.bridge_stopped = true
              return
            end
            local request = vim.json.decode(data)
            eq(request.terminalID, state.focus)
            state.focus = request.action == 'goto_split:right' and 'temporary' or 'original'
            opts.stdout(nil, vim.json.encode({ ok = true, result = failure == 'action' and 'false' or 'true' }) .. '\n')
          end,
          wait = function()
            return { code = 0 }
          end,
        }
      end
      if argv[2]:find('/pane.applescript', 1, true) then
        local operation, id = argv[3], argv[4]
        if operation == 'split' then
          eq(id, 'original')
          if failure == 'setup' then
            return result('', 1)
          end
          if failure == 'same-id' then
            return result('original')
          end
          state.focus = 'temporary'
          return result('temporary')
        elseif operation == 'close' then
          eq(id, 'temporary')
          eq(argv[5], 'original')
          state.closed[#state.closed + 1] = id
          if failure == 'cleanup' then
            return result('', 1)
          end
        elseif operation == 'focus' then
          state.focus = id
        else
          error('unexpected pane operation')
        end
        return result('')
      elseif argv[2]:find('/focused-terminal-id.applescript', 1, true) then
        return result(state.focus)
      end
      assert(argv[2]:find('/perform-action.applescript', 1, true))
      eq(argv[3], state.focus)
      state.focus = argv[4] == 'goto_split:right' and 'temporary' or 'original'
      return result('true')
    end,
  }, { __index = vim })
  local runner = assert(loadfile('tests/bench/run.lua'))
  setfenv(
    runner,
    setmetatable({
      vim = fake_vim,
      arg = { '--pairs', '2', '--warmup', '1', '--json', '/unused/mock-report.json' },
      print = function() end,
      io = {
        stderr = {
          write = function(_, message)
            state.errors = state.errors .. message
          end,
        },
      },
    }, { __index = _G })
  )
  runner()
  return state
end

T['benchmark creates its own pane and cleans up after measuring'] = function()
  local state = run()
  eq(state.closed, { 'temporary' })
  eq(state.focus, 'original')
  eq(state.bridge_stopped, true)
  eq(state.commands, {})
  eq(state.report.transports.bridge.count, 4)
  eq(state.report.transports.osascript.count, 4)
end

T['benchmark cleans up and restores focus after an action failure'] = function()
  local state = run('action')
  eq(state.closed, { 'temporary' })
  eq(state.focus, 'original')
  eq(state.bridge_stopped, true)
  eq(state.commands, { 'cquit 1' })
  eq(state.report, nil)
end

T['benchmark never closes an unknown or original pane on setup failure'] = function()
  for _, failure in ipairs({ 'setup', 'same-id' }) do
    local state = run(failure)
    eq(state.closed, {})
    eq(state.focus, 'original')
    eq(state.commands, { 'cquit 1' })
    eq(state.report, nil)
  end
end

T['benchmark restores focus and reports cleanup failures'] = function()
  local state = run('cleanup')
  eq(state.focus, 'original')
  eq(state.commands, { 'cquit 1' })
  assert(state.errors:find('Pane cleanup failed', 1, true))
end

return T
