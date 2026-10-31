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
