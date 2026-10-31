local h = require("tests.helpers")
local khalorg = require("khalorg")
local process = require("khalorg.process")
local ui = require("khalorg.ui")
local run, error_report = process.run, ui.error
local calls, errors, pending, baseline, source
local timestamp = "<2030-01-01 Tue 01:00-02:00>"
local record = "new-uid\tMeeting\t<2030-01-01 Tue 01:00>--<2030-01-01 Tue 02:00>\n"

local function setup(lines)
  calls, errors, pending, baseline = {}, {}, nil, ""
  vim.cmd.enew({ bang = true })
  source = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(source, 0, -1, false, lines or { "* Meeting", timestamp, "Notes" })
  vim.bo.filetype = "org"
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  khalorg.setup()
  ui.error = function(err) errors[#errors + 1] = tostring(err) end
  local listed = false
  process.run = function(argv, stdin, callback)
    calls[#calls + 1] = { argv = argv, stdin = stdin }
    if argv[2] == "new" then
      callback({ code = 0, stdout = "Created" })
    elseif not listed then
      listed = true
      callback({ code = 0, stdout = baseline })
    else
      pending = callback
    end
  end
end

local function contents()
  return table.concat(vim.api.nvim_buf_get_lines(source, 0, -1, false), "\n")
end

h.test("new writes a verified UID into a new property drawer", function()
  setup()
  khalorg.new()
  h.equal("list", calls[1].argv[2])
  h.equal("2030-01-01 Tue", calls[1].argv[7])
  h.equal({ "khalorg", "new", "--", "default" }, calls[2].argv)
  pending({ code = 0, stdout = record })
  assert(contents():find(":PROPERTIES:\n:UID: new-uid\n:END:\nNotes", 1, true))
  h.equal(true, vim.bo[source].modified)
end)

h.test("UID writeback fills a blank property and preserves the body", function()
  setup({ "* Meeting", "  " .. timestamp, "  :PROPERTIES:", "  :LOCATION: Room", "  :UID:", "  :END:", "  Notes", "** Child", "<2030-01-02 Wed>" })
  khalorg.new()
  pending({ code = 0, stdout = record })
  assert(contents():find("  :UID: new-uid", 1, true))
  assert(contents():find("  :LOCATION: Room", 1, true))
  assert(contents():find("** Child", 1, true))
end)

h.test("UID writeback inserts into an existing drawer without a UID", function()
  setup({ "* Meeting", timestamp, ":PROPERTIES:", ":LOCATION: Room", ":END:", "Notes" })
  khalorg.new()
  pending({ code = 0, stdout = record })
  assert(contents():find(":LOCATION: Room\n:UID: new-uid\n:END:", 1, true))
end)

h.test("new refuses entries that already have a UID", function()
  setup({ "* Meeting", timestamp, ":PROPERTIES:", ":UID: existing", ":END:" })
  khalorg.new()
  h.equal(0, #calls)
  assert(errors[1]:find("already has a UID", 1, true))
end)

h.test("existing matching calendar events are not created again", function()
  setup()
  baseline = record
  khalorg.new()
  h.equal(1, #calls)
  assert(errors[1]:find("already exists", 1, true))
end)

h.test("ambiguous new UIDs do not change the source", function()
  setup()
  local original = contents()
  khalorg.new()
  pending({ code = 0, stdout = record .. record:gsub("new%-uid", "other-uid") })
  h.equal(original, contents())
end)

h.test("UID lookup verifies the event title and time", function()
  setup()
  local original = contents()
  khalorg.new()
  pending({ code = 0, stdout = record:gsub("Meeting", "Unrelated") })
  h.equal(original, contents())
end)

h.test("concurrent edits prevent UID writeback", function()
  setup()
  khalorg.new()
  vim.api.nvim_buf_set_lines(source, 2, 3, false, { "Edited notes" })
  pending({ code = 0, stdout = record })
  assert(not contents():find(":UID:", 1, true))
  assert(contents():find("Edited notes", 1, true))
end)

h.test("cursor and buffer switches do not redirect UID writeback", function()
  setup()
  khalorg.new()
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Other buffer" })
  pending({ code = 0, stdout = record })
  assert(contents():find(":UID: new-uid", 1, true))
  h.equal({ "Other buffer" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
end)

h.test("a failed creation does not write a UID and releases the calendar", function()
  setup()
  local original = contents()
  process.run = function(argv, _, callback)
    callback({ code = argv[2] == "new" and 1 or 0, stdout = "", stderr = "Failure" })
  end
  khalorg.new()
  h.equal(original, contents())
  setup()
  khalorg.new()
  pending({ code = 0, stdout = record })
  assert(contents():find(":UID: new-uid", 1, true))
end)

h.test("edits during the first UID read prevent calendar creation", function()
  setup()
  local first_read
  process.run = function(_, _, callback) first_read = callback end
  khalorg.new()
  vim.api.nvim_buf_set_lines(source, 2, 3, false, { "New notes" })
  first_read({ code = 0, stdout = "" })
  assert(errors[1]:find("changed before event creation", 1, true))
end)

h.test("malformed UID output stops creation and releases the lock", function()
  setup()
  baseline = "Malformed\tTitle\tWith\tTabs\n"
  khalorg.new()
  h.equal(1, #calls)
  assert(errors[1]:find("Cannot read event UIDs", 1, true))
end)

h.test("all-day and point events match their calendar representation", function()
  setup({ "* Meeting", "<2030-01-01 Tue>" })
  khalorg.new()
  pending({ code = 0, stdout = "all-day\tMeeting\t<2030-01-01 Tue>\n" })
  assert(contents():find(":UID: all-day", 1, true))
  setup({ "* Meeting", "<2030-01-01 Tue 23:30>" })
  khalorg.new()
  pending({ code = 0, stdout = "overnight\tMeeting\t<2030-01-01 Tue 23:30>--<2030-01-02 Wed 00:30>\n" })
  assert(contents():find(":UID: overnight", 1, true))
end)

h.test("a deleted source buffer does not receive writeback", function()
  setup()
  khalorg.new()
  vim.api.nvim_buf_delete(source, { force = true })
  pending({ code = 0, stdout = record })
  assert(not vim.api.nvim_buf_is_valid(source))
end)

h.test("event creation shares overlap protection with sync", function()
  setup()
  khalorg.new()
  local release, err = require("khalorg.lock").acquire(require("khalorg.config").resolve())
  h.equal(nil, release)
  assert(err:find("already running", 1, true))
  pending({ code = 0, stdout = record })
end)

h.test("UID matching normalizes TODO, priorities, tags, and links", function()
  setup({ "* TODO [#A] [[https://example.com][Meeting]] :work:", timestamp })
  khalorg.new()
  pending({ code = 0, stdout = record })
  assert(contents():find(":UID: new-uid", 1, true))
end)

process.run, ui.error = run, error_report
khalorg.setup()
