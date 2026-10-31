vim.opt.rtp:prepend(vim.fn.getcwd())
local orgmode = vim.env.ORG_MODE_PATH
if orgmode then
  vim.opt.rtp:append(orgmode)
end
for _, file in ipairs(vim.fn.glob("tests/spec/*_spec.lua", false, true)) do
  dofile(file)
end
print(string.format("Passed %d tests", require("tests.helpers").count))
