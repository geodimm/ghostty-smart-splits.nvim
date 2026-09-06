local suite = arg[1]
local descriptions = {
  core = 'shared Ghostty transport, session lifecycle, and health (no upstream smart-splits)',
  v2 = 'v2 setup and mux integration with upstream smart-splits v2',
  v3 = 'v3 backend protocol and integration with upstream smart-splits v3',
}
assert(descriptions[suite], 'choose core, v2, or v3; use make test to run all suites in separate processes')
print(('Test suite: %s — %s'):format(suite, descriptions[suite]))
local files = vim.fn.globpath('tests/' .. suite, '**/test_*.lua', true, true)
table.sort(files)
assert(#files > 0, 'no test files found for ' .. suite)
require('mini.test').run({ collect = {
  find_files = function()
    return files
  end,
} })
