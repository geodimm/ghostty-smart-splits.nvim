---@diagnostic disable: duplicate-set-field
local M = {}
local MiniTest = require('mini.test')

function M.mock()
  local state = { calls = {}, warnings = {}, response = { code = 0, stdout = 'true' }, id = 'terminal-1' }
  local saved = { system = vim.system, has = vim.fn.has, executable = vim.fn.executable, notify = vim.notify_once }
  local env = {}
  for _, key in ipairs({ 'TERM_PROGRAM', 'SSH_CONNECTION', 'TMUX', 'ZELLIJ' }) do
    env[key] = vim.env[key]
    vim.env[key] = nil
  end
  vim.env.TERM_PROGRAM = 'ghostty'
  local modules = { 'ghostty_smart_splits', 'ghostty_smart_splits.mux', 'smart-splits.mux.ghostty', 'smart-splits' }
  local loaded = {}
  for _, name in ipairs(modules) do
    loaded[name] = package.loaded[name]
    package.loaded[name] = nil
  end
  package.loaded['smart-splits'] = {
    setup = function(opts)
      state.config = opts
    end,
  }
  vim.fn.has = function(feature)
    if feature == 'macunix' then
      return state.linux and 0 or 1
    end
    return saved.has(feature)
  end
  vim.fn.executable = function(name)
    return name == 'osascript' and (state.missing and 0 or 1) or saved.executable(name)
  end
  vim.notify_once = function(message)
    table.insert(state.warnings, message)
  end
  vim.system = function(argv)
    table.insert(state.calls, argv)
    assert(argv[1] == 'osascript')
    assert(vim.fn.filereadable(argv[2]) == 1)
    local response = argv[2]:match('focused%-terminal%-id') and { code = 0, stdout = state.id } or state.response
    return {
      wait = function()
        return response
      end,
    }
  end
  MiniTest.finally(function()
    vim.wait(10, function()
      return false
    end)
    vim.system, vim.fn.has, vim.fn.executable, vim.notify_once = saved.system, saved.has, saved.executable, saved.notify
    for _, key in ipairs({ 'TERM_PROGRAM', 'SSH_CONNECTION', 'TMUX', 'ZELLIJ' }) do
      vim.env[key] = env[key]
    end
    for _, name in ipairs(modules) do
      package.loaded[name] = loaded[name]
    end
    pcall(vim.api.nvim_del_augroup_by_name, 'GhosttySmartSplits')
    for _, mode in ipairs({ 'n', 'v', 't' }) do
      for _, lhs in ipairs({ '<C-h>', '<C-j>', '<C-k>', '<C-l>' }) do
        pcall(vim.keymap.del, mode, lhs)
      end
    end
    vim.cmd('silent! only!')
  end)
  return state
end

return M
