--This file servers a a minimal config file for testing. Ensure that the followin plugins are installed:
-- - nvim-treesitter
-- - orgmode.nvim
--Khalorg is not required as a plugin as it is loaded directly from the lua directory.
require 'nvim-treesitter.configs'.setup {
  highlight = {
    disable = { 'org', 'orgagenda' },
    additional_vim_regex_highlighting = { 'org', 'orgagenda' }
  },
}

-- Reset the orgmode and khalorg modules to ensure that the modules are reloaded.
package.loaded['orgmode'] = nil
package.loaded['lua.khalorg'] = nil
local orgmode = require('orgmode')
local khalorg = require('lua.khalorg')

khalorg.setup({ calendar = '' })
orgmode.setup_ts_grammar()

--An echo export is added to test if the make_exporter function works properly.
orgmode.setup({
  org_custom_exports = {
    c = {
      label = 'Let the agenda item pass through.',
      action = khalorg.make_exporter('cat')
    }
  }
})
