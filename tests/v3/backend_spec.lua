local h = require('tests.helpers')
local mock = h.mock

describe('v3 backend', function()
  after_each(h.restore)

  it('configuration and detection have no side effects', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.setup({ key_table = 'editor' })
    backend.setup({ key_table = 'editor' })
    assert.is_true(backend.detect())
    assert.are.equal(0, #state.calls)
    assert.is_nil(state.config)
    assert.is_false(pcall(vim.api.nvim_get_autocmds, { group = 'GhosttySmartSplits' }))
    assert.is_false(backend.move('left'))
    assert.is_false(backend.resize('left'))
    assert.is_false(backend.move('left', { at_edge = 'split' }))
    assert.is_nil(backend.split) -- Core dropped `split` from the protocol.
    assert.are.equal(0, #state.calls)
    assert.is_true(backend.activate())
    h.wait_for_calls(state, 2)
    assert.are.equal('activate_key_table:editor', h.last_action(state))
    assert.is_nil(state.config)
  end)

  it('slow threshold follows bridge mode and supports an override', function()
    mock()
    local backend = require('smart-splits-backend-ghostty')
    assert.are.equal(150, backend.slow_threshold)
    backend.setup({ bridge = true })
    assert.are.equal(100, backend.slow_threshold)
    backend.setup({ bridge = false })
    assert.are.equal(150, backend.slow_threshold)
    backend.setup({ slow_threshold = 250 })
    assert.are.equal(250, backend.slow_threshold)
  end)

  it('v3 loads independently of the v2 adapter', function()
    mock()
    require('smart-splits-backend-ghostty').activate()
    assert.are.equal('table', type(package.loaded['ghostty-smart-splits.ghostty']))
    assert.is_nil(package.loaded['smart-splits.mux.ghostty'])
  end)

  it('v3 options use the shared transport and captured terminal', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.activate()
    h.wait_for_calls(state, 2)
    state.id = 'terminal-2'
    for _, direction in ipairs({ 'left', 'right', 'up', 'down' }) do
      assert.is_true(backend.move(direction, { at_edge = 'stop', future = true }))
      assert.are.same({ 'terminal-1', 'goto_split:' .. direction }, h.last_target(state))
      assert.is_true(backend.resize(direction, { amount = 4, future = true }))
      assert.are.same('resize_split:' .. direction .. ',40', h.last_action(state))
    end
    assert.is_true(backend.resize('left'))
    assert.are.equal('resize_split:left,30', h.last_action(state))
    assert.is_true(backend.resize('left', {}))
    assert.are.equal('resize_split:left,30', h.last_action(state))
    assert.are.equal(1000, state.system_opts.timeout)
    state.response = { code = 0, stdout = 'false' }
    assert.is_false(backend.move('left', { at_edge = 'wrap' }))
    assert.is_false(backend.resize('left'))
    assert.is_false(backend.move('left', { at_edge = 'split' }))
    state.spawn_error = true
    assert.is_false(backend.move('left'))
    state.spawn_error = false
    state.response = { code = 124, stderr = 'timed out' }
    assert.is_false(backend.move('left'))
    vim.env.TERM_PROGRAM = 'other'
    local count = #state.calls
    assert.is_false(backend.move('left'))
    assert.is_false(backend.resize('left'))
    assert.is_false(backend.move('left', { at_edge = 'split' }))
    assert.are.same(count, #state.calls)
  end)

  -- Core hands `at_edge` to the backend and only acts on a false return, so the
  -- Ghostty split has to happen inside move().
  it('at_edge split becomes a Ghostty split and defers to core when it fails', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.activate()
    h.wait_for_calls(state, 2)
    state.responses = { ['goto_split:right'] = { code = 0, stdout = 'false' } }

    assert.is_true(backend.move('right', { at_edge = 'split' }))
    assert.are.equal('new_split:right', h.last_action(state))

    -- A move that lands never splits.
    assert.is_true(backend.move('left', { at_edge = 'split' }))
    assert.are.equal('goto_split:left', h.last_action(state))

    -- Every other at_edge stays core's business.
    local count = #state.calls
    assert.is_false(backend.move('right', { at_edge = 'stop' }))
    assert.is_false(backend.move('right', { at_edge = 'wrap' }))
    assert.is_false(backend.move('right'))
    assert.are.same(count + 3, #state.calls)

    -- Ghostty refusing the split returns the fallback to core.
    state.responses['new_split:right'] = { code = 0, stdout = 'false' }
    assert.is_false(backend.move('right', { at_edge = 'split' }))
  end)

  it('failed activation never follows focus during operations', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    state.id = ''
    assert.is_true(backend.activate())
    h.wait_for_calls(state, 1)
    state.id = 'unrelated-terminal'
    assert.is_false(backend.move('right'))
    assert.is_false(backend.resize('right'))
    assert.is_false(backend.move('right', { at_edge = 'split' }))
    assert.are.equal(1, #state.calls)
  end)

  it('both module names and interfaces share key-table ownership', function()
    local state = mock()
    local legacy = require('ghostty_smart_splits')
    assert.are.equal(require('ghostty-smart-splits'), legacy)
    assert.are.equal(require('ghostty-smart-splits.health'), require('ghostty_smart_splits.health'))
    legacy.setup()
    local backend = require('smart-splits-backend-ghostty')
    backend.activate()
    h.wait_for_calls(state, 2)
    for _ = 1, 2 do
      vim.api.nvim_exec_autocmds('VimEnter', {})
      assert.are.same(2 + (_ - 1) * 2, #state.calls)
      state.id = 'unrelated-terminal'
      vim.api.nvim_exec_autocmds('VimSuspend', {})
      assert.are.same({ 'terminal-1', 'deactivate_key_table' }, h.last_target(state))
      local count = #state.calls
      vim.api.nvim_exec_autocmds('VimResume', {})
      h.wait_for_calls(state, count + 1)
      assert.are.same({ 'terminal-1', 'activate_key_table:nvim' }, h.last_target(state))
    end
    vim.api.nvim_exec_autocmds('VimLeavePre', {})
    local count = #state.calls
    assert.is_true(legacy.release_keys())
    assert.are.same(count, #state.calls)
  end)

  it('backend health emits no section header or Apple Events', function()
    local state = mock()
    state.linux = true
    local reports = {}
    h.stub(
      vim,
      'health',
      setmetatable({}, {
        __index = function(_, level)
          return function()
            assert(level ~= 'start', 'core owns the health header')
            table.insert(reports, level)
          end
        end,
      })
    )
    require('smart-splits-backend-ghostty').health()
    assert.is_true(#reports > 0)
    assert.are.equal(0, #state.calls)
  end)
end)
