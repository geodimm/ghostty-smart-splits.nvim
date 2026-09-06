---@diagnostic disable: duplicate-set-field
local M = {}
local MiniTest = require('mini.test')

function M.mock()
  local state = {
    calls = {},
    warnings = {},
    response = { code = 0, stdout = 'true' },
    id = 'terminal-1',
    bridge_starts = {},
    bridge_requests = {},
    bridge_stops = {},
  }
  local saved = {
    system = vim.system,
    has = vim.fn.has,
    executable = vim.fn.executable,
    notify = vim.notify_once,
    jobstart = vim.fn.jobstart,
    jobstop = vim.fn.jobstop,
    chansend = vim.fn.chansend,
  }
  local env = {}
  for _, key in ipairs({ 'TERM_PROGRAM', 'SSH_CONNECTION', 'TMUX', 'ZELLIJ' }) do
    env[key] = vim.env[key]
    vim.env[key] = nil
  end
  vim.env.TERM_PROGRAM = 'ghostty'
  local modules = {
    'ghostty_smart_splits',
    'ghostty_smart_splits.health',
    'ghostty-smart-splits',
    'ghostty-smart-splits.config',
    'ghostty-smart-splits.bridge',
    'ghostty-smart-splits.ghostty',
    'ghostty-smart-splits.health',
    'ghostty-smart-splits.session',
    'smart-splits-backend-ghostty',
    'smart-splits.mux.ghostty',
    'smart-splits',
  }
  for name in pairs(package.loaded) do
    if name:match('^smart%-splits%.') and name ~= 'smart-splits.mux.ghostty' then
      table.insert(modules, name)
    end
  end
  local loaded = {}
  for _, name in ipairs(modules) do
    loaded[name] = package.loaded[name]
    package.loaded[name] = nil
  end
  package.loaded['smart-splits'] = {
    setup = function(opts)
      state.config = vim.tbl_deep_extend('force', state.config or {}, opts)
    end,
  }
  vim.fn.has = function(feature)
    if feature == 'macunix' then
      return state.linux and 0 or 1
    end
    return saved.has(feature)
  end
  vim.fn.executable = function(name)
    if name:match('ghostty%-smart%-splits%-bridge$') then
      return state.bridge_available and 1 or 0
    end
    return name == 'osascript' and (state.missing and 0 or 1) or saved.executable(name)
  end
  vim.notify_once = function(message)
    table.insert(state.warnings, message)
  end
  local bridge_callbacks
  vim.fn.jobstart = function(argv, opts)
    assert(argv[1]:match('ghostty%-smart%-splits%-bridge$'))
    table.insert(state.bridge_starts, argv)
    bridge_callbacks = opts
    return state.bridge_start_failure and -1 or #state.bridge_starts
  end
  vim.fn.jobstop = function(job)
    table.insert(state.bridge_stops, job)
    return 1
  end
  vim.fn.chansend = function(job, data)
    local request = vim.json.decode(data)
    table.insert(state.bridge_requests, request)
    local response = state.bridge_response
      or (request.command == 'focused-terminal-id' and { ok = true, result = state.id })
      or { ok = true, result = 'true' }
    -- Mirror the osascript mock: a successful move lands in the next terminal.
    if
      request.command == 'perform'
      and (request.action or ''):match('^goto_split:')
      and response.ok
      and response.result == 'true'
      and state.next_id
    then
      state.id = state.next_id
    end
    bridge_callbacks.on_stdout(job, { vim.json.encode(response), '' })
    return #data
  end
  vim.system = function(argv, opts, on_exit)
    table.insert(state.calls, argv)
    state.system_opts = opts
    if state.spawn_error then
      error('osascript failed to start')
    end
    assert(argv[1] == 'osascript')
    assert(vim.fn.filereadable(argv[2]) == 1)
    local response = argv[2]:match('focused%-terminal%-id') and { code = 0, stdout = state.id }
      or (state.responses or {})[argv[4]]
      or state.response
    if on_exit then
      on_exit(response)
    end
    return {
      wait = function()
        if
          argv[2]:match('perform%-action')
          and argv[4]
          and argv[4]:match('^goto_split:')
          and response.code == 0
          and vim.trim(response.stdout or '') == 'true'
          and state.next_id
        then
          state.id = state.next_id
        end
        return response
      end,
    }
  end
  MiniTest.finally(function()
    vim.wait(10, function()
      return false
    end)
    vim.system, vim.fn.has, vim.fn.executable, vim.notify_once = saved.system, saved.has, saved.executable, saved.notify
    vim.fn.jobstart, vim.fn.jobstop, vim.fn.chansend = saved.jobstart, saved.jobstop, saved.chansend
    for _, key in ipairs({ 'TERM_PROGRAM', 'SSH_CONNECTION', 'TMUX', 'ZELLIJ' }) do
      vim.env[key] = env[key]
    end
    for name in pairs(package.loaded) do
      if name:match('^smart%-splits%.') then
        package.loaded[name] = nil
      end
    end
    for _, name in ipairs(modules) do
      package.loaded[name] = loaded[name]
    end
    pcall(vim.api.nvim_del_augroup_by_name, 'GhosttySmartSplits')
    vim.cmd('silent! only!')
  end)
  return state
end

return M
