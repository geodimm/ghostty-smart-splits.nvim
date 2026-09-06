-- Local benchmark utilities, inspired by smart-splits-backend-zellij/tests/bench.
local M = {}

---@param timings number[] Milliseconds, in measurement order.
function M.summarize(timings)
  assert(#timings > 0, 'at least one measurement is required')
  local sorted = vim.deepcopy(timings)
  table.sort(sorted)
  local count, sum = #sorted, 0
  for _, value in ipairs(sorted) do
    sum = sum + value
  end
  return {
    count = count,
    avg = sum / count,
    median = (sorted[math.floor((count + 1) / 2)] + sorted[math.ceil((count + 1) / 2)]) / 2,
    min = sorted[1],
    max = sorted[count],
    p95 = sorted[math.ceil(count * 0.95)],
    samples_ms = timings,
  }
end

---@param cases {name: string, run: fun(i: integer)}[]
---@param opts {iterations: integer, warmup: integer}
function M.compare(cases, opts)
  -- Pairs must finish before changing transports, so every case starts on the left.
  assert(opts.iterations > 0 and opts.iterations % 2 == 0, 'iterations must be a positive even integer')
  assert(opts.warmup >= 2 and opts.warmup % 2 == 0, 'warmup must be a positive even integer')
  local timings = {}
  for _, case in ipairs(cases) do
    timings[case.name] = {}
    for i = 1, opts.warmup do
      case.run(i)
    end
  end
  for pair = 1, opts.iterations / 2 do
    -- Reverse the case order after every pair to reduce order/time bias.
    for slot = 1, #cases do
      local index = pair % 2 == 1 and slot or (#cases - slot + 1)
      local case = cases[index]
      for i = pair * 2 - 1, pair * 2 do
        local start = vim.uv.hrtime()
        case.run(i)
        table.insert(timings[case.name], (vim.uv.hrtime() - start) / 1e6)
      end
    end
  end
  local results = {}
  for _, case in ipairs(cases) do
    results[case.name] = M.summarize(timings[case.name])
  end
  return results
end

function M.print_result(name, result)
  print(
    ('%-12s avg: %8.2f ms  median: %8.2f ms  min: %8.2f ms  max: %8.2f ms  p95: %8.2f ms'):format(
      name,
      result.avg,
      result.median,
      result.min,
      result.max,
      result.p95
    )
  )
end

return M
