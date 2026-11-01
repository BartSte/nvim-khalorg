local M = {}

local function command_supported(executable, command)
  local ok, result = pcall(function()
    return vim.system({ executable, command, "--help" }, { text = true }):wait(5000)
  end)
  return ok and result.code == 0
end

function M.check()
  local health = vim.health
  local config = require("khalorg.config")
  health.start("Khalorg")
  if vim.fn.has("nvim-0.11") == 1 then
    health.ok("Neovim 0.11 or later")
  else
    health.error("Neovim 0.11 or later is required")
  end
  local orgmode = pcall(require, "orgmode")
  if orgmode then
    health.ok("Orgmode is available")
  else
    health.error("Orgmode is missing. Install nvim-orgmode/orgmode and call its setup function.")
  end
  local parser, reason = pcall(function()
    local trees = vim.treesitter.get_string_parser("* Health\n<2030-01-01 Tue>\n", "org"):parse()
    assert(not trees[1]:root():has_error(), "Org parser returned a syntax error")
    vim.treesitter.query.parse("org", "(section headline: (headline) plan: (plan))")
  end)
  if parser then
    health.ok("Org Tree-sitter parser supports event extraction")
  else
    health.error("Org parser is missing or incompatible. Install the parser through orgmode setup. " .. tostring(reason))
  end
  local executable = config.values.executable
  if vim.fn.executable(executable) == 1 then
    health.ok("Khalorg executable: " .. executable)
    for _, command in ipairs({ "new", "edit", "delete", "list", "sync" }) do
      if command_supported(executable, command) then
        health.ok("CLI supports " .. command)
      elseif command == "sync" then
        health.warn("CLI sync is unavailable. Install a khalorg version with sync support.")
      else
        health.error("CLI command is unavailable: " .. command .. ". Check the configured executable.")
      end
    end
  else
    health.error("Khalorg executable is missing: " .. executable .. ". Install khalorg or configure executable.")
  end
  if vim.fn.executable("khal") == 1 then
    health.ok("Khal executable is available")
  else
    health.error("Khal executable is missing from PATH")
  end
  if vim.fn.executable("vdirsyncer") == 1 then
    health.ok("Optional vdirsyncer executable is available")
  else
    health.info("Install vdirsyncer if you need remote CalDAV synchronization")
  end
  if #config.names() == 0 then
    health.info("No calendar-to-file mappings. Event actions use " .. config.values.calendar)
  end
  for name, calendar in pairs(config.values.calendars) do
    local parent = vim.fs.dirname(calendar.org_file)
    if vim.fn.isdirectory(parent) ~= 1 then
      health.error("Calendar " .. name .. ": directory does not exist: " .. parent)
    elseif vim.fn.filereadable(calendar.org_file) == 1 then
      health.ok("Calendar " .. name .. ": " .. calendar.org_file)
    elseif vim.uv.fs_stat(calendar.org_file) then
      health.error("Calendar " .. name .. ": org_file is not a readable file: " .. calendar.org_file)
    else
      health.info("Calendar " .. name .. ": import or sync can create " .. calendar.org_file)
    end
  end
end

return M
