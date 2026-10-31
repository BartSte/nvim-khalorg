local h = require("tests.helpers")
local khalorg = require("khalorg")
local process = require("khalorg.process")

h.test("public actions work directly and as orgmode export callbacks", function()
  local run, get_item = process.run, khalorg.get_item_in_fold_under_cursor
  local calls = {}
  process.run = function(argv, stdin, callback)
    calls[#calls + 1] = { argv = argv, stdin = stdin }
    callback({ code = 0 })
  end
  khalorg.get_item_in_fold_under_cursor = function() return "* Meeting\n<2030-01-01 Tue>" end
  -- Keep a reference before setup, as orgmode does when registering exports.
  local edit = khalorg.edit
  khalorg.new({ write_uid = false })
  khalorg.setup({ calendar = "Work calendar" })
  edit(function() error("The legacy exporter must not run") end)
  khalorg.edit_all()
  khalorg.delete()
  h.equal({ "khalorg", "new", "--", "default" }, calls[1].argv)
  h.equal({ "khalorg", "edit", "--", "Work calendar" }, calls[2].argv)
  h.equal({ "khalorg", "edit", "--edit-dates", "--", "Work calendar" }, calls[3].argv)
  h.equal({ "khalorg", "delete", "--", "Work calendar" }, calls[4].argv)
  h.equal(khalorg.edit, khalorg.edit_props)
  process.run, khalorg.get_item_in_fold_under_cursor = run, get_item
  khalorg.setup()
end)

h.test("event actions select the calendar for the current file", function()
  local run, get_item = process.run, khalorg.get_item_in_fold_under_cursor
  local called
  process.run = function(argv, _, callback) called = argv; callback({ code = 0 }) end
  khalorg.get_item_in_fold_under_cursor = function() return "* Meeting\n<2030-01-01 Tue>" end
  local file = vim.fn.tempname() .. " work.org"
  khalorg.setup({ executable = "/path with spaces/khalorg", calendars = { work = { org_file = file } } })
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_name(0, file)
  khalorg.edit()
  h.equal({ "/path with spaces/khalorg", "edit", "--", "work" }, called)
  khalorg.edit({ calendar = "another calendar" })
  h.equal("another calendar", called[4])
  process.run, khalorg.get_item_in_fold_under_cursor = run, get_item
  khalorg.setup()
end)
