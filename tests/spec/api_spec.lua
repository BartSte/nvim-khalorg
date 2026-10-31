local h = require("tests.helpers")
local khalorg = require("khalorg")
local process = require("khalorg.process")

h.test("public actions work directly and as orgmode export callbacks", function()
  local run, get_item = process.run, khalorg.get_item_in_fold_under_cursor
  local calls = {}
  process.run = function(argv, stdin)
    calls[#calls + 1] = { argv = argv, stdin = stdin }
  end
  khalorg.get_item_in_fold_under_cursor = function() return "* Meeting\n<2030-01-01 Tue>" end
  -- Keep a reference before setup, as orgmode does when registering exports.
  local edit = khalorg.edit
  khalorg.new()
  khalorg.setup({ calendar = "Work calendar" })
  edit(function() error("The legacy exporter must not run") end)
  khalorg.edit_all()
  khalorg.delete()
  h.equal({ "khalorg", "new", "default" }, calls[1].argv)
  h.equal({ "khalorg", "edit", "Work calendar" }, calls[2].argv)
  h.equal({ "khalorg", "edit", "--edit-dates", "Work calendar" }, calls[3].argv)
  h.equal({ "khalorg", "delete", "Work calendar" }, calls[4].argv)
  h.equal(khalorg.edit, khalorg.edit_props)
  process.run, khalorg.get_item_in_fold_under_cursor = run, get_item
  khalorg.setup()
end)
