# ghostty-smart-splits.nvim

Navigate between Neovim splits and Ghostty panes on macOS with the same keys.
smart-splits handles Neovim windows first; at an editor edge, the matching
Ghostty binding handles the pane.

A macOS bridge for [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim).

Supports smart-splits v2 and the experimental v3 backend.

https://github.com/user-attachments/assets/774b72c1-acd5-48fa-9b03-406f2cc740ab

## Requirements

- Neovim 0.11+, smart-splits.nvim, and Ghostty 1.3+ on macOS.
- Ghostty AppleScript enabled (the default) and macOS Automation permission.

## Installation

### smart-splits v2

With lazy.nvim:

```lua
{
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  dependencies = { 'geodimm/ghostty-smart-splits.nvim' },
  config = function()
    require('smart-splits').setup({}) -- Your existing options and mappings.
    require('ghostty-smart-splits').setup()
  end,
}
```

With `vim.pack` (Neovim 0.12+):

```lua
vim.pack.add({
  'https://github.com/mrjones2014/smart-splits.nvim',
  'https://github.com/geodimm/ghostty-smart-splits.nvim',
})

require('smart-splits').setup({}) -- Your existing options and mappings.
require('ghostty-smart-splits').setup()
```

### smart-splits v3 (experimental)

Use smart-splits' `v3` branch. The protocol and backend may change before
release.

With lazy.nvim:

```lua
{
  'mrjones2014/smart-splits.nvim',
  branch = 'v3',
  lazy = false,
  dependencies = {
    {
      'geodimm/ghostty-smart-splits.nvim',
      main = 'smart-splits-backend-ghostty',
    },
  },
  opts = {
    mux = {
      backend = 'smart-splits-backend-ghostty',
    },
    move = {
      at_edge = 'stop',
    },
  },
}
```

With `vim.pack` (Neovim 0.12+):

```lua
vim.pack.add({
  {
    src = 'https://github.com/mrjones2014/smart-splits.nvim',
    version = 'v3',
  },
  'https://github.com/geodimm/ghostty-smart-splits.nvim',
})

require('smart-splits').setup({
  mux = {
    backend = 'smart-splits-backend-ghostty',
  },
  move = {
    at_edge = 'stop',
  },
})
```

Do not call the v2 `ghostty-smart-splits` setup when using v3.

## Ghostty configuration

Copy this to your Ghostty config, reload it, then start Neovim in the target
pane.

```ini
# Outside Neovim.
# Move
keybind = performable:ctrl+h=goto_split:left
keybind = performable:ctrl+j=goto_split:down
keybind = performable:ctrl+k=goto_split:up
keybind = performable:ctrl+l=goto_split:right

# Resize
keybind = performable:alt+h=resize_split:left,30
keybind = performable:alt+j=resize_split:down,30
keybind = performable:alt+k=resize_split:up,30
keybind = performable:alt+l=resize_split:right,30

# Inside Neovim.
keybind = nvim/
# Move
keybind = nvim/ctrl+h=text:\x08
keybind = nvim/ctrl+j=text:\x0a
keybind = nvim/ctrl+k=text:\x0b
keybind = nvim/ctrl+l=text:\x0c

# Resize
keybind = nvim/alt+h=esc:h
keybind = nvim/alt+j=esc:j
keybind = nvim/alt+k=esc:k
keybind = nvim/alt+l=esc:l
```

The keys in Neovim and Ghostty must match.

## Configuration

Both integrations accept the same backend options:

| Option | Default | Behavior |
| --- | --- | --- |
| `key_table` | `'nvim'` | Ghostty key table used while Neovim is active. |
| `bridge` | `false` | Use a persistent bridge for actions and pane lookups; fall back to `osascript` when unavailable. Set `false` to use only `osascript`. |
| `slow_threshold` | `100` with the bridge, `150` without | Milliseconds before smart-splits v3 logs a slow-operation warning. Must be a positive integer. Follows `bridge` until you set it. |

