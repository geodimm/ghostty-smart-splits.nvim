# ghostty-smart-splits.nvim

Navigate between Neovim splits and Ghostty panes on macOS with the same keys.
smart-splits handles Neovim windows first; at an editor edge, the matching
Ghostty binding handles the pane.

A macOS bridge for [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim).

Supports smart-splits v2 and the experimental v3 backend.

https://github.com/user-attachments/assets/774b72c1-acd5-48fa-9b03-406f2cc740ab

## Requirements

- Neovim 0.11+, smart-splits.nvim, and Ghostty 1.3+ on macOS.
- Neovim running locally inside Ghostty.
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

The v2 setup uses the `nvim` Ghostty key table by default and preserves your
smart-splits options. To use another table:

```lua
require('ghostty-smart-splits').setup({ key_table = 'editor' })
```

Configure movement and resize mappings through smart-splits. The v2 setup adds
`multiplexer_integration = 'ghostty'` and `at_edge = 'stop'`.

The preferred module and health names use dashes:
`ghostty-smart-splits` and `:checkhealth ghostty-smart-splits`. The old
underscore names remain as deprecated aliases for now.

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

- macOS only. AppleScript calls are synchronous and time out after one second.
- The initial Ghostty terminal comes from the focused pane; later actions keep
  using that terminal instead of following focus changes.
- Do not stack another Ghostty key table above this one while Neovim is active.
  If a crash or config reload leaves stale state, Ghostty's
  `deactivate_all_key_tables` action can recover it, but clears every table.
