local h = require("tests.helpers")
local khalorg = require("khalorg")

local function extract(lines, row)
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "org"
  vim.api.nvim_win_set_cursor(0, { row or 1, 0 })
  return khalorg.get_item_in_fold_under_cursor()
end

h.test("ordinary events export without query metadata", function()
  local text = extract({ "* Meeting", "<2030-01-01 Tue 01:00-02:00>", ":PROPERTIES:", ":UID: 123", ":END:", "Description" })
  assert(text:find("* Meeting", 1, true))
  assert(text:find(":UID: 123", 1, true))
  assert(text:find("Description", 1, true))
end)

h.test("parent export excludes child events", function()
  local text = extract({ "* Parent", "<2030-01-01 Tue 01:00-02:00>", "Parent notes", "** Child", "<2030-01-02 Wed 01:00-02:00>", "Child notes" })
  assert(text:find("Parent notes", 1, true))
  assert(not text:find("Child", 1, true))
end)

h.test("cursor in a child exports only the child", function()
  local text = extract({ "* Parent", "<2030-01-01 Tue 01:00-02:00>", "** Child", "<2030-01-02 Wed 01:00-02:00>", "Child notes" }, 5)
  assert(text:find("** Child", 1, true))
  assert(not text:find("Parent", 1, true))
end)

h.test("explicit date ranges retain their original separator", function()
  local range = "<2030-01-01 Tue 01:00>--<2030-01-02 Wed 02:00>"
  local text = extract({ "* Meeting", range, "Notes" })
  assert(text:find(range, 1, true))
end)

h.test("scheduled and deadline dates are not combined", function()
  local ok, err = pcall(extract, { "* Meeting", "SCHEDULED: <2030-01-01 Tue 01:00-02:00> DEADLINE: <2030-01-02 Wed 01:00-02:00>" })
  assert(not ok)
  assert(tostring(err):find("Multiple event timestamps", 1, true))
end)

h.test("inactive CLOSED dates do not change the event range", function()
  local text = extract({ "* Meeting", "CLOSED: [2030-01-01 Tue] SCHEDULED: <2030-01-02 Wed 01:00-02:00>" })
  assert(text:find("<2030-01-02 Wed 01:00-02:00>", 1, true))
  assert(not text:find("CLOSED", 1, true))
end)

h.test("multiple occurrence timestamps fail before export", function()
  local ok, err = pcall(extract, { "* Meeting", "<2030-01-01 Tue 01:00-02:00>", "<2030-01-08 Tue 01:00-02:00>" })
  assert(not ok)
  assert(tostring(err):find("Multiple event timestamps", 1, true))
end)

h.test("a single repeater remains intact", function()
  local timestamp = "<2030-01-01 Tue 01:00-02:00 +1w>"
  assert(extract({ "* Meeting", timestamp }):find(timestamp, 1, true))
end)
