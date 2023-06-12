local orgmode = require('orgmode')
local khalorg = require('lua.khalorg')

local custom_exports = {
    e = {
        label = 'Echo',
        action = khalorg.make_exporter('echo')
    },
}

orgmode.setup_ts_grammar()

orgmode.setup({
  org_custom_exports = custom_exports
})

khalorg.setup({calendar=''})

local function print_fold()
  print(khalorg.get_fold_under_cursor())
end

vim.keymap.set('n', '<leader>pf', print_fold)
