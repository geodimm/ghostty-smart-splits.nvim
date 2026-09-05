# ghostty-smart-splits.nvim

Navigate between Neovim splits and Ghostty panes on macOS with the same keys.

Ctrl+h/j/k/l moves inside Neovim first. At the editor's edge, it moves into
Ghostty. Shell panes keep their native Ghostty navigation.

A macOS bridge for [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim).
This is an independent plugin, not an official Ghostty or smart-splits backend.

## Requirements

- Neovim 0.11+ and smart-splits.nvim.
- Ghostty 1.3+ on macOS (developed against 1.3.1).
- Local Neovim running directly in Ghostty.
- Ghostty AppleScript support and macOS Automation permission. AppleScript is
  enabled by default; do not set `macos-applescript = false`.
  See [Ghostty's AppleScript guide](https://ghostty.org/docs/features/applescript).

Linux and other terminals are left untouched: `setup()` returns `false` without
installing mappings or running AppleScript.

## Installation

With lazy.nvim:

```lua
{
  'geodimm/ghostty-smart-splits.nvim',
  lazy = false,
  dependencies = { 'mrjones2014/smart-splits.nvim' },
  config = function()
    local opts = {} -- Your existing smart-splits options.
    if not require('ghostty_smart_splits').setup({ smart_splits = opts }) then
      local splits = require('smart-splits')
      splits.setup(opts)
      for key, direction in pairs({ h = 'left', j = 'down', k = 'up', l = 'right' }) do
        vim.keymap.set('n', '<C-' .. key .. '>', splits['move_cursor_' .. direction])
      end
    end
  end,
}
```

Do not also call `smart-splits.setup()` from a separate plugin spec. This bridge
calls it on supported sessions and owns the Ghostty-specific settings.

With Neovim's built-in `vim.pack` (Neovim 0.12+):

```lua
vim.pack.add({
  'https://github.com/mrjones2014/smart-splits.nvim',
  'https://github.com/geodimm/ghostty-smart-splits.nvim',
})
require('ghostty_smart_splits').setup()
```

Load the plugin at startup while this Neovim's Ghostty pane has focus. The bridge
captures that terminal's ID once and uses it for later actions, including cleanup.
Delayed/background setup can capture the wrong terminal.

## Ghostty configuration

Add this to your Ghostty config and reload it **before starting Neovim**:

```ini
# Outside Neovim, navigate Ghostty panes.
keybind = performable:ctrl+h=goto_split:left
keybind = performable:ctrl+j=goto_split:down
keybind = performable:ctrl+k=goto_split:up
keybind = performable:ctrl+l=goto_split:right

# Inside Neovim, pass the keys to the editor first.
keybind = nvim/
keybind = nvim/ctrl+h=text:\x08
keybind = nvim/ctrl+j=text:\x0a
keybind = nvim/ctrl+k=text:\x0b
keybind = nvim/ctrl+l=text:\x0c
```

A copy is in [examples/ghostty.conf](examples/ghostty.conf). On first use, allow
macOS to automate Ghostty when prompted. If access was denied, review System
Settings → Privacy & Security → Automation.

The table is pushed on startup/resume and popped on suspend/exit. This keeps
Neovim's keys local to its Ghostty terminal; it does not reconfigure other panes.

## Configuration

Defaults:

```lua
require('ghostty_smart_splits').setup({
  key_table = 'nvim',
  keymaps = {
    left = '<C-h>',
    down = '<C-j>',
    up = '<C-k>',
    right = '<C-l>',
  },
  modes = { 'n', 'v', 't' },
  smart_splits = {},
})
```

Use `keymaps = false` to manage all mappings yourself, or set an individual
direction to `false` to leave it unmapped. If you change the keys or table name,
update the Ghostty configuration to match.

```lua
vim.keymap.set({ 'n', 'v', 't' }, '<C-h>', function()
  require('ghostty_smart_splits').move('left')
end)
```

`move(direction)` accepts `left`, `right`, `up`, or `down` and returns whether
a move succeeded. `claim_keys()` and `release_keys()` can manually acquire/release
the table. Repeated claims/releases do not push/pop additional tables.

The bridge forces `multiplexer_integration = 'ghostty'`, `at_edge = 'stop'`,
and `disable_multiplexer_nav_when_zoomed = false`. Other options belong in
`smart_splits`.

## How it works

Ghostty’s `performable` bindings let Neovim handle Ctrl+h/j/k/l first. The plugin
moves to a neighboring Neovim window when one exists. At the editor’s edge, it
calls Ghostty’s AppleScript API to move to the adjacent pane.

The plugin captures the focused Ghostty terminal when setup runs, activates a
temporary key table while Neovim is active, and releases it when Neovim is
suspended or exits. Unsupported platforms and terminals are left unchanged.

## Limitations

- macOS only. There is no Linux/D-Bus implementation in this plugin.
- AppleScript calls are synchronous; crossing an editor edge may have noticeable
  latency. Moving between ordinary Neovim splits does not launch a subprocess.
- Initial terminal association depends on focus, not a process-to-surface lookup.
  Later actions use the captured ID and do not silently retarget after focus changes.
- Do not stack another Ghostty key table above this one while Neovim is active.
  Cleanup pops the top table; Ghostty's pop action cannot remove a table by name.
  A crash cannot clean up. An optional recovery binding is
  `keybind = ctrl+shift+escape=deactivate_all_key_tables`; it clears **all** tables.
  Reloading Ghostty's config during a session can also invalidate table state.
- The custom movement mappings do not implement smart-splits counts, wrapping,
  ignored-buffer rules, or split-at-edge behavior.

Native `performable:goto_split` bindings are enough if you prefer Ghostty panes
to take priority. This plugin is for the opposite order: Neovim first.

## Troubleshooting and development

Run `:checkhealth ghostty_smart_splits` for local prerequisites. The health check
does not send Apple Events or verify Automation permissions.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks and a manual smoke test, and
`:help ghostty-smart-splits` for the API.

MIT licensed.
