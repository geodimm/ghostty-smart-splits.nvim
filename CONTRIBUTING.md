# Development

The local toolchain is Neovim 0.11 or newer, StyLua, LuaLS, Make, and a Lua 5.1
rocks tree holding Luacheck, busted and nlua. The LuaRocks package versions
match CI.

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

Run the CI checks with `make check`. Individual targets are `make format`,
`make format-check`, `make lint`, `make typecheck`, and `make test`.

| Command | What it verifies |
| --- | --- |
| `make test` (also `make test-core`) | 25 focused configuration, import, health, and failure-path tests in real Neovim. No Ghostty or upstream checkout is needed. |
| `make test-e2e` | Four visible Neovim sessions in real Ghostty: v2/v3 × osascript/bridge. Local macOS only. |

The fast suite uses busted through nlua. Configuration tests use no mocks;
import tests stub the warning function. Transport doubles are reserved for
failure paths and checks such as unavailable executables, denied Apple Events,
missing replies, reentrant requests, and attachment races.

Each case prints its name, file, line and duration. Pass other busted flags
through `BUSTED_ARGS`, for example `make test BUSTED_ARGS="-o TAP"`,
`make test BUSTED_ARGS=--filter=bridge`, or `make test BUSTED_ARGS=-l`.
Run one spec with `busted --run=core tests/core/bridge_spec.lua`.

### Local end-to-end tests

Requires macOS with an active graphical login, Ghostty 1.3+ installed as
`/Applications/Ghostty.app`, Neovim 0.11+, and Xcode Command Line Tools to build
the optional bridge. Busted, nlua, and a personal Neovim config are not needed.

1. From any terminal, including your existing Ghostty, run this at the repository root:

   ```sh
   make test-e2e
   ```

2. Allow macOS Automation access to Ghostty if prompted. If a first-run prompt
   outlasts the test timeout, allow it and run the command again.
3. Leave the test windows alone until the run finishes. The harness closes its
   own Ghostty instance on success or failure and exits nonzero on failure.

If you interrupt the coordinator, close only its test windows before rerunning.

The target builds the bridge and downloads the upstream smart-splits v2/v3
checkouts into the ignored `deps/` directory when missing. Override
`SMART_SPLITS_DIR` and `SMART_SPLITS_V3_DIR` to use existing checkouts;
`SMART_SPLITS_V3_REF` selects the ref for a new v3 checkout.

The harness launches a separate Ghostty process with `--config-default-files=false`
and `--config-file=tests/e2e/ghostty.conf`. Your existing Ghostty can stay open.
Harness operations and cleanup address only the process it launched; the plugin
finds the Ghostty ancestor of its own process and addresses that PID. Neither
uses the application name to choose between instances. Your Ghostty config is
not read or edited.

Each case starts a fresh visible Neovim with `tests/e2e/init.lua`, the real
upstream smart-splits, and this plugin. There are no transport mocks or
synthetic lifecycle autocommands in these tests.

The four sessions check movement within Neovim, movement into an adjacent
Ghostty shell and back, editor and terminal resizing, real Ctrl-Z/`fg`
suspend/resume, and shell navigation after Neovim exits. Keys enter through
Ghostty's AppleScript `send key` API. Neovim RPC prepares layouts, queues the
quit command, and reads window state; it does not perform the navigation or
resize actions. A harmless F12 mapping observes key-table activation before
sending the test keys. Failures print the Ghostty focus and Neovim state and
messages when available.

Transport checks inspect the real bridge child process and record Neovim's
osascript launches with a forwarding executable that runs the installed binary
with the original arguments. Bridge sessions must launch osascript exactly once,
for initial attachment; any fallback during activation, navigation, resizing,
suspend/resume, or exit fails the test. The coordinator's automation calls are
outside that recording path.

Ghostty 1.3.x's scripted letter keys lack the Unicode codepoint used by normal
letter bindings. The test config uses documented physical names (`key_h`,
`key_l`, etc.) to exercise the same actions and key tables on these versions.
This tests Ghostty's key-processing path but does not synthesize physical OS
keyboard events or verify keyboard-layout translation. See the
[upstream input fix](https://github.com/ghostty-org/ghostty/pull/13205).

E2E is deliberately separate from `make check` and CI. It requires a graphical
session and Automation permission; unattended GitHub-hosted execution has not
been validated. Run it locally before submitting navigation or lifecycle changes.

## Ghostty automation

With Ghostty installed on macOS, syntax-check the scripts without running them:

```sh
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
osacompile -l JavaScript -o "$check_dir/ghostty.scpt" scripts/ghostty.js
osacompile -l JavaScript -o "$check_dir/e2e.scpt" tests/ghostty.js
```

## Bridge

Build `bin/ghostty-smart-splits-bridge` with `make bridge` on macOS with
Xcode Command Line Tools installed. Make rebuilds when the binary is missing
or the Swift source or Makefile is newer. Use `make -B bridge` after a
toolchain change.

`bridge/main.swift` uses OSAKit to execute the shared `scripts/ghostty.js`
JavaScript for Automation handlers against Ghostty's scripting API. The Lua
client in `lua/ghostty-smart-splits/bridge.lua` manages the process and JSON protocol.
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

The E2E suite covers the isolated workflows above. Use these manual checks for
your personal config, sidebars, terminal buffers, alternate keyboard layouts,
and granting or denying Automation permission.

## CI

To exercise the pull-request workflow locally, start Docker and install
[`act`](https://github.com/nektos/act):

```sh
brew install act
act pull_request -W .github/workflows/ci.yaml -s GITHUB_TOKEN="$(gh auth token)"
```

CI runs the fast suite on Linux and macOS with Neovim 0.11, stable, and nightly,
plus formatting, lint, and type checks. The macOS jobs also build the bridge and
syntax-check the automation scripts. Live Ghostty E2E tests are local only.

CI uses standard Lua 5.1.5 to run LuaRocks. Running the installer under LuaJIT
can fail with `main function has more than 65536 constants` while parsing the
public package manifest; this is not a missing Busted release. The installed
Lua 5.1 modules are still loaded by Neovim's LuaJIT when nlua runs the tests.
Homebrew's LuaRocks already uses a separate standard Lua interpreter; its
`--lua-version=5.1 --lua-dir=...` flags select the modules' target runtime.

Use Conventional Commit prefixes for releasable changes. `fix:` produces a
patch release, `feat:` a minor release, and a `!` or `BREAKING CHANGE` footer a
major release. After CI passes on `main`, Release Please opens or updates a
release PR; merging it creates the SemVer tag and GitHub release.
