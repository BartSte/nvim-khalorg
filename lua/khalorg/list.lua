local config = require("khalorg.config")
local ui = require("khalorg.ui")
local M = {}
local serial = 0

local function preview(text, calendar)
  serial = serial + 1
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(bufnr, "khalorg://list/" .. serial .. "/" .. calendar)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[bufnr].filetype = "org"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modified = false
  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, bufnr)
  return bufnr
end

local function import(file, text)
  -- Exclusive creation also protects files created while the CLI runs.
  local fd, err = vim.uv.fs_open(file, "wx", 384)
  if not fd then
    return nil, "Cannot create " .. file .. ": " .. tostring(err)
  end
  local offset = 0
  while offset < #text do
    local written, reason = vim.uv.fs_write(fd, text:sub(offset + 1), offset)
    if not written or written == 0 then
      vim.uv.fs_close(fd)
      vim.uv.fs_unlink(file)
      return nil, "Cannot write " .. file .. ": " .. tostring(reason)
    end
    offset = offset + written
  end
  vim.uv.fs_close(fd)
  return true
end

local function prepare(opts)
  local target = config.resolve(opts)
  local range = config.sync_options(target, opts)
  if opts.import then
    assert(target.org_file, "Configure an org_file or pass org_file for import")
    assert(not vim.uv.fs_stat(target.org_file), "Import does not overwrite existing files. Use sync for an existing calendar file.")
    local snapshots, err = require("khalorg.buffers").snapshot(target.org_file)
    assert(snapshots, err)
    assert(vim.fn.isdirectory(vim.fs.dirname(target.org_file)) == 1, "The Org file directory does not exist")
  end
  local argv = { target.executable, "list", "--", target.calendar, range.start, range.stop }
  return target, argv
end

function M.run(opts)
  opts = type(opts) == "table" and opts or {}
  local ok, target, argv = pcall(prepare, opts)
  if not ok then
    ui.error(target)
    return
  end
  local release, err = require("khalorg.lock").acquire(target)
  if not release then
    ui.error(err)
    return
  end
  return require("khalorg.process").run(argv, nil, function(result)
    local bufnr
    if result.code ~= 0 then
      ui.result("list failed", result)
    elseif opts.import then
      local snapshots, changed = require("khalorg.buffers").snapshot(target.org_file)
      local imported, reason
      if snapshots then
        imported, reason = import(target.org_file, result.stdout or "")
      else
        reason = changed
      end
      if imported then
        require("khalorg.buffers").reload(target.org_file, snapshots)
        vim.notify("Khalorg imported events into " .. target.org_file)
      else
        ui.error(reason)
        -- Keep fetched events available even when the target cannot be written.
        bufnr = preview(result.stdout or "", target.calendar)
      end
    else
      bufnr = preview(result.stdout or "", target.calendar)
    end
    release()
    if opts.on_complete then
      opts.on_complete(result, bufnr)
    end
  end)
end

return M
