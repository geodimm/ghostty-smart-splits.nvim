-- Busted helper: runs once per busted process, before any spec is collected.
-- `nlua` makes Neovim the Lua interpreter, so this is the equivalent of the
-- `-u` init script the runner used before.
local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)
-- `tests/` is not on the runtimepath, so `require('tests.helpers')` resolves
-- through package.path instead.
package.path = table.concat({ root .. '/?.lua', root .. '/?/init.lua', package.path }, ';')
vim.opt.shadafile = 'NONE'
vim.lsp.log.set_level('off')
