-- Append the repository and orgmode checkout to runtimepath before loading this file.
local khalorg = require("khalorg")
khalorg.setup()
require("orgmode").setup({
  org_custom_exports = {
    c = {
      label = "Show the event text",
      action = khalorg.make_exporter({ "cat" }),
    },
    n = { label = "Add a khal event", action = khalorg.new },
    e = { label = "Edit a khal event", action = khalorg.edit },
    E = { label = "Edit a khal event and its dates", action = khalorg.edit_all },
    d = { label = "Delete a khal event", action = khalorg.delete },
  },
})
