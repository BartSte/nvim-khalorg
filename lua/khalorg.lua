local ts_utils = require("orgmode.utils.treesitter")
local process = require("khalorg.process")
local config = require("khalorg.config")

---@class Khalorg
---@field calendar string
---@field delete function
---@field edit function
---@field edit_all function
---@field get_fold_node function
---@field get_headline_and_timestamps_in_fold_under_cursor function
---@field make_exporter function
---@field new function
---@field setup function
local M = {}

local function get_fold_node(node_type)
  local node = ts_utils.get_node_at_cursor()
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
  local query = ts_utils.get_query("(timestamp) @timestamp")
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

-- Setup khalorg.
---@param opts? table {calendar: string}
M.setup = function(opts)
  M.calendar = config.setup(opts).calendar
  M.new = M.make_exporter({ "khalorg", "new", M.calendar })
  M.edit = M.make_exporter({ "khalorg", "edit", M.calendar })
  M.delete = M.make_exporter({ "khalorg", "delete", M.calendar })
  M.edit_all = M.make_exporter({ "khalorg", "edit", "--edit-dates", M.calendar })
end

return M
