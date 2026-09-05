MINITEST_DIR ?= deps/mini.test
SMART_SPLITS_DIR ?= deps/smart-splits.nvim

.PHONY: check format format-check lint typecheck test test-unit test-integration

define LOAD_LUAJIT_ROCKS
if command -v brew >/dev/null 2>&1 && command -v luarocks >/dev/null 2>&1; then \
  LUAJIT_PREFIX="$$(brew --prefix luajit 2>/dev/null || true)"; \
  if [ -n "$$LUAJIT_PREFIX" ]; then \
    eval "$$(luarocks --lua-version=5.1 --lua-dir="$$LUAJIT_PREFIX" --local path)"; \
  fi; \
fi;
endef

check: format-check lint typecheck test

format:
	stylua lua tests

format-check:
	stylua --check lua tests

lint:
	@$(LOAD_LUAJIT_ROCKS) \
	luacheck lua tests

typecheck:
	@$(LOAD_LUAJIT_ROCKS) \
	VIMRUNTIME="$$(NVIM_LOG_FILE=/tmp/ghostty-smart-splits-typecheck.log nvim --clean -i NONE --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'quitall')" \
	lua-language-server --check=. --checklevel=Warning --check_format=pretty --configpath=.luarc.json --logpath=.tmp/luals

test: test-unit test-integration

test-unit test-integration: $(MINITEST_DIR) $(SMART_SPLITS_DIR)
	MINITEST_DIR="$(abspath $(MINITEST_DIR))" SMART_SPLITS_DIR="$(abspath $(SMART_SPLITS_DIR))" XDG_STATE_HOME=/tmp/ghostty-smart-splits.nvim NVIM_LOG_FILE=/tmp/ghostty-smart-splits-nvim.log nvim --headless -i NONE -u tests/minimal_init.lua -l tests/run.lua $(@:test-%=%)

$(MINITEST_DIR):
	mkdir -p "$(dir $(MINITEST_DIR))"
	git clone --filter=blob:none --branch stable https://github.com/nvim-mini/mini.test "$@"

$(SMART_SPLITS_DIR):
	mkdir -p "$(dir $(SMART_SPLITS_DIR))"
	git clone --filter=blob:none https://github.com/mrjones2014/smart-splits.nvim "$@"
