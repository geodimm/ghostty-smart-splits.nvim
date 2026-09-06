local T = require('mini.test').new_set()
local eq = require('mini.test').expect.equality

local function wait_for_calls(state, count)
  assert(vim.wait(100, function()
    return #state.calls >= count
  end, 1))
end

local function setup(opts)
  local state = require('tests.helpers').mock()
  package.loaded['smart-splits'] = nil
  local splits = require('smart-splits')
  eq(splits.PROTOCOL_VERSION, vim.version.parse('3.0.0'))
  splits.setup(vim.tbl_deep_extend('force', {
    mux = { backend = 'smart-splits-backend-ghostty' },
    move = { at_edge = 'stop' },
    log = { file = false },
  }, opts or {}))
  wait_for_calls(state, 2)
  return state, splits
end

T['core selects and activates the backend without changing user options'] = function()
  local state, splits = setup({ resize = { amount = 5 }, move = { at_edge = 'wrap' } })
  eq(require('smart-splits.backend').resolve(), require('smart-splits-backend-ghostty'))
  eq(require('smart-splits.config').issues(), {})
  eq(require('smart-splits.config').move.at_edge, 'wrap')
  eq(require('smart-splits.config').resize.amount, 5)
  eq(#state.calls, 2)
  eq(state.calls[2][4], 'activate_key_table:nvim')
  splits.resize_right()
  eq(state.calls[#state.calls][4], 'resize_split:right,50')
  splits.resize_down({ amount = 7 })
  eq(state.calls[#state.calls][4], 'resize_split:down,70')
  vim.api.nvim_exec_autocmds('VimSuspend', {})
  eq(state.calls[#state.calls][4], 'deactivate_key_table')
  local count = #state.calls
  vim.api.nvim_exec_autocmds('VimResume', {})
  wait_for_calls(state, count + 1)
  eq(state.calls[#state.calls][4], 'activate_key_table:nvim')
end

T['navigation stays inside Neovim until the edge then delegates'] = function()
  local state, splits = setup()
  vim.cmd('vsplit')
  vim.cmd('wincmd h')
  local left = vim.api.nvim_get_current_win()
  local count = #state.calls
  splits.move_cursor_right()
  eq(vim.api.nvim_get_current_win() ~= left, true)
  eq(#state.calls, count)
  splits.move_cursor_right()
  eq(#state.calls, count + 1)
  eq(state.calls[#state.calls][4], 'goto_split:right')
  state.response = { code = 0, stdout = 'false' }
  splits.move_cursor_right({ at_edge = 'wrap' })
  eq(vim.api.nvim_get_current_win(), left)
end

T['split delegates after an unhandled move and falls back when Ghostty fails'] = function()
  local state, splits = setup({ move = { at_edge = 'split' } })
  state.responses = { ['goto_split:right'] = { code = 0, stdout = 'false' } }
  splits.move_cursor_right()
  eq(state.calls[#state.calls][4], 'new_split:right')
  eq(#vim.api.nvim_list_wins(), 1)
  state.responses['new_split:right'] = { code = 0, stdout = 'false' }
  splits.move_cursor_right()
  eq(#vim.api.nvim_list_wins(), 2)
end

T['an unselected backend can be configured without claiming keys'] = function()
  local state = require('tests.helpers').mock()
  local ghostty = require('smart-splits-backend-ghostty')
  ghostty.setup({ key_table = 'editor' })
  package.loaded['smart-splits'] = nil
  local preferred = {
    name = 'preferred',
    protocol_version = '3.0.0',
    detect = function()
      return true
    end,
    move = function()
      return false
    end,
  }
  require('smart-splits').setup({ mux = { backend = { preferred, ghostty } }, log = { file = false } })
  eq(require('smart-splits.backend').resolve(), preferred)
  eq(#state.calls, 0)
  eq(pcall(vim.api.nvim_get_autocmds, { group = 'GhosttySmartSplits' }), false)
end

T['unsupported sessions are skipped and keep plain Neovim navigation'] = function()
  local state = require('tests.helpers').mock()
  state.linux = true
  package.loaded['smart-splits'] = nil
  local splits = require('smart-splits')
  splits.setup({
    mux = { backend = 'smart-splits-backend-ghostty', warn_if_unusable = false },
    log = { file = false },
  })
  eq(require('smart-splits.backend').resolve(), nil)
  splits.move_cursor_right()
  eq(#state.calls, 0)
  eq(require('smart-splits.backend').report()[1].status, 'skipped')
end

return T
