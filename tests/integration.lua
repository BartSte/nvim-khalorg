-- Run against a separate khalorg installation. All calendar data stays in a temp directory.
vim.opt.rtp:prepend(vim.fn.getcwd())
if vim.env.ORG_MODE_PATH then vim.opt.rtp:append(vim.env.ORG_MODE_PATH) end
local h = require("tests.helpers")
local executable = assert(vim.env.KHALORG_INTEGRATION_BIN, "Set KHALORG_INTEGRATION_BIN to a khalorg executable with sync support")
executable = vim.fn.fnamemodify(executable, ":p")
local root = vim.fn.tempname() .. " integration"
for _, directory in ipairs({ "/config/khal", "/data", "/cache", "/calendar", "/state" }) do
  vim.fn.mkdir(root .. directory, "p")
end
vim.env.XDG_CONFIG_HOME, vim.env.XDG_DATA_HOME, vim.env.XDG_CACHE_HOME = root .. "/config", root .. "/data", root .. "/cache"
vim.fn.writefile({
  "[calendars]", "[[work]]", "path = " .. root .. "/calendar", "type = calendar",
  "[sqlite]", "path = " .. root .. "/calendar.db",
  "[default]", "default_calendar = work", "[locale]",
  "local_timezone = Europe/Berlin", "default_timezone = Europe/Berlin",
  "longdatetimeformat = %Y-%m-%d %a %H:%M", "datetimeformat = %Y-%m-%d %a %H:%M",
  "longdateformat = %Y-%m-%d %a", "dateformat = %Y-%m-%d %a", "timeformat = %H:%M",
}, root .. "/config/khal/config")
local process = require("khalorg.process")
local run = process.run
-- Khalorg's log path ignores XDG variables. Override it without changing HOME.
process.run = function(argv, stdin, callback)
  local isolated = { argv[1], "--logfile", root .. "/khalorg.log" }
  vim.list_extend(isolated, vim.list_slice(argv, 2))
  return run(isolated, stdin, callback)
end
local khalorg = require("khalorg")
local file = root .. "/calendar.org"
local year = tonumber(os.date("%Y")) + 2
local date = string.format("%04d-01-03", year)
local weekday = os.date("%a", os.time({ year = year, month = 1, day = 3, hour = 12 }))
local start = date .. " " .. weekday
local timestamp = "<" .. start .. " 10:00-11:00>"
local format = "* {title}\n{timestamps}\n:PROPERTIES:\n:UID: {uid}\n:CALENDAR: {calendar}\n:END:\n{description}\n"
khalorg.setup({ executable = executable, calendars = { work = { org_file = file } },
  sync = { start = start, stop = "7d", state_dir = root .. "/state", edit_dates = true, format = format } })
require("orgmode").setup({ org_agenda_files = { root .. "/*.org" }, org_default_notes_file = root .. "/notes.org",
  notifications = { enabled = false },
  org_custom_exports = { n = { label = "Create calendar event", action = khalorg.new } },
})
local function await(action, opts)
  local result, extra
  opts = opts or {}
  opts.on_complete = function(value, other) result, extra = value, other end
  action(opts)
  h.wait(function() return result ~= nil end)
  assert(result.code == 0, vim.inspect(result))
  return result, extra
end
local function cli(argv, stdin)
  local result
  process.run(argv, stdin, function(value) result = value end)
  h.wait(function() return result ~= nil end)
  assert(result.code == 0, vim.inspect(result))
  return result.stdout
end
local function listed()
  return cli({ executable, "list", "--format", format, "--", "work", start, "7d" })
end
local uid
h.test("integration creates an event and writes its real UID", function()
  vim.cmd.edit(vim.fn.fnameescape(file))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "* Budget $HOME $(printf BAD)", timestamp, 'A "quoted" description with `literal` text.' })
  vim.bo.filetype = "org"
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local _, value = await(khalorg.new)
  uid = assert(value, "The created UID was not found")
  local source = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  assert(source:find(":UID: " .. uid, 1, true))
  assert(listed():find('A "quoted" description with `literal` text.', 1, true))
  assert(listed():find("Budget $HOME $(printf BAD)", 1, true))
  vim.cmd.write()
end)
h.test("integration edits properties and event dates", function()
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { "* Updated meeting" })
  await(khalorg.edit)
  assert(listed():find("Updated meeting", 1, true))
  vim.api.nvim_buf_set_lines(0, 1, 2, false, { (timestamp:gsub("10:00%-11:00", "12:00-13:00")) })
  await(khalorg.edit_all)
  assert(listed():find("12:00", 1, true))
  vim.cmd.write()
end)
h.test("integration imports to a new file and opens list output", function()
  local imported = root .. "/import.org"
  await(khalorg.import, { calendar = "work", org_file = imported })
  assert(table.concat(vim.fn.readfile(imported), "\n"):find(uid, 1, true))
  local _, bufnr = await(khalorg.list, { calendar = "work" })
  h.equal("org", vim.bo[bufnr].filetype)
  assert(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"):find(uid, 1, true))
  vim.cmd.close()
end)
h.test("integration dry run preserves the Org file and sync state", function()
  local before = vim.fn.readfile(file)
  local calendar_before = {}
  for _, event_file in ipairs(vim.fn.glob(root .. "/calendar/*.ics", false, true)) do
    calendar_before[event_file] = vim.fn.readfile(event_file)
  end
  await(khalorg.sync_dry_run)
  h.equal(before, vim.fn.readfile(file))
  h.equal({}, vim.fn.glob(root .. "/state/*", false, true))
  for event_file, content in pairs(calendar_before) do h.equal(content, vim.fn.readfile(event_file)) end
  h.equal(vim.tbl_count(calendar_before), #vim.fn.glob(root .. "/calendar/*.ics", false, true))
  vim.cmd.close()
end)
h.test("integration sync imports remote events and reloads the source", function()
  cli({ executable, "new", "--", "work" }, "* Remote event\n<" .. start .. " 15:00-16:00>\nRemote notes")
  await(khalorg.sync)
  vim.cmd.close()
  local source = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  assert(source:find("Remote event", 1, true))
  assert(#vim.fn.glob(root .. "/state/*", false, true) > 0)
end)
h.test("integration deletion removes only the selected temporary event", function()
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  await(khalorg.delete)
  local remaining = listed()
  assert(not remaining:find(uid, 1, true))
  assert(remaining:find("Remote event", 1, true))
end)
h.test("integration writes UIDs for all-day and overnight point events", function()
  for _, item in ipairs({ { "All-day event", "<" .. start .. ">" }, { "Overnight point event", "<" .. start .. " 23:30>" } }) do
    vim.cmd.enew({ bang = true })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "* " .. item[1], item[2] })
    vim.bo.filetype = "org"
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local _, created_uid = await(khalorg.new, { calendar = "work" })
    assert(created_uid, "UID writeback failed for " .. item[1])
  end
end)
process.run = run
print(string.format("Passed %d isolated integration tests", h.count))
vim.fn.delete(root, "rf")
