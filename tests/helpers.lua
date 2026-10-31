local M = { count = 0 }

function M.test(name, action)
  local ok, err = xpcall(action, debug.traceback)
  if not ok then
    error(name .. "\n" .. err)
  end
  M.count = M.count + 1
  print("PASS " .. name)
end

function M.equal(expected, actual)
  assert(vim.deep_equal(expected, actual), "Expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

function M.wait(predicate)
  assert(vim.wait(10000, predicate, 10), "Timed out")
end

return M
