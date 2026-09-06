# ghostty-smart-splits.nvim

Navigate between Neovim splits and Ghostty panes on macOS with the same keys.

Your smart-splits navigation keys move inside Neovim first. At the editor's
edge, the matching Ghostty bindings move into an adjacent pane. Shell panes
keep their native Ghostty navigation.

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
changing smart-splits or running AppleScript.

## Installation

### smart-splits v2

With lazy.nvim:

```lua
{
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  dependencies = { 'geodimm/ghostty-smart-splits.nvim' },
  config = function()
    local splits = require('smart-splits')
    local opts = {} -- Your existing smart-splits options.
    splits.setup(opts)
    require('ghostty-smart-splits').setup()
    -- Keep your existing smart-splits mappings.
  end,
}
```

Keep your existing smart-splits options and mappings. Add this plugin as a
dependency, then call its setup after `smart-splits.setup()`.

With Neovim's built-in `vim.pack` (Neovim 0.12+):

```lua
vim.pack.add({
  'https://github.com/mrjones2014/smart-splits.nvim',
  'https://github.com/geodimm/ghostty-smart-splits.nvim',
})

local splits = require('smart-splits')
local opts = {} -- Your existing smart-splits options.
splits.setup(opts)
require('ghostty-smart-splits').setup()
-- Keep your existing smart-splits mappings.
```

Load the plugin at startup while this Neovim's Ghostty pane has focus. The bridge
captures that terminal's ID once and uses it for later actions, including cleanup.
Delayed/background setup can capture the wrong terminal.

### smart-splits v3 (experimental)

