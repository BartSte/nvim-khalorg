local process = require("khalorg.process")
local config = require("khalorg.config")

---@class Khalorg
---@field calendar string
---@field delete function
---@field edit function
---@field edit_all function
---@field get_item_in_fold_under_cursor function
---@field make_exporter function
---@field new function
---@field setup function
local M = { calendar = config.values.calendar }

local function get_fold_node(node_type)
  vim.treesitter.get_parser(0, "org"):parse()
  local node = vim.treesitter.get_node({ lang = "org" })
  while node and node:type() ~= node_type do
    node = node:parent()
  end
  if node == nil then
    error("No fold found under the cursor")
  end
  return node
end

-- Print the output of a successful export.
--@param output string[]
local function export_success(output)
  vim.notify("Khalorg export successful")
  vim.api.nvim_echo({ { table.concat(output, "\n") } }, true, {})
end

-- Print the error message of a failed export.
--@param err string[]
local function export_error(err)
  vim.notify("Khalorg export failed")
  vim.api.nvim_echo({ { table.concat(err, "\n"), "ErrorMsg" } }, true, {})
end

-- Get the headline, timestamps and properties of the fold under the cursor. If no fold, headline or timestamp is found, return an empty string.
-- @return string
M.get_item_in_fold_under_cursor = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local fold_node = get_fold_node("section")

  -- Export only this section, without its child sections.
  local startfold, _, endfold = fold_node:range()
  for child in fold_node:iter_children() do
    if child:type() == "section" then
      endfold = child:start()
      break
    end
  end

  local function text(field)
    local node = fold_node:field(field)[1]
    return node and vim.treesitter.get_node_text(node, bufnr) or ""
  end

  -- A timestamp node already includes an explicit Org date range.
  -- Never manufacture a range from separate planning entries.
  local timestamps = {}
  local query = vim.treesitter.query.parse("org", "(timestamp) @timestamp")
  for _, node in query:iter_captures(fold_node, bufnr, startfold, endfold) do
    if node:start() < endfold then
      local value = vim.treesitter.get_node_text(node, bufnr)
      if value:sub(1, 1) == "<" then
        timestamps[#timestamps + 1] = { node = node, text = value }
      end
    end
  end

  if #timestamps == 0 then
    return ""
  end
  if #timestamps > 1 then
    error("Multiple event timestamps found. Keep one timestamp or one explicit Org date range.", 0)
  end
  local timestamp = timestamps[1]
  local plan = fold_node:field("plan")[1]
  if not plan or timestamp.node:parent():parent() ~= plan then
    error("Place the event timestamp directly below its headline.", 0)
  end
  return table.concat({ text("headline"), timestamp.text, text("property_drawer"), text("body") }, "\n")
end

-- Create an exporter function for a given khalorg command.
---@param khalorg_command string[]
---@return function
M.make_exporter = function(khalorg_command)
  assert(type(khalorg_command) == "table" and #khalorg_command > 0, "Use an argument array for the khalorg command")
  return function()
    local ok, org_agenda_item = pcall(M.get_item_in_fold_under_cursor)
    if not ok then
      export_error({ tostring(org_agenda_item) })
      return
    end
    if org_agenda_item == "" then
      export_error({ "No agenda item found under the cursor" })
      return
    else
      return process.run(khalorg_command, org_agenda_item, function(result)
        if result.code == 0 then
          export_success(vim.split(result.stdout or "", "\n", { plain = true }))
        else
          export_error(vim.split(result.stderr or "", "\n", { plain = true }))
        end
      end)
    end
  end
end

local function action(command, edit_dates)
  local argv = { "khalorg", command }
  if edit_dates then
    argv[#argv + 1] = "--edit-dates"
  end
  argv[#argv + 1] = config.values.calendar
  return M.make_exporter(argv)()
end

-- These functions also accept the unused callback from org_custom_exports.
function M.new()
  return action("new")
end

function M.edit()
  return action("edit")
end

function M.delete()
  return action("delete")
end

function M.edit_all()
  return action("edit", true)
end

M.edit_props = M.edit

---@param opts? table
function M.setup(opts)
  M.calendar = config.setup(opts).calendar
end

return M
