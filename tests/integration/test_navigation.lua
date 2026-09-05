local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality
local mock = require('tests.helpers').mock

T['setup preserves smart-splits options and does not create mappings'] = function()
  local state = mock()
  local plugin = require('ghostty_smart_splits')
  require('smart-splits').setup({ default_amount = 5 })
  eq(plugin.setup(), true)
  eq(state.config.multiplexer_integration, 'ghostty')
  eq(state.config.at_edge, 'stop')
  eq(state.config.default_amount, 5)
  eq(vim.fn.maparg('<C-h>', 'n'), '')
end

T['lifecycle events push once and pop once across repeated resumes'] = function()
  local state = mock()
  local plugin = require('ghostty_smart_splits')
  plugin.setup()
  plugin.setup()
  eq(#state.calls, 2)
  for _ = 1, 2 do
    vim.api.nvim_exec_autocmds('VimEnter', {})
    eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    eq(state.calls[#state.calls][4], 'deactivate_key_table')
    local count = #state.calls
    plugin.release_keys()
    eq(#state.calls, count)
    vim.api.nvim_exec_autocmds('VimResume', {})
    eq(#state.calls, count + 1)
    eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
  end
  vim.api.nvim_exec_autocmds('VimLeavePre', {})
  eq(state.calls[#state.calls][4], 'deactivate_key_table')
end

T['custom tables and failed release retries'] = function()
  local state = mock()
  local plugin = require('ghostty_smart_splits')
  require('smart-splits').setup({ default_amount = 5 })
  local opts = { key_table = 'editor' }
  plugin.setup(opts)
  eq(state.calls[#state.calls][4], 'activate_key_table:editor')
  eq(state.config.default_amount, 5)
  eq(opts.multiplexer_integration, nil)
  state.response = { code = 0, stdout = 'false' }
  eq(plugin.release_keys(), false)
  state.response = { code = 0, stdout = 'true' }
  eq(plugin.release_keys(), true)
end

return T
