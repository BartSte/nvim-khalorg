local ts_utils = require('orgmode.utils.treesitter')

-- Module table.
-- @field calendar string
-- @field new function
-- @field edit function
-- @field delete function
-- @field edit_all function
-- @field get_fold_under_cursor function
-- @field make_exporter function
-- @field setup function
local M = {}

-- Get the range of the fold under the cursor of a given type.
-- @param node_type string
-- @return {number, number} startfold, endfold
local function get_fold_range_at_cursor(node_type)
  local node = ts_utils.get_node_at_cursor()
  while node and node:type() ~= node_type do
    node = node:parent()
  end
  if node == nil then
    error('No fold found under the cursor')
  else
    local startfold, _, endfold, _ = vim.treesitter.get_node_range(node)
    return { startfold, endfold }
  end
end

-- Print the output of a successful export.
--@param output string[]
local function export_success(output)
  print('Khalorg export successful')
  vim.api.nvim_echo({ { table.concat(output, '\n') } }, true, {})
end

-- Print the error message of a failed export.
--@param err string[]
local function export_error(err)
  print('Khalorg export failed')
  vim.api.nvim_echo({ { table.concat(err, '\n'), 'ErrorMsg' } }, true, {})
end

-- Get the text of the fold under the cursor. If no fold is found, return an empty string.
-- @return string
M.get_fold_under_cursor = function()
  local status, result = pcall(function() return get_fold_range_at_cursor('section') end)
  if status then
    local lines = vim.api.nvim_buf_get_lines(0, result[1], result[2], true)
    return table.concat(lines, '\n')
  else
    return ''
  end
end

-- Create an exporter function for a given khalorg command.
-- @param khalorg_command string
-- @return function
M.make_exporter = function(khalorg_command)
  return function(exporter)
    local org_agenda_item = M.get_fold_under_cursor()
    if org_agenda_item == '' then
      export_error({ 'No agenda item found under the cursor' })
      return
    else
      local cmd = "echo \"" .. org_agenda_item .. "\" | " .. khalorg_command
      return exporter(cmd, '', export_success, export_error)
    end
  end
end

-- Setup khalorg.
-- @param opts table {calendar: string}
M.setup = function(opts)
  M.calendar = opts.calendar
  M.new = M.make_exporter('khalorg new ' .. M.calendar)
  M.edit = M.make_exporter('khalorg edit ' .. M.calendar)
  M.delete = M.make_exporter('khalorg delete ' .. M.calendar)
  M.edit_all = M.make_exporter('khalorg edit --edit-dates ' .. M.calendar)
end

return M
