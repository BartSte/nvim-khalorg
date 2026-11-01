local h = require("tests.helpers")
local khalorg = require("khalorg")
local health = require("khalorg.health")

h.test("health reports missing executables and unavailable sync", function()
  local saved_health, saved_system = vim.health, vim.system
  local messages = {}
  local function capture(message) messages[#messages + 1] = message end
  vim.health = { start = capture, ok = capture, error = capture, warn = capture, info = capture }
  khalorg.setup({ executable = "/nonexistent/khalorg" })
  health.check()
  assert(table.concat(messages, "\n"):find("Khalorg executable is missing", 1, true))
  messages = {}
  -- Neovim itself is executable, while the stub supplies CLI probe results.
  khalorg.setup({ executable = vim.v.progpath })
  local count = 0
  vim.system = function(argv)
    count = count + 1
    return { wait = function(_, timeout)
      h.equal(5000, timeout)
      return { code = argv[2] == "sync" and 2 or 0 }
    end }
  end
  health.check()
  h.equal(5, count)
  assert(table.concat(messages, "\n"):find("CLI sync is unavailable", 1, true))
  vim.health, vim.system = saved_health, saved_system
  khalorg.setup()
end)

h.test("health detects missing mapped directories", function()
  local saved = vim.health
  local errors = {}
  vim.health = { start = function() end, ok = function() end, info = function() end, warn = function() end,
    error = function(message) errors[#errors + 1] = message end }
  khalorg.setup({ executable = "/nonexistent/khalorg", calendars = { work = { org_file = "/nonexistent/khalorg/calendar.org" } } })
  health.check()
  assert(table.concat(errors, "\n"):find("directory does not exist", 1, true))
  vim.health = saved
  khalorg.setup()
end)
