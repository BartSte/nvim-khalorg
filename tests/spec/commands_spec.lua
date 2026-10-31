local h = require("tests.helpers")
local khalorg = require("khalorg")
local list = require("khalorg.list")
local ui = require("khalorg.ui")

h.test("commands preserve calendar names with escaped spaces", function()
  local run, sync = list.run, khalorg.sync
  local listed, synced
  list.run = function(opts) listed = opts end
  khalorg.sync = function(opts) synced = opts end
  khalorg.setup()
  vim.cmd("KhalorgList Work\\ calendar today 7d")
  h.equal("Work calendar", listed.calendar)
  h.equal("today", listed.start)
  h.equal("7d", listed.stop)
  vim.cmd("KhalorgSync Work\\ calendar")
  h.equal("Work calendar", synced.calendar)
  list.run, khalorg.sync = run, sync
end)

h.test("list commands reject extra arguments before starting a process", function()
  local run, report = list.run, ui.error
  local error
  list.run = function() assert(false, "Unexpected calendar read") end
  ui.error = function(message) error = message end
  vim.cmd("KhalorgList work today 7d extra")
  assert(error:find("Use [calendar] [start] [stop]", 1, true))
  list.run, ui.error = run, report
end)
