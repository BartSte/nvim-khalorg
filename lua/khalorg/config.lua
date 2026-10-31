local defaults = { calendar = "default", executable = "khalorg", calendars = {} }
local M = { values = vim.deepcopy(defaults) }

local function nonempty(value, name)
  assert(type(value) == "string" and value:match("%S"), "Khalorg " .. name .. " must be a non-empty string")
end

function M.path(path)
  local absolute = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
  return vim.uv.fs_realpath(absolute) or absolute
end

function M.setup(opts)
  if opts == nil then
    opts = {}
  end
  assert(type(opts) == "table", "Khalorg configuration must be a table")
  local values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  nonempty(values.calendar, "calendar")
  nonempty(values.executable, "executable")
  assert(type(values.calendars) == "table", "Khalorg calendars must be a table")
  local files = {}
  for name, calendar in pairs(values.calendars) do
    nonempty(name, "calendar name")
    assert(type(calendar) == "table", "Each Khalorg calendar must be a table")
    nonempty(calendar.org_file, "org_file")
    calendar.org_file = M.path(calendar.org_file)
    assert(not files[calendar.org_file], "Each Org file must map to only one calendar")
    files[calendar.org_file] = name
  end
  M.values = values
  return values
end

function M.names()
  return vim.fn.sort(vim.tbl_keys(M.values.calendars))
end

---Resolve the calendar at action time, so saved callbacks use the current file.
function M.resolve(opts)
  opts = opts or {}
  local name = opts.calendar
  local file = vim.api.nvim_buf_get_name(opts.bufnr or 0)
  if not name and file ~= "" then
    file = M.path(file)
    for candidate, calendar in pairs(M.values.calendars) do
      if calendar.org_file == file then
        name = candidate
        break
      end
    end
  end
  name = name or M.values.calendar
  nonempty(name, "calendar")
  local calendar = vim.deepcopy(M.values.calendars[name] or {})
  calendar.calendar = name
  calendar.executable = M.values.executable
  calendar.org_file = opts.org_file and M.path(opts.org_file) or calendar.org_file
  return calendar
end

return M
