local M = {}

function M.setup()
  local function sync(args, dry_run)
    local opts = { calendar = args.args ~= "" and args.args or nil }
    if dry_run then
      require("khalorg").sync_dry_run(opts)
    else
      require("khalorg").sync(opts)
    end
  end
  local options = { nargs = "?", complete = function() return require("khalorg.config").names() end, force = true }
  vim.api.nvim_create_user_command("KhalorgSync", function(args) sync(args, false) end, options)
  vim.api.nvim_create_user_command("KhalorgSyncDryRun", function(args) sync(args, true) end, options)
end

return M
