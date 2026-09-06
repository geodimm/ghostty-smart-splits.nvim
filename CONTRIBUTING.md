# Development

The local toolchain is Neovim 0.11 or newer, StyLua, LuaLS, Luacheck, and Make.
On macOS:

```sh
brew install neovim stylua lua-language-server luajit luarocks
LUAJIT_PREFIX="$(brew --prefix luajit)"
luarocks --lua-version=5.1 --lua-dir="$LUAJIT_PREFIX" --local install luacheck 1.2.0-1
eval "$(luarocks --lua-version=5.1 --lua-dir="$LUAJIT_PREFIX" --local path)"
```

The `lint` and `typecheck` Make targets load this LuaRocks environment
automatically when Homebrew and LuaRocks are available. Linux CI skips that
optional setup and uses its installed standalone tools.

Run the complete check with `make check`. Individual targets are `make format`,
`make format-check`, `make lint`, `make typecheck`, and `make test`.

| Command | Test directory | What it verifies |
| --- | --- | --- |
| `make test-core` | `tests/core/` | Shared Ghostty transport, terminal attachment, key-table lifecycle, and health checks; no upstream smart-splits checkout is loaded. |
| `make test-v2` | `tests/v2/` | V2 setup, legacy import warnings, mux discovery, and action forwarding through the real v2 core. |
| `make test-v3` | `tests/v3/` | V3 backend contract, shared state with the v2 entry point, selection, navigation, resizing, and fallback through the real v3 core. |

`make test` and `make check` run all three suites in separate Neovim processes.
Each suite prints its scope and its own case/failure counts. CI exposes them as
three named steps on each platform and Neovim version.

Tests use [mini.test](https://github.com/nvim-mini/mini.test) and
[smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim). The first
`make test` downloads mini.test and separate smart-splits checkouts for master
(v2) and the experimental v3 branch into the ignored `deps/` directory. They
are development-only dependencies. Override `SMART_SPLITS_DIR` or
`SMART_SPLITS_V3_DIR` to test against existing checkouts; `SMART_SPLITS_V3_REF`
selects the branch or tag when downloading a new v3 checkout.

The shared suite needs only mini.test. All suites mock AppleScript and platform
checks; the shared health test also stubs smart-splits availability. The v2 and
v3 `test_smart_splits.lua` files exercise the actual upstream code and real
Neovim windows. No automated suite moves live Ghostty panes or requires macOS.

## AppleScript

With Ghostty installed on macOS, syntax-check the scripts without running them:

```sh
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
osacompile -o "$check_dir/perform-action.scpt" scripts/perform-action.applescript
osacompile -o "$check_dir/focused-terminal-id.scpt" scripts/focused-terminal-id.applescript
```

## Manual smoke test

1. Add the example Ghostty bindings and reload the configuration.
2. Start Neovim in the focused Ghostty pane, with a shell pane to its right.
3. Create two Neovim vertical splits. Ctrl+l should visit the right editor split,
   then the shell. Ctrl+h from the shell should return to Neovim.
4. Repeat vertically, in a terminal buffer, and with your sidebar open.
5. Suspend/resume twice and then exit. Native Ghostty navigation should return
   while suspended and after exit. Other panes' key tables should remain intact.
6. Deny Automation access and confirm a useful warning, not navigation in an
   unrelated terminal.

Repeat with the v2 setup and the v3 backend configuration from README.md.
For v3, also exercise resizing, move.at_edge='split', failed-move wrapping
inside Neovim, and a different backend winning the configured priority list.

Automated tests do not prove live Ghostty behavior, Automation permission
handling, or AppleScript compatibility.

## CI

To exercise the pull-request workflow locally, start Docker and install
[`act`](https://github.com/nektos/act):

```sh
brew install act
act pull_request -W .github/workflows/ci.yaml \
  -s GITHUB_TOKEN="$(gh auth token)"
```

CI runs tests on Linux and macOS with Neovim 0.11, stable, and nightly. It also
checks formatting, lint, and types.

Use Conventional Commit prefixes for releasable changes. `fix:` produces a
patch release, `feat:` a minor release, and a `!` or `BREAKING CHANGE` footer a
major release. After CI passes on `main`, Release Please opens or updates a
release PR; merging it creates the SemVer tag and GitHub release.
