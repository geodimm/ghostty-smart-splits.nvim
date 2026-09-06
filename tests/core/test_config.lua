local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

T['uses the default key table'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  config.setup()
  eq(config.key_table, 'nvim')
end

T['accepts a custom key table'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  config.setup({ key_table = 'editor' })
  eq(config.key_table, 'editor')
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
  eq(config.bridge, false)
  config.setup({ bridge = true, key_table = 'editor' })
  eq(config.bridge, true)
  for _, value in ipairs({ 'false', 0, {} }) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, message = pcall(config.setup, { bridge = value })
    eq(ok, false)
    assert(tostring(message):find('bridge must be a boolean', 1, true))
    eq(config.bridge, true)
    eq(config.key_table, 'editor')
  end
  config.reset()
  eq(config.bridge, false)
end

T['slow threshold follows the transport and accepts a positive integer override'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  eq(config.slow_threshold, 150)
  config.setup({ bridge = true })
  eq(config.slow_threshold, 100)
  config.setup({ bridge = false })
  eq(config.slow_threshold, 150)
  config.setup({ slow_threshold = 200 })
  eq(config.slow_threshold, 200)
  config.setup({ bridge = true })
  eq(config.slow_threshold, 200)
  config.reset()
  eq(config.slow_threshold, 150)
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
    eq(config.bridge, true)
    eq(config.key_table, 'editor')
    eq(config.slow_threshold, 200)
  end
end

T['setup merges over the current options and reset restores defaults'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  config.setup({ key_table = 'editor', bridge = true, slow_threshold = 200 })

  -- Naming one option leaves the rest alone, however many calls it takes.
  config.setup({ bridge = false })
  eq(config.bridge, false)
  eq(config.key_table, 'editor')
  eq(config.slow_threshold, 200)
  config.setup()
  eq(config.key_table, 'editor')
  eq(config.slow_threshold, 200)

  config.reset()
  eq(config.key_table, 'nvim')
  eq(config.bridge, false)
  eq(config.slow_threshold, 150)

  -- An explicit value still wins, and an invalid one is still rejected.
  config.setup({ key_table = 'other' })
  eq(config.key_table, 'other')
  for _, value in ipairs({ '', 1, false }) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    eq(pcall(config.setup, { key_table = value }), false)
    eq(config.key_table, 'other')
  end
end

T['unknown options are rejected instead of silently dropped'] = function()
  mock()
  local config = require('ghostty-smart-splits.config')
  config.setup({ key_table = 'editor' })
  for _, opts in ipairs({ { bridge_enabled = true }, { keytable = 'x' }, { slowThreshold = 200 } }) do
    local ok, message = pcall(config.setup, opts)
    eq(ok, false)
    assert(tostring(message):find('unknown option', 1, true))
  end
  eq(config.key_table, 'editor')
  eq(config.bridge, false)
end

return T
