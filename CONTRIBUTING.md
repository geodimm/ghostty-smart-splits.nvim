# Contributing

This project targets macOS and Ghostty. Install the toolchain with Homebrew,
then allow Xcode Command Line Tools to finish installing:

```sh
xcode-select --install
brew install neovim stylua lua-language-server luajit luarocks

LUAJIT_PREFIX="$(brew --prefix luajit)"
ROCKS=(--lua-version=5.1 --lua-dir="$LUAJIT_PREFIX" --local)
luarocks "${ROCKS[@]}" install luacheck 1.2.0-1
luarocks "${ROCKS[@]}" install busted 2.3.0
luarocks "${ROCKS[@]}" install nlua 0.3.2
eval "$(luarocks "${ROCKS[@]}" path --bin)"
```

Run the fast checks from the repository root:

```sh
make check
```

This runs formatting, LuaLS, Luacheck, and 25 focused tests in Neovim. Use
`make format`, `make lint`, `make typecheck`, or `make test` individually.
Pass Busted options with `BUSTED_ARGS`, for example:
`make test BUSTED_ARGS='--filter=bridge'`.

## Real Ghostty tests

These require a logged-in macOS desktop, Ghostty 1.3 or newer at
`/Applications/Ghostty.app`, Neovim 0.11 or newer, and macOS Automation
permission.

```sh
make test-e2e
```

The harness launches a separate Ghostty process with
`tests/e2e/ghostty.conf`, so existing sessions can stay open. It runs real
Neovim and Ghostty through smart-splits v2 and v3, using both osascript and the
persistent bridge. It checks split movement, shell movement, resizing,
`Ctrl-Z`/`fg`, key-table lifecycle, and navigation after Neovim exits.

Bridge sessions verify a real bridge child process and reject any osascript
fallback after initial attachment. The upstream v2/v3 checkouts are downloaded
to ignored `deps/` when needed; override them with `SMART_SPLITS_DIR` and
`SMART_SPLITS_V3_DIR`.

E2E is local-only because it needs a graphical session and Automation
permission. It is excluded from `make check` and CI.

## Benchmark

`make bench` builds the bridge and launches its own Ghostty instance and window.
Existing sessions can stay open. It measures real osascript and bridge
round-trips in two temporary panes, prints latency statistics, and closes the
test instance.

```sh
make bench
make bench BENCH_ARGS='--pairs 30 --warmup 4 --json /tmp/ghostty-bench.json'
```

Leave the benchmark window alone until it finishes. A forced interruption may
leave that disposable window open.

## Automation and bridge

The osascript transport and Swift bridge share [`scripts/ghostty.js`](scripts/ghostty.js)
and address the Ghostty process owning the current Neovim instance. Build the
bridge with `make bridge`; syntax-check the scripts with:

```sh
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
osacompile -l JavaScript -o "$tmpdir/ghostty.scpt" scripts/ghostty.js
osacompile -l JavaScript -o "$tmpdir/tests.scpt" tests/ghostty.js
```

Use Conventional Commit prefixes such as `fix:` and `feat:`. Changes to
navigation, lifecycle handling, or the bridge should
include `make test-e2e` results when possible.
