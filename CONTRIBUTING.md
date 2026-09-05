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
`make format-check`, `make lint`, `make typecheck`, and `make test`. Run
`make test-unit` or `make test-integration` when working on one layer.

Tests use [mini.test](https://github.com/nvim-mini/mini.test) and
[smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim). The first
`make test` downloads both into the ignored `deps/` directory. They are
development-only dependencies.

Unit tests cover the Ghostty multiplexer adapter with mocked Neovim APIs.
Integration tests use real Neovim windows and a mocked AppleScript subprocess.
They do not move Ghostty panes or require macOS.

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
