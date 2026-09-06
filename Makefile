MINITEST_DIR ?= deps/mini.test
SMART_SPLITS_DIR ?= deps/smart-splits.nvim
SMART_SPLITS_V3_DIR ?= deps/smart-splits-v3.nvim
SMART_SPLITS_V3_REF ?= 23963901e8756cd5cf38b27f3d8bdf2fba7fc34f
BENCH_ARGS ?=
NVIM_LOG_FILE ?= /tmp/ghostty-smart-splits-nvim.log
export NVIM_LOG_FILE

.PHONY: check format format-check lint typecheck test test-core test-v2 test-v3 bench bridge

define LOAD_LUAJIT_ROCKS
if command -v brew >/dev/null 2>&1 && command -v luarocks >/dev/null 2>&1; then \
  LUAJIT_PREFIX="$$(brew --prefix luajit 2>/dev/null || true)"; \
  if [ -n "$$LUAJIT_PREFIX" ]; then \
    eval "$$(luarocks --lua-version=5.1 --lua-dir="$$LUAJIT_PREFIX" --local path)"; \
  fi; \
fi;
endef

check: format-check lint typecheck test

# Local only: moves real Ghostty panes. Deliberately excluded from check/CI.
bench:
	nvim --headless -u NONE -i NONE -l tests/bench/run.lua $(BENCH_ARGS)

bridge: bin/ghostty-smart-splits-bridge

bin/ghostty-smart-splits-bridge: bridge/main.swift Makefile
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "Skipping Ghostty bridge build: macOS is required"; \
	elif ! command -v swiftc >/dev/null 2>&1; then \
		echo "Skipping Ghostty bridge build: swiftc is unavailable"; \
	else \
		mkdir -p bin; \
		swiftc -O -framework Foundation -framework Carbon -o "$@" bridge/main.swift; \
	fi

format:
	stylua lua tests

format-check:
	stylua --check lua tests

lint:
	@$(LOAD_LUAJIT_ROCKS) \
	luacheck lua tests

typecheck:
	@$(LOAD_LUAJIT_ROCKS) \
	VIMRUNTIME="$$(nvim --clean -i NONE --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'quitall')" \
	lua-language-server --check=. --checklevel=Warning --check_format=pretty --configpath=.luarc.json --logpath=.tmp/luals

test: test-core test-v2 test-v3

test-core: $(MINITEST_DIR)
	MINITEST_DIR="$(abspath $(MINITEST_DIR))" SMART_SPLITS_DIR= XDG_STATE_HOME=/tmp/ghostty-smart-splits.nvim nvim --headless -i NONE -u tests/minimal_init.lua -l tests/run.lua core

test-v3: $(MINITEST_DIR) $(SMART_SPLITS_V3_DIR)
	MINITEST_DIR="$(abspath $(MINITEST_DIR))" SMART_SPLITS_DIR="$(abspath $(SMART_SPLITS_V3_DIR))" XDG_STATE_HOME=/tmp/ghostty-smart-splits.nvim nvim --headless -i NONE -u tests/minimal_init.lua -l tests/run.lua v3

test-v2: $(MINITEST_DIR) $(SMART_SPLITS_DIR)
	MINITEST_DIR="$(abspath $(MINITEST_DIR))" SMART_SPLITS_DIR="$(abspath $(SMART_SPLITS_DIR))" XDG_STATE_HOME=/tmp/ghostty-smart-splits.nvim nvim --headless -i NONE -u tests/minimal_init.lua -l tests/run.lua v2

$(MINITEST_DIR):
	mkdir -p "$(dir $(MINITEST_DIR))"
	git clone --filter=blob:none --branch stable https://github.com/nvim-mini/mini.test "$@"

$(SMART_SPLITS_DIR):
	mkdir -p "$(dir $(SMART_SPLITS_DIR))"
	git clone --filter=blob:none https://github.com/mrjones2014/smart-splits.nvim "$@"

$(SMART_SPLITS_V3_DIR):
	mkdir -p "$(dir $(SMART_SPLITS_V3_DIR))"
	git clone --filter=blob:none --no-checkout https://github.com/mrjones2014/smart-splits.nvim "$@"
	git -C "$@" checkout --quiet "$(SMART_SPLITS_V3_REF)"
