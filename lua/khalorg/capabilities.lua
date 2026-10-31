local M = {}

function M.check(target, command, callback)
  return require("khalorg.process").run({ target.executable, command, "--help" }, nil, function(result)
    if result.code == 0 then
      callback(true)
    else
      callback(false, "The khalorg executable does not support " .. command .. ". Install a version with this command.\n" .. (result.stderr or ""))
    end
  end)
end

return M
