local h = require('tests.helpers')

describe('v3 smart-splits integration', function()
  after_each(h.restore)

  local function start_smart_splits(opts)
    local state = h.mock()
    package.loaded['smart-splits'] = nil
    local splits = require('smart-splits')
    assert.are.same(vim.version.parse('3.0.0'), splits.PROTOCOL_VERSION)
    splits.setup(vim.tbl_deep_extend('force', {
      mux = { backend = 'smart-splits-backend-ghostty' },
      move = { at_edge = 'stop' },
      log = { file = false },
    }, opts or {}))
    h.wait_for_calls(state, 2)
    return state, splits
  end

  it('core selects and activates the backend without changing user options', function()
    local state, splits = start_smart_splits({ resize = { amount = 5 }, move = { at_edge = 'wrap' } })
    assert.are.equal(require('smart-splits-backend-ghostty'), require('smart-splits.backend').resolve())
    assert.are.same({}, require('smart-splits.config').issues())
    assert.are.equal('wrap', require('smart-splits.config').move.at_edge)
    assert.are.equal(5, require('smart-splits.config').resize.amount)
    assert.are.equal(2, #state.calls)
    assert.are.equal('activate_key_table:nvim', state.calls[2][4])
    splits.resize_right()
    assert.are.equal('resize_split:right,50', h.last_action(state))
    splits.resize_down({ amount = 7 })
    assert.are.equal('resize_split:down,70', h.last_action(state))
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    assert.are.equal('deactivate_key_table', h.last_action(state))
    local count = #state.calls
    vim.api.nvim_exec_autocmds('VimResume', {})
    h.wait_for_calls(state, count + 1)
    assert.are.equal('activate_key_table:nvim', h.last_action(state))
  end)

  it('navigation stays inside Neovim until the edge then delegates', function()
    local state, splits = start_smart_splits()
    vim.cmd('vsplit')
    vim.cmd('wincmd h')
    local left = vim.api.nvim_get_current_win()
    local count = #state.calls
    splits.move_cursor_right()
    assert.is_true(vim.api.nvim_get_current_win() ~= left)
    assert.are.same(count, #state.calls)
    splits.move_cursor_right()
    assert.are.same(count + 1, #state.calls)
    assert.are.equal('goto_split:right', h.last_action(state))
    state.response = { code = 0, stdout = 'false' }
    splits.move_cursor_right({ at_edge = 'wrap' })
    assert.are.same(left, vim.api.nvim_get_current_win())
  end)

  it('split delegates after an unhandled move and falls back when Ghostty fails', function()
    local state, splits = start_smart_splits({ move = { at_edge = 'split' } })
    state.responses = { ['goto_split:right'] = { code = 0, stdout = 'false' } }
    splits.move_cursor_right()
    assert.are.equal('new_split:right', h.last_action(state))
    assert.are.equal(1, #vim.api.nvim_list_wins())
    state.responses['new_split:right'] = { code = 0, stdout = 'false' }
    splits.move_cursor_right()
    assert.are.equal(2, #vim.api.nvim_list_wins())
  end)

  it('an unselected backend can be configured without claiming keys', function()
    local state = h.mock()
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
    assert.are.equal(preferred, require('smart-splits.backend').resolve())
    assert.are.equal(0, #state.calls)
    assert.is_false(pcall(vim.api.nvim_get_autocmds, { group = 'GhosttySmartSplits' }))
  end)

  it('unsupported sessions are skipped and keep plain Neovim navigation', function()
    local state = h.mock()
    state.linux = true
    package.loaded['smart-splits'] = nil
    local splits = require('smart-splits')
    splits.setup({
      mux = { backend = 'smart-splits-backend-ghostty', warn_if_unusable = false },
      log = { file = false },
    })
    assert.is_nil(require('smart-splits.backend').resolve())
    splits.move_cursor_right()
    assert.are.equal(0, #state.calls)
    assert.are.equal('skipped', require('smart-splits.backend').report()[1].status)
  end)
end)
