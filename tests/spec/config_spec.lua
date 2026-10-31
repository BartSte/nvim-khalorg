local h = require("tests.helpers")
local khalorg = require("khalorg")

h.test("setup without options uses the documented calendar", function()
  khalorg.setup()
  h.equal("default", khalorg.calendar)
  khalorg.setup({})
  h.equal("default", khalorg.calendar)
end)

h.test("calendar mappings resolve by file with an explicit override", function()
  local config = require("khalorg.config")
  local work = vim.fn.tempname() .. " work.org"
  local personal = vim.fn.tempname() .. " personal.org"
  khalorg.setup({ calendars = { work = { org_file = work }, personal = { org_file = personal } } })
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_name(0, work)
  h.equal("work", config.resolve().calendar)
  h.equal(work, config.resolve().org_file)
  h.equal("personal", config.resolve({ calendar = "personal" }).calendar)
  h.equal({ "personal", "work" }, config.names())
  vim.api.nvim_buf_set_name(0, personal)
  h.equal("personal", config.resolve().calendar)
  khalorg.setup()
  h.equal("default", config.resolve().calendar)
end)

h.test("duplicate calendar files and invalid executable values are rejected", function()
  local file = vim.fn.tempname() .. ".org"
  assert(not pcall(khalorg.setup, { calendars = { a = { org_file = file }, b = { org_file = file } } }))
  assert(not pcall(khalorg.setup, { calendars = { a = {} } }))
  assert(not pcall(khalorg.setup, { executable = "" }))
  assert(not pcall(khalorg.setup, false))
  khalorg.setup()
end)

h.test("calendar validation preserves the last valid configuration", function()
  khalorg.setup({ calendar = "Work calendar" })
  for _, opts in ipairs({ "invalid", { calendar = false }, { calendar = "" }, { calendar = "  " } }) do
    assert(not pcall(khalorg.setup, opts))
    h.equal("Work calendar", khalorg.calendar)
  end
  khalorg.setup()
end)
