local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(vim.env.SMART_SPLITS_DIR or vim.fs.joinpath(root, 'deps', 'smart-splits.nvim'))
vim.opt.runtimepath:append(vim.env.MINITEST_DIR or vim.fs.joinpath(root, 'deps', 'mini.test'))
vim.opt.shadafile = 'NONE'
vim.lsp.log.set_level('off')

require('mini.test').setup({
  collect = { emulate_busted = false },
  execute = { reporter = require('mini.test').gen_reporter.stdout({ group_depth = 3 }) },
})
