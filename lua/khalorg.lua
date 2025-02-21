local ts_utils = require("orgmode.utils.treesitter")

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
---@return string
M.get_headline_and_timestamps_in_fold_under_cursor = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local fold_node = get_fold_node("section")

  -- Get fold limits to remove nested folds in `query:iter_matches` bellow
  local query_fold_limits = ts_utils.get_query([[
  ((section) @section (#offset! @section))
  ]])

  -- local startfold, endfold = vim.treesitter.get_node_range(node)
  local startfold, endfold
  local i = 1
  for _, captures, metadata in query_fold_limits:iter_matches(fold_node, bufnr) do
    local range = metadata[1].range

    if i == 1 then
      startfold = range[1]
      endfold = range[3]
    elseif range[1] < endfold then
      endfold = range[1]
    end
    i = i + 1
  end

  local query = ts_utils.get_query([[
  (section
    headline: (headline
                tags: (tag_list)? @tags) @headline
    plan: (plan
            (entry
              name: (entry_name)? @name
              (timestamp
                repeat: (repeat)? @repeat) @timestamp))
    property_drawer: (property_drawer)? @properties
    (body)? @body)
  ]])

  -- This is the text containing the timestamps and the headline
  local properties, timestamps, headline = nil
  for _, captures, metadata in query:iter_matches(fold_node, bufnr, startfold, endfold) do
    if headline == nil then
      headline = vim.treesitter.get_node_text(captures[2], bufnr)
    end

    if timestamps ~= nil then
      -- Concatenate the timestamps with '--' when there are multiple
      timestamps = timestamps .. "--" .. vim.treesitter.get_node_text(captures[5], bufnr)
    else
      timestamps = vim.treesitter.get_node_text(captures[5], bufnr)
    end

    -- The @properties capture is optional
    if properties == nil and captures[6] then
      properties = vim.treesitter.get_node_text(captures[6], bufnr)
    end
  end

  if timestamps and headline then
    return table.concat({ headline, timestamps, properties or "" }, "\n")
  else
    return ""
  end
end

-- Create an exporter function for a given khalorg command.
---@param khalorg_command string
---@return function
M.make_exporter = function(khalorg_command)
  return function(exporter)
    local org_agenda_item = M.get_headline_and_timestamps_in_fold_under_cursor()
    if org_agenda_item == "" then
      export_error({ "No agenda item found under the cursor" })
      return
    else
      local cmd = 'echo "' .. org_agenda_item .. '" | ' .. khalorg_command
      return exporter(cmd, "", export_success, export_error)
    end
  end
end

-- Setup khalorg.
---@param opts table {calendar: string}
M.setup = function(opts)
  M.calendar = opts.calendar
  M.new = M.make_exporter("khalorg new " .. M.calendar)
  M.edit = M.make_exporter("khalorg edit " .. M.calendar)
  M.delete = M.make_exporter("khalorg delete " .. M.calendar)
  M.edit_all = M.make_exporter("khalorg edit --edit-dates " .. M.calendar)
end

return M
