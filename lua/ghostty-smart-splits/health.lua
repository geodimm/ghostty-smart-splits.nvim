local M = {}

function M.report()
  if vim.fn.has('nvim-0.11') == 1 then
    vim.health.ok('Neovim >= 0.11')
  else
    vim.health.error('Neovim >= 0.11 is required')
  end
  if vim.fn.has('macunix') == 1 then
    vim.health.ok('macOS')
  else
    vim.health.warn('Only macOS is supported; setup() is a no-op here')
  end
  if vim.fn.executable('osascript') == 1 then
    vim.health.ok('osascript is available')
  else
    vim.health.warn('osascript is unavailable')
  end
  local bridge = require('ghostty-smart-splits.bridge').status()
  if not require('ghostty-smart-splits.config').get_bridge() then
    vim.health.info('bridge = false: actions use osascript')
  elseif bridge.running then
    vim.health.ok('bridge = true: persistent bridge is running')
  elseif bridge.executable then
    vim.health.info('bridge = true: binary is available; bridge is not running')
  else
    vim.health.warn('bridge = true: binary is missing; actions fall back to osascript. Run make bridge')
  end
  vim.health.info('Bridge path: ' .. bridge.path)
  if vim.env.TERM_PROGRAM == 'ghostty' then
    vim.health.ok('Running in Ghostty')
  else
    vim.health.warn('Not running in Ghostty')
  end
  if vim.env.SSH_CONNECTION or vim.env.TMUX or vim.env.ZELLIJ then
    vim.health.warn('SSH and nested terminal multiplexers are not supported')
  end
  if pcall(require, 'smart-splits') then
    vim.health.ok('smart-splits.nvim is available')
  else
    vim.health.error('Install mrjones2014/smart-splits.nvim')
  end
  vim.health.info(
    'Enable Ghostty AppleScript, configure the nvim key table, and allow macOS Automation access (see README)'
  )
  vim.health.info('Health checks do not send Apple Events or test Automation permissions')
end

function M.check()
  vim.health.start('ghostty-smart-splits.nvim')
  M.report()
end

return M
