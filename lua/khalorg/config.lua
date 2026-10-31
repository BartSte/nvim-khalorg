local M = { values = { calendar = "default" } }

function M.setup(opts)
  opts = opts or {}
  assert(type(opts) == "table", "Khalorg configuration must be a table")
  local values = vim.tbl_extend("force", { calendar = "default" }, opts)
  assert(type(values.calendar) == "string" and values.calendar:match("%S"), "Khalorg calendar must be a non-empty string")
  M.values = values
  return values
end

return M
