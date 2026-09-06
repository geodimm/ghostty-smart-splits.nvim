local h = require('tests.helpers')

describe('bench harness', function()
  after_each(h.restore)

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
              assert.are.same(state.focus, request.terminalID)
              state.focus = request.action == 'goto_split:right' and 'temporary' or 'original'
              opts.stdout(
                nil,
                vim.json.encode({ ok = true, result = failure == 'action' and 'false' or 'true' }) .. '\n'
              )
            end,
            wait = function()
              return { code = 0 }
            end,
          }
        end
        if argv[2]:find('/pane.applescript', 1, true) then
          local operation, id = argv[3], argv[4]
          if operation == 'split' then
            assert.are.equal('original', id)
            if failure == 'setup' then
              return result('', 1)
            end
            if failure == 'same-id' then
              return result('original')
            end
            state.focus = 'temporary'
            return result('temporary')
          elseif operation == 'close' then
            assert.are.equal('temporary', id)
            assert.are.equal('original', argv[5])
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
        assert.are.same(state.focus, argv[3])
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

  it('benchmark creates its own pane and cleans up after measuring', function()
    local state = run()
    assert.are.same({ 'temporary' }, state.closed)
    assert.are.equal('original', state.focus)
    assert.is_true(state.bridge_stopped)
    assert.are.same({}, state.commands)
    assert.are.equal(4, state.report.transports.bridge.count)
    assert.are.equal(4, state.report.transports.osascript.count)
  end)

  it('benchmark cleans up and restores focus after an action failure', function()
    local state = run('action')
    assert.are.same({ 'temporary' }, state.closed)
    assert.are.equal('original', state.focus)
    assert.is_true(state.bridge_stopped)
    assert.are.same({ 'cquit 1' }, state.commands)
    assert.is_nil(state.report)
  end)

  it('benchmark never closes an unknown or original pane on setup failure', function()
    for _, failure in ipairs({ 'setup', 'same-id' }) do
      local state = run(failure)
      assert.are.same({}, state.closed)
      assert.are.equal('original', state.focus)
      assert.are.same({ 'cquit 1' }, state.commands)
      assert.is_nil(state.report)
    end
  end)

  it('benchmark restores focus and reports cleanup failures', function()
    local state = run('cleanup')
    assert.are.equal('original', state.focus)
    assert.are.same({ 'cquit 1' }, state.commands)
    assert(state.errors:find('Pane cleanup failed', 1, true))
  end)
end)
