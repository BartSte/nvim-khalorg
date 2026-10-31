local config = require("khalorg.config")
local M = {}

function M.for_file(file)
  local buffers = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if vim.api.nvim_buf_is_loaded(bufnr) and name ~= "" and config.path(name) == file then
      buffers[#buffers + 1] = bufnr
    end
  end
  return buffers
end

function M.snapshot(file)
  local snapshots = {}
  for _, bufnr in ipairs(M.for_file(file)) do
    if vim.bo[bufnr].modified then
      return nil, "Save changes to " .. file .. " before running Khalorg sync"
    end
    snapshots[bufnr] = vim.api.nvim_buf_get_changedtick(bufnr)
  end
  return snapshots
end

function M.reload(file, snapshots)
  for _, bufnr in ipairs(M.for_file(file)) do
    if vim.bo[bufnr].modified or (snapshots[bufnr] and snapshots[bufnr] ~= vim.api.nvim_buf_get_changedtick(bufnr)) then
      vim.notify("Khalorg updated " .. file .. " on disk. Buffer edits remain unchanged. Review the disk changes before saving.", vim.log.levels.WARN)
    else
      vim.api.nvim_buf_call(bufnr, function()
        local view = vim.fn.winsaveview()
        vim.cmd("silent edit")
        vim.fn.winrestview(view)
      end)
    end
  end
end

return M
