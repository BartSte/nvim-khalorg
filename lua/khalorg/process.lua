local M = {}

---Run a command without a shell. Deliver results on the main event loop.
---@param argv string[]
---@param stdin string|nil
---@param callback fun(result: table)
function M.run(argv, stdin, callback)
  assert(type(argv) == "table" and #argv > 0, "Use a non-empty argument array for the khalorg command")
  for _, arg in ipairs(argv) do
    assert(type(arg) == "string", "Command arguments must be strings")
  end
  local ok, process = pcall(vim.system, argv, { stdin = stdin, text = true }, function(result)
    vim.schedule(function()
      callback(result)
    end)
  end)
  if not ok then
    vim.schedule(function()
      callback({ code = -1, stdout = "", stderr = tostring(process) })
    end)
    return nil
  end
  return process
end

return M
