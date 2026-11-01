local h = require("tests.helpers")
local khalorg = require("khalorg")
local process = require("khalorg.process")
local ui = require("khalorg.ui")
local original_run, original_result, original_error = process.run, ui.result, ui.error
local calls, errors, results, pending
local file = vim.fn.tempname() .. " calendar.org"

local function setup()
  calls, errors, results, pending = {}, {}, {}, nil
  vim.fn.writefile({ "* Saved", "<2030-01-01 Tue>" }, file)
  vim.cmd.enew({ bang = true })
  vim.cmd("edit! " .. vim.fn.fnameescape(file))
  vim.cmd("silent edit!")
  khalorg.setup({ calendars = { work = { org_file = file } } })
  ui.result = function(title, result) results[#results + 1] = { title = title, result = result } end
  ui.error = function(err) errors[#errors + 1] = tostring(err) end
  process.run = function(argv, _, callback)
    calls[#calls + 1] = argv
    if argv[3] == "--help" then
      callback({ code = 0 })
    else
      pending = callback
    end
  end
end

h.test("sync resolves mappings, serializes options, and blocks overlap", function()
  setup()
  khalorg.sync({ start = "2030-01-01", stop = "30d", edit_dates = true, conflict_resolution = "org", state_dir = "/tmp/state with spaces", filetags = { "work" } })
  h.equal({ "khalorg", "sync", "--help" }, calls[1])
  h.equal({ "khalorg", "sync", "--start", "2030-01-01", "--stop", "30d", "--conflict-resolution", "org", "--edit-dates", "--state-dir", "/tmp/state with spaces", "--filetags", "work", "--", "work", file }, calls[2])
  khalorg.sync()
  h.equal(2, #calls)
  assert(errors[1]:find("already running", 1, true))
  vim.fn.writefile({ "* Imported", "<2030-01-02 Wed>" }, file)
  pending({ code = 0, stdout = "Imported 1 event" })
  h.equal("* Imported", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
  h.equal(1, #results)
end)

h.test("sync refuses unsaved buffers and invalid options", function()
  setup()
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { "* Unsaved" })
  khalorg.sync()
  h.equal(0, #calls)
  assert(errors[1]:find("Save changes", 1, true))
  vim.bo.modified = false
  khalorg.sync({ conflict_resolution = "invalid" })
  h.equal(0, #calls)
end)

h.test("sync preserves edits made while the process runs", function()
  setup()
  khalorg.sync()
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { "* Typed during sync" })
  vim.fn.writefile({ "* Remote change" }, file)
  pending({ code = 0 })
  h.equal("* Typed during sync", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
  h.equal(true, vim.bo.modified)
end)

h.test("dry run disables reload and deletion propagation stays off", function()
  setup()
  khalorg.sync_dry_run()
  h.equal({}, errors)
  assert(vim.tbl_contains(calls[2], "--dry-run"))
  assert(not vim.tbl_contains(calls[2], "--delete-on-sync"))
  pending({ code = 0, stdout = "Preview only" })
  h.equal("sync preview", results[1].title)
end)

h.test("missing sync capability reports an upgrade and releases its lock", function()
  setup()
  process.run = function(_, _, callback) callback({ code = 2, stderr = "invalid choice: sync" }) end
  khalorg.sync()
  assert(errors[1]:find("Install a version", 1, true))
  setup()
  khalorg.sync()
  h.equal(2, #calls)
  pending({ code = 1, stderr = "Calendar error" })
  h.equal(1, results[1].result.code)
end)

h.test("changes during the capability probe block sync", function()
  setup()
  local probe
  process.run = function(_, _, callback) probe = callback end
  khalorg.sync()
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { "* Changed during probe" })
  probe({ code = 0 })
  assert(errors[1]:find("Save changes", 1, true))
end)

process.run, ui.result, ui.error = original_run, original_result, original_error
khalorg.setup()
vim.cmd.enew({ bang = true })
vim.fn.delete(file)
