local h = require("tests.helpers")
local process = require("khalorg.process")

h.test("stdin and arguments preserve shell-sensitive text", function()
  local payload = '* Budget $HOME $(printf BAD) `printf BAD`\nA "quoted" description\\n'
  local argument = "Work calendar; $(printf BAD)"
  local result
  process.run({ vim.v.progpath, "--headless", "-u", "NONE", "-l", "tests/fixtures/echo.lua", argument }, payload, function(output)
    result = output
  end)
  h.wait(function() return result ~= nil end)
  h.equal(0, result.code)
  h.equal(payload .. "\nARG:" .. argument, result.stdout)
end)

h.test("spawn failures reach the error callback", function()
  local result
  process.run({ "/nonexistent/khalorg" }, "", function(output) result = output end)
  h.wait(function() return result ~= nil end)
  assert(result.code ~= 0)
  assert(result.stderr ~= "")
end)

h.test("shell command strings are rejected", function()
  assert(not pcall(process.run, "cat | sh", "", function() end))
end)
