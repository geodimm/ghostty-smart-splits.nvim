local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

T['uses the default key table'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  config.setup()
  eq(config.get_key_table(), 'nvim')
end

T['accepts a custom key table'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  config.setup({ key_table = 'editor' })
  eq(config.get_key_table(), 'editor')
end

T['rejects invalid key tables'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  for _, value in ipairs({ '', 1, false }) do
    local ok, message = pcall(config.setup, { key_table = value })
    eq(ok, false)
    assert(type(message) == 'string')
    eq(message:match('key_table must be a non%-empty string$'), 'key_table must be a non-empty string')
  end
end

return T
