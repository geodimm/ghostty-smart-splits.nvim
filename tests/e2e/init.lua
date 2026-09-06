-- This is the visible Neovim running inside Ghostty, with no user config.
vim.opt.runtimepath:prepend(vim.env.GSS_ROOT)
vim.opt.runtimepath:append(vim.env.GSS_SMART_SPLITS)
vim.opt.swapfile = false
vim.opt.shadafile = 'NONE'
vim.opt.termguicolors = true
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 50
vim.opt.background = 'dark'
vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })

local splits = require('smart-splits')
local opts = { bridge = vim.env.GSS_BRIDGE == 'true' }
if vim.env.GSS_VERSION == 'v3' then
  require('smart-splits-backend-ghostty').setup(opts)
  splits.setup({ mux = { backend = 'smart-splits-backend-ghostty' }, move = { at_edge = 'stop' } })
else
  splits.setup({})
  require('ghostty-smart-splits').setup(opts)
end
for key, direction in pairs({ h = 'left', j = 'down', k = 'up', l = 'right' }) do
  vim.keymap.set('n', '<C-' .. key .. '>', splits['move_cursor_' .. direction])
  vim.keymap.set('n', '<M-' .. key .. '>', splits['resize_' .. direction])
end
vim.keymap.set('n', '<F12>', function()
  vim.g.e2e_probe = (vim.g.e2e_probe or 0) + 1
end)
vim.cmd('vsplit | wincmd h')
vim.g.e2e_ready = true