With v2, pass them to the plugin setup:

```lua
require('ghostty-smart-splits').setup({
  key_table = 'nvim',
  bridge = false, -- If navigation feels slow, build the bridge and set true.
})
```

With v3, configure the backend **before** smart-splits selects and activates it:

```lua
require('smart-splits-backend-ghostty').setup({
  key_table = 'nvim',
  bridge = false, -- If navigation feels slow, build the bridge and set true.
  -- slow_threshold = 200,
})
require('smart-splits').setup({
  mux = { backend = 'smart-splits-backend-ghostty' },
  move = { at_edge = 'stop' },
})
```

`setup` merges over the current options: a call that names one option leaves
the rest alone, so the bridge can be toggled at runtime without repeating
`key_table`. An unknown option name is an error rather than a silent no-op.
Call `require('ghostty-smart-splits.config').reset()` to restore every default.

Changing `key_table` to a different name while it is claimed is an error;
release it first. Disabling the bridge stops an existing bridge immediately;
enabling it starts one on the next attachment or action.

Configure movement and resize mappings through smart-splits. The v2 setup adds
`multiplexer_integration = 'ghostty'` and `at_edge = 'stop'`.

The preferred module and health names use dashes:
`ghostty-smart-splits` and `:checkhealth ghostty-smart-splits`. The old
underscore names remain as deprecated aliases for now.

In local measurements, bridge actions took about 30 ms versus about 130 ms
through per-call `osascript`; results vary by machine.
The v3 warning threshold is therefore raised to 150 ms when the bridge is off.
If your machine is slower and you are comfortable with the latency, increase
`slow_threshold` to suppress expected warnings.

### Optional bridge

The bridge is a persistent Swift process that reuses compiled AppleScript to reduce the overhead of talking to Ghostty.
Every request goes through it, including the pane lookups smart-splits v2 makes before and after each move.

If navigation feels slow, try enabling the bridge. With Xcode Command Line Tools installed,
run this from the plugin directory, then set `bridge = true`:

```sh
make bridge
```

To rebuild on install/update with lazy.nvim, use this dependency spec:

```lua
{ 'geodimm/ghostty-smart-splits.nvim', build = 'make bridge' }
```

With vim.pack, register this hook before `vim.pack.add()`:

```lua
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local d = ev.data
    if d.spec.name == 'ghostty-smart-splits.nvim'
      and (d.kind == 'install' or d.kind == 'update') then
      local r = vim.system({ 'make', 'bridge' }, { cwd = d.path, text = true }):wait()
      assert(r.code == 0, r.stderr or 'bridge build failed')
    end
  end,
})
```

Run `make bench` to benchmark locally.

## How it works

Ghostty's `performable` bindings give Neovim first chance at each key. This
plugin uses Ghostty's AppleScript API when smart-splits reaches an editor edge,
and keeps a temporary key table active while Neovim is running.

## API

```lua
require('ghostty-smart-splits').claim_keys()
require('ghostty-smart-splits').release_keys()
```

Keys are claimed and released automatically on Neovim suspend, resume, and
exit. Use the functions above only when managing the table manually.

Run `:checkhealth ghostty-smart-splits` for local prerequisites. With v3,
`:checkhealth smart-splits` also includes backend diagnostics.

## Limitations

- macOS only. Action AppleScript calls are synchronous and time out after one second
- The initial Ghostty terminal comes from the focused pane and the lookup is asynchronous;
  Later actions keep using that terminal instead of following focus changes.
  A failed lookup is retried when Neovim next regains focus, so answering the
  macOS Automation prompt recovers the session without restarting Neovim. After
  five failures it stops trying and warns once.
- Do not stack another Ghostty key table above this one while Neovim is active.
  If a crash or config reload leaves stale state, Ghostty's
  `deactivate_all_key_tables` action can recover it, but clears every table.
