local process = require("khalorg.process")
local config = require("khalorg.config")
local ui = require("khalorg.ui")

local M = { calendar = config.values.calendar }

function M.get_item_in_fold_under_cursor()
  return require("khalorg.org").capture().text
end

local function report(result)
  if result.code == 0 then
    vim.notify("Khalorg export successful")
    local output = (result.stdout or "") .. (result.stderr or "")
    if output ~= "" then
      vim.api.nvim_echo({ { output } }, true, {})
    end
  else
    ui.error(result.stderr or "Command failed")
  end
end

local function selected_item()
  local ok, item = pcall(M.get_item_in_fold_under_cursor)
  if not ok or item == "" then
    ui.error(ok and "No agenda item found under the cursor" or item)
    return nil
  end
  return item
end

---Create an action that sends the selected event to an argument array.
function M.make_exporter(argv)
  assert(type(argv) == "table" and #argv > 0, "Use an argument array for the khalorg command")
  return function()
    local item = selected_item()
    if item then
      return process.run(argv, item, report)
    end
  end
end

local function action(command, edit_dates, opts)
  opts = type(opts) == "table" and opts or {}
  local ok, target = pcall(config.resolve, opts)
  if not ok then
    ui.error(target)
    return
  end
  local write_uid = opts.write_uid
  if write_uid == nil then write_uid = config.values.write_uid end
  if command == "new" and write_uid then
    return require("khalorg.new").run(target, opts, report)
  end
  local item = selected_item()
  if not item then return end
  local release, err = require("khalorg.lock").acquire(target)
  if not release then ui.error(err); return end
  local argv = { target.executable, command }
  if edit_dates then argv[#argv + 1] = "--edit-dates" end
  vim.list_extend(argv, { "--", target.calendar })
  return process.run(argv, item, function(result)
    release()
    report(result)
    if opts.on_complete then opts.on_complete(result) end
  end)
end

-- Orgmode passes an unused exporter callback. Direct calls accept options.
function M.new(opts)
  return action("new", false, opts)
end

function M.edit(opts)
  return action("edit", false, opts)
end

function M.delete(opts)
  return action("delete", false, opts)
end

function M.edit_all(opts)
  return action("edit", true, opts)
end

M.edit_props = M.edit

function M.sync(opts)
  return require("khalorg.sync").run(opts)
end

function M.sync_dry_run(opts)
  opts = type(opts) == "table" and vim.deepcopy(opts) or {}
  opts.dry_run = true
  return M.sync(opts)
end

function M.list(opts)
  return require("khalorg.list").run(opts)
end

function M.import(opts)
  opts = type(opts) == "table" and vim.deepcopy(opts) or {}
  opts.import = true
  return M.list(opts)
end

function M.setup(opts)
  M.calendar = config.setup(opts).calendar
  require("khalorg.commands").setup()
end

return M
