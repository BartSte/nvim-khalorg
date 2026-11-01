local h = require("tests.helpers")
local khalorg = require("khalorg")
local process = require("khalorg.process")
local ui = require("khalorg.ui")
local run, report_error = process.run, ui.error
local calls, errors, pending
local file = vim.fn.tempname() .. " import.org"
local text = "* Imported\n<2030-01-01 Tue 01:00-02:00>\n:PROPERTIES:\n:UID: abc\n:END:\n"
local function setup()
  calls, errors, pending = {}, {}, nil
  vim.cmd.enew({ bang = true })
  khalorg.setup({ calendars = { work = { org_file = file } } })
  process.run = function(argv, _, callback)
    calls[#calls + 1] = argv
    pending = callback
  end
  ui.error = function(err) errors[#errors + 1] = tostring(err) end
end

h.test("list opens Org output without changing the current file", function()
  setup()
  local origin = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(origin, 0, -1, false, { "Unsaved notes" })
  khalorg.list({ calendar = "work", start = "2030-01-01", stop = "30d" })
  h.equal({ "khalorg", "list", "--", "work", "2030-01-01", "30d" }, calls[1])
  pending({ code = 0, stdout = text })
  h.equal("org", vim.bo.filetype)
  h.equal("* Imported", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
  h.equal({ "Unsaved notes" }, vim.api.nvim_buf_get_lines(origin, 0, -1, false))
  local saved = vim.fn.tempname() .. ".org"
  vim.cmd.write(vim.fn.fnameescape(saved))
  h.equal("* Imported", vim.fn.readfile(saved)[1])
  vim.fn.delete(saved)
  vim.cmd.close()
end)

h.test("import creates a mapped file and refuses overwrite", function()
  setup()
  khalorg.import({ calendar = "work" })
  pending({ code = 0, stdout = text })
  h.equal("* Imported", vim.fn.readfile(file)[1])
  khalorg.import({ calendar = "work" })
  h.equal(1, #calls)
  assert(errors[1]:find("does not overwrite", 1, true))
  vim.fn.delete(file)
end)

h.test("import protects a file created during the calendar read", function()
  setup()
  khalorg.import({ calendar = "work" })
  vim.fn.writefile({ "Created elsewhere" }, file)
  pending({ code = 0, stdout = text })
  h.equal({ "Created elsewhere" }, vim.fn.readfile(file))
  assert(#errors == 1)
  h.equal("org", vim.bo.filetype)
  vim.cmd.close()
  vim.fn.delete(file)
end)

h.test("failed list output never becomes an import file", function()
  setup()
  local result = ui.result
  ui.result = function() end
  khalorg.import({ calendar = "work" })
  pending({ code = 1, stderr = "Calendar unavailable" })
  h.equal(0, vim.fn.filereadable(file))
  ui.result = result
end)

process.run, ui.error = run, report_error
khalorg.setup()
