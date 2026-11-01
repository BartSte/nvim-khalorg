local M = {}
local serial = 0

function M.error(message)
  vim.notify("Khalorg: " .. tostring(message), vim.log.levels.ERROR)
end

function M.result(title, result)
  serial = serial + 1
  local lines = { "Khalorg " .. title, "Exit code: " .. result.code, "" }
  for _, text in ipairs({ result.stdout or "", result.stderr or "" }) do
    if text ~= "" then
      vim.list_extend(lines, vim.split(text, "\n", { plain = true }))
    end
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, "khalorg://results/" .. serial)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "log"
  vim.bo[bufnr].modifiable = false
  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, bufnr)
  return bufnr
end

return M
