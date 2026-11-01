local M = {}

function M.setup()
  local function sync(args, dry_run)
    if #args.fargs > 1 then
      require("khalorg.ui").error("Use one calendar name. Escape spaces with a backslash.")
      return
    end
    local opts = { calendar = args.fargs[1] }
    if dry_run then
      require("khalorg").sync_dry_run(opts)
    else
      require("khalorg").sync(opts)
    end
  end
  local options = { nargs = "*", complete = function() return require("khalorg.config").names() end, force = true }
  vim.api.nvim_create_user_command("KhalorgSync", function(args) sync(args, false) end, options)
  vim.api.nvim_create_user_command("KhalorgSyncDryRun", function(args) sync(args, true) end, options)
  local function list(args, import)
    if #args.fargs > 3 then
      require("khalorg.ui").error("Use [calendar] [start] [stop] for list and import")
      return
    end
    require("khalorg.list").run({ calendar = args.fargs[1], start = args.fargs[2], stop = args.fargs[3], import = import })
  end
  local list_options = {
    nargs = "*", force = true,
    complete = function(_, line)
      if #vim.split(line, "%s+") <= 2 then
        return require("khalorg.config").names()
      end
      return { "today", "tomorrow", "7d", "30d", "90d" }
    end,
  }
  vim.api.nvim_create_user_command("KhalorgList", function(args) list(args, false) end, list_options)
  vim.api.nvim_create_user_command("KhalorgImport", function(args) list(args, true) end, list_options)
  vim.api.nvim_create_user_command("KhalorgCalendar", function()
    vim.ui.select(require("khalorg.config").names(), { prompt = "Calendar to list" }, function(name)
      if name then
        require("khalorg").list({ calendar = name })
      end
    end)
  end, { force = true })
end

return M
