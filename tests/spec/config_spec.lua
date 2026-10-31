local h = require("tests.helpers")
local khalorg = require("khalorg")

h.test("setup without options uses the documented calendar", function()
  khalorg.setup()
  h.equal("default", khalorg.calendar)
  khalorg.setup({})
  h.equal("default", khalorg.calendar)
end)

h.test("calendar validation preserves the last valid configuration", function()
  khalorg.setup({ calendar = "Work calendar" })
  for _, opts in ipairs({ "invalid", { calendar = false }, { calendar = "" }, { calendar = "  " } }) do
    assert(not pcall(khalorg.setup, opts))
    h.equal("Work calendar", khalorg.calendar)
  end
  khalorg.setup()
end)
