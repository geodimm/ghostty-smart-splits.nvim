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

T['bridge defaults to false and rejects invalid values without changing config'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  eq(config.get_bridge(), false)
  config.setup({ bridge = true, key_table = 'editor' })
  eq(config.get_bridge(), true)
  for _, value in ipairs({ 'false', 0, {} }) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, message = pcall(config.setup, { bridge = value })
    eq(ok, false)
    assert(tostring(message):find('bridge must be a boolean', 1, true))
    eq(config.get_bridge(), true)
    eq(config.get_key_table(), 'editor')
  end
  config.setup()
  eq(config.get_bridge(), false)
end

T['slow threshold follows the transport and accepts a positive integer override'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  eq(config.get_slow_threshold(), 150)
  config.setup({ bridge = true })
  eq(config.get_slow_threshold(), 100)
  config.setup({ bridge = false })
  eq(config.get_slow_threshold(), 150)
  config.setup({ slow_threshold = 200 })
  eq(config.get_slow_threshold(), 200)
end

T['rejects invalid slow thresholds without changing config'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  config.setup({ bridge = true, key_table = 'editor', slow_threshold = 200 })
  for _, value in ipairs({ 0, -1, 1.5, '200', false, {} }) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, message = pcall(config.setup, { slow_threshold = value })
    eq(ok, false)
    assert(tostring(message):find('slow_threshold must be a positive integer', 1, true))
    eq(config.get_bridge(), true)
    eq(config.get_key_table(), 'editor')
    eq(config.get_slow_threshold(), 200)
  end
end

return T
