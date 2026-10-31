local config = require("khalorg.config")
local ui = require("khalorg.ui")
local buffers = require("khalorg.buffers")
local M = {}

local function prepare(opts)
  local target = config.resolve(opts)
  target.org_file = target.org_file or vim.api.nvim_buf_get_name(0)
  assert(target.org_file ~= "", "Configure an org_file or open a named Org file before sync")
  target.org_file = config.path(target.org_file)
  assert(target.org_file:match("%.org$"), "Sync requires an .org file")
  assert(vim.fn.isdirectory(vim.fs.dirname(target.org_file)) == 1, "The Org file directory does not exist")
  local options = config.sync_options(target, opts)
  local snapshots, err = buffers.snapshot(target.org_file)
  assert(snapshots, err)
  local argv = { target.executable, "sync", "--start", options.start, "--stop", options.stop,
    "--conflict-resolution", options.conflict_resolution }
  for _, key in ipairs({ "edit_dates", "delete_on_sync", "dry_run" }) do
    if options[key] then
      argv[#argv + 1] = "--" .. key:gsub("_", "-")
    end
  end
  if options.state_dir then
    vim.list_extend(argv, { "--state-dir", config.path(options.state_dir) })
  end
  for _, tag in ipairs(options.filetags) do
    vim.list_extend(argv, { "--filetags", tag })
  end
  vim.list_extend(argv, { "--", target.calendar, target.org_file })
  return { target = target, options = options, snapshots = snapshots, argv = argv }
end

function M.run(opts)
  opts = type(opts) == "table" and opts or {}
  local ok, request = pcall(prepare, opts)
  if not ok then
    ui.error(request)
    return
  end
  local release, err = require("khalorg.lock").acquire(request.target)
  if not release then
    ui.error(err)
    return
  end
  return require("khalorg.capabilities").check(request.target, "sync", function(supported, reason)
    if not supported then
      release()
      ui.error(reason)
      return
    end
    -- The capability probe is asynchronous. Recheck saved changes before sync.
    local snapshots, changed = buffers.snapshot(request.target.org_file)
    if not snapshots then
      release()
      ui.error(changed)
      return
    end
    request.snapshots = snapshots
    require("khalorg.process").run(request.argv, nil, function(result)
      release()
      if not request.options.dry_run and vim.fn.filereadable(request.target.org_file) == 1 then
        -- A failing process can still have written the Org file.
        buffers.reload(request.target.org_file, request.snapshots)
      end
      ui.result(request.options.dry_run and "sync preview" or "sync", result)
      if opts.on_complete then
        opts.on_complete(result)
      end
    end)
  end)
end

return M
