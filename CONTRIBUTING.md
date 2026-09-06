# Development

The local toolchain is Neovim 0.11 or newer, StyLua, LuaLS, Make, and a Lua 5.1
rocks tree holding Luacheck, busted and nlua. Everything is pinned to the
versions CI uses.

On macOS, copy and paste the whole block:

```sh
brew install neovim stylua lua-language-server luajit luarocks
LUAJIT_PREFIX="$(brew --prefix luajit)"
ROCKS=(--lua-version=5.1 --lua-dir="$LUAJIT_PREFIX" --local)
luarocks "${ROCKS[@]}" install luacheck 1.2.0-1
luarocks "${ROCKS[@]}" install busted 2.3.0
luarocks "${ROCKS[@]}" install nlua 0.3.2
eval "$(luarocks "${ROCKS[@]}" path --bin)"
```

Elsewhere, install Neovim, StyLua, LuaLS and LuaRocks from your package manager
or their releases, plus a Lua 5.1 install for LuaRocks to build against. On
Debian and Ubuntu that is:

```sh
sudo apt install make luarocks lua5.1 liblua5.1-0-dev
ROCKS=(--lua-version=5.1 --lua-dir=/usr --local)
luarocks "${ROCKS[@]}" install luacheck 1.2.0-1
luarocks "${ROCKS[@]}" install busted 2.3.0
luarocks "${ROCKS[@]}" install nlua 0.3.2
eval "$(luarocks "${ROCKS[@]}" path --bin)"
```

Run the complete check with `make check`. Individual targets are `make format`,
`make format-check`, `make lint`, `make typecheck`, and `make test`.

| Command | Test directory | What it verifies |
| --- | --- | --- |
| `make test-core` | `tests/core/` | Shared Ghostty transport, terminal attachment, key-table lifecycle, and health checks; no upstream smart-splits checkout is loaded. |
| `make test-v2` | `tests/v2/` | V2 setup, legacy import warnings, mux discovery, and action forwarding through the real v2 core. |
| `make test-v3` | `tests/v3/` | V3 backend contract, shared state with the v2 entry point, selection, navigation, resizing, and fallback through the real v3 core. |

`make test` and `make check` run all three suites in separate busted processes,
because each needs a different smart-splits checkout on the runtimepath.

Each case is named as it runs, with its file, line and duration. Pass other
busted flags through `BUSTED_ARGS`, for example `make test BUSTED_ARGS="-o TAP"`
for one line per case, `-o plainTerminal` for dots, or `-l` to list case names
without running them.

Run a single suite with `make test-core`, or one spec with
`busted --run=core tests/core/bridge_spec.lua`, and filter cases with
`make test-core BUSTED_ARGS=--filter=bridge`.

The upstream [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim)
checkouts for master (v2) and the experimental v3 branch are downloaded into the
ignored `deps/` directory on first run, as development-only dependencies.
Override `SMART_SPLITS_DIR` or `SMART_SPLITS_V3_DIR` to test against existing
checkouts; `SMART_SPLITS_V3_REF` selects the branch or tag when downloading a
new v3 checkout.

The shared suite needs no upstream checkout. All suites mock AppleScript and
platform checks; the shared health spec also stubs smart-splits availability.
The v2 and v3 `smart_splits_spec.lua` files exercise the actual upstream code
and real Neovim windows. No automated suite moves live Ghostty panes or
requires macOS.

## AppleScript

With Ghostty installed on macOS, syntax-check the scripts without running them:

```sh
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
osacompile -o "$check_dir/perform-action.scpt" scripts/perform-action.applescript
osacompile -o "$check_dir/focused-terminal-id.scpt" scripts/focused-terminal-id.applescript
```

## Bridge

Build `bin/ghostty-smart-splits-bridge` with `make bridge` on macOS with
Xcode Command Line Tools installed. Make rebuilds when the binary is missing
or the Swift source or Makefile is newer. Use `make -B bridge` after a
toolchain change.

`bridge/main.swift` executes AppleScript requests. The Lua client in
`lua/ghostty-smart-splits/bridge.lua` manages the process and JSON protocol.
Each Neovim instance owns one bridge and stops it on exit. The initial terminal
lookup uses `osascript`.

## Manual smoke test

### Local latency benchmark

Run from a shell in Ghostty at the repository root:

```sh
make bridge
make bench
```

The benchmark creates a temporary right pane, alternates right/left actions,
then closes that pane and restores focus. Avoid interacting with Ghostty
during the run. Cleanup also runs on benchmark errors; a forced interruption
or a setup/cleanup failure may leave the temporary pane open.

By default, it measures 20 actions per transport after four warmup actions
each. Output includes average, median, p95, range, speedup, and latency
reduction. Failed responses abort the run with a nonzero exit status.

Timings cover request/response round trips, including per-call `osascript`
startup. Bridge startup and pane setup/cleanup are excluded. The benchmark
runs in headless Neovim and does not measure keypress or rendering latency.

For more samples or shareable results:

```sh
make bench BENCH_ARGS='--pairs 30 --json /tmp/ghostty-bench.json'
```

JSON includes raw timings and environment metadata. Use `--pairs` to set the
measured pairs and `--warmup` to set warmup pairs per transport. Run on a quiet
system. The benchmark requires a live Ghostty session and is excluded from
`make check` and CI.

### Navigation and lifecycle

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
act pull_request -W .github/workflows/ci.yaml -s GITHUB_TOKEN="$(gh auth token)"
```

CI runs tests on Linux and macOS with Neovim 0.11, stable, and nightly. It also
checks formatting, lint, and types.

Use Conventional Commit prefixes for releasable changes. `fix:` produces a
patch release, `feat:` a minor release, and a `!` or `BREAKING CHANGE` footer a
major release. After CI passes on `main`, Release Please opens or updates a
release PR; merging it creates the SemVer tag and GitHub release.