The same plugin also implements the evolving [v3 backend protocol](https://github.com/mrjones2014/smart-splits.nvim/blob/v3/PROTOCOL.md).
Its v3 module follows the `smart-splits-backend-ghostty` naming convention;
both integrations ship in this repository.
Use the upstream `v3` branch and select the backend explicitly:

```lua
{
  'mrjones2014/smart-splits.nvim',
  branch = 'v3',
  lazy = false,
  dependencies = { 'geodimm/ghostty-smart-splits.nvim' },
  opts = {
    mux = { backend = 'smart-splits-backend-ghostty' },
    move = { at_edge = 'stop' },
  },
}
```

Keep your smart-splits mappings and the Ghostty configuration below. Core calls
the backend's `activate()` during setup, so start with Neovim's Ghostty pane
focused. For v3, omit the v2 `require('ghostty-smart-splits').setup()` call.
The backend leaves your smart-splits options unchanged.

For a custom key table, configure the backend before smart-splits setup:

```lua
require('smart-splits-backend-ghostty').setup({ key_table = 'editor' })
require('smart-splits').setup({
  mux = { backend = 'smart-splits-backend-ghostty' },
  move = { at_edge = 'stop' },
})
```

With lazy.nvim, the equivalent dependency is
`{ 'geodimm/ghostty-smart-splits.nvim', main = 'smart-splits-backend-ghostty', opts = { key_table = 'editor' } }`.
Backend `setup()` only stores configuration; it never runs AppleScript or
registers autocommands. Only the backend selected by core activates.

Movement, resizing, and splitting share the v2 AppleScript transport. Resize
amounts use the existing conversion: ten Ghostty units per Neovim cell, with a
minimum of ten. Ghostty pane wrapping and zoom detection are not implemented.
If a move fails, core applies `move.at_edge`, including wrapping inside Neovim
or attempting a Ghostty split and then a Neovim split if that fails.

This targets the prototype on `v3`, tested at upstream commit `656cc50c07ba`.
The protocol may change before release. Run `:checkhealth smart-splits` for
backend diagnostics, or `:checkhealth ghostty-smart-splits` for prerequisites.

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

Ghostty's [`text:` action](https://ghostty.org/docs/config/reference#keybind)
uses Zig string literal syntax. For another Ctrl key, find its hexadecimal value
in the [complete C0 control-character table](https://terminfo.dev/fundamentals/control-characters)
and write it as `text:\xNN`; Ctrl+a through Ctrl+z map to `01` through `1a`.

A copy is in [examples/ghostty.conf](examples/ghostty.conf). On first use, allow
macOS to automate Ghostty when prompted. If access was denied, review System
Settings → Privacy & Security → Automation.

The navigation keys configured in Neovim must match both sets of Ghostty
bindings. The example uses Ctrl+h/j/k/l.

The table is pushed on startup/resume and popped on suspend/exit. This keeps
Neovim's keys local to its Ghostty terminal; it does not reconfigure other panes.

## Configuration

Defaults:

```lua
require('ghostty-smart-splits').setup({
  key_table = 'nvim',
})
```

Configure movement mappings through smart-splits. If you change the movement
keys or table name, update the Ghostty configuration to match. `claim_keys()` and
`release_keys()` can manually acquire or release the table. Repeated claims and
releases do not push or pop additional tables.

The bridge preserves your existing smart-splits configuration and applies
`multiplexer_integration = 'ghostty'` and `at_edge = 'stop'` on v2.

The preferred module name is `ghostty-smart-splits`. Existing
`require('ghostty_smart_splits')` calls and the underscore `health` module
remain supported but emit a deprecation warning once per module. Update imports
and `:checkhealth` commands to use dashes. The underscore aliases are scheduled
for removal when smart-splits v3 becomes the main release.
Both spellings return the same module instances, so
mixing them does not duplicate terminal attachment or key-table claims.

## How it works

Ghostty’s `performable` bindings let Neovim handle the configured navigation
keys first. smart-splits moves to a neighboring Neovim window when one exists.
At the editor’s edge, this plugin calls Ghostty’s AppleScript API to move to
the adjacent pane.

The plugin captures the focused Ghostty terminal when setup runs, activates a
temporary key table while Neovim is active, and releases it when Neovim is
suspended or exits. Unsupported platforms and terminals are left unchanged.

`ghostty-smart-splits.ghostty` implements the Ghostty operations, and
`ghostty-smart-splits.session` manages the key-table lifecycle. The v2
`smart-splits.mux.ghostty` adapter and v3 `smart-splits-backend-ghostty` module
use those shared building blocks independently.

The file `lua/smart-splits/mux/ghostty.lua` is the v2 discovery entry point:
setting `multiplexer_integration = 'ghostty'` makes smart-splits require
`smart-splits.mux.ghostty`. Neovim finds that module in this plugin through its
runtime path. Loading the adapter does not attach to a Ghostty terminal or
activate the key table, so v2 still needs `require('ghostty-smart-splits').setup()`.
V3 instead loads `smart-splits-backend-ghostty` and calls its `activate()` hook;
the root `ghostty-smart-splits.setup()` call is unnecessary for v3.

## Limitations

- macOS only. There is no Linux/D-Bus implementation in this plugin.
- AppleScript calls are synchronous; crossing an editor edge may have noticeable
  latency. Calls time out after one second and report failure. Moving between
  ordinary Neovim splits does not launch a subprocess. If the initial Automation
  prompt times out, allow access and restart Neovim with its pane focused.
- Initial terminal association depends on focus, not a process-to-surface lookup.
  Later actions use the captured ID and do not silently retarget after focus changes.
- Do not stack another Ghostty key table above this one while Neovim is active.
  Cleanup pops the top table; Ghostty's pop action cannot remove a table by name.
  A crash cannot clean up. An optional recovery binding is
  `keybind = ctrl+shift+escape=deactivate_all_key_tables`; it clears **all** tables.
  Reloading Ghostty's config during a session can also invalidate table state.

Native `performable:goto_split` bindings are enough if you prefer Ghostty panes
to take priority. This plugin is for the opposite order: Neovim first.

## Troubleshooting and development

Run `:checkhealth ghostty-smart-splits` for local prerequisites. The health check
does not send Apple Events or verify Automation permissions.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks and a manual smoke test, and
`:help ghostty-smart-splits` for the API.

MIT licensed.
