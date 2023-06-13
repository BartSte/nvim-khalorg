# README - nvim-khalorg

Plugin to interact with `khalorg`: an interface between the org mode and the
`khal` cli calendar.

## CONTENTS                                              

1. Introduction                                     
2. Installation                                     
3. Configuration                                    
4. Usage                                            
5. Functions                                        
6. Troubleshooting                                  
7. Contributing                                     
8. License                                          

## Introduction

The `nvim-khalorg` plugin sends folds in an org document to khalorg through
stdin. The functions are exposed through `nvim-orgmode` its custom export option.

## Installation

Install using your favorite plugin manager. For example packer:

```lua
use {'nvim-treesitter/nvim-treesitter'}
use {'nvim-orgmode/orgmode'}
use {'BartSte/nvim-khalorg'}
```

where `nvim-treesitter` and `nvim-orgmode` are required. Also, make sure you
installed `khalorg`, which can be found here: https://github.com/BartSte/khalorg

## Configuration

The following configuration options are available through the `khalorg.setup`
function:

- calendar: The name of the calendar to use (default: 'default').

Configuring `nvim-khalorg` can be done by placing the following in your
`init.lua`:

```lua
require('khalorg').setup({
    calendar = 'my_calendar'
})
```

where you need to replace `'my_calendar'` with the `khal` calendar you want to
use. You can add the export functions of `nvim-khalorg` to `nvim-orgmode` by
adding the following to your `init.lua`:

```lua
orgmode.setup_ts_grammar()
orgmode.setup({
    org_custom_exports = {
        n = { label = 'Add a new khal item', action = khalorg.new },
        d = { label = 'Delete a khal item', action = khalorg.delete },
        e = { label = 'Edit properties of a khal item', action = khalorg.edit },
        E = { label = 'Edit properties & dates of a khal item', action = khalorg.edit_all }
    }
})
```

## Usage

After configuring `nvim-khalorg` as is described above, you can access them
through `orgmode-org_export` (default mapping: `<leader>oe`). More information
can be found by running `:help orgmode-org_export`.

## Functions

The following functions are provided that send a fold in an org file to a
khalorg command through stdin:

- **khalorg.new()**: add a new item to khal.
- **khalorg.delete()**: delete a khal item.
- **khalorg.edit_props()**: edit properties of a khal item, the dates are not updated.
- **khalorg.edit_all()**: edit properties of a khal item together with the dates.

The following function is used to create the functions above and can be used to
make your own khalorg export functions.

- **khalorg.make_exporter(khalorg_command)**:  
Returns a function that, when called, does the following:
  1. Get the current fold.
  2. Get the start and end line of the fold.
  3. Get the text of the fold.
  4. Send the text of the fold to khalorg_command through stdin.

The example below shows how to use `khalorg.make_exporter` function to create
the `khalorg.new` function:

```lua
new = khalorg.make_exporter('khalorg new')
```

## Troubleshooting

If you encounter any issues, please report them on the issue tracker at:
[nvim-khalorg issues](https://github.com/BartSte/nvim-khalorg/issues)

If you think the issue arises from khalorg instead of nvim-khalorg, please
report them here: [khalorg issues](https://github.com/BartSte/khalorg/issues)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING](./CONTRIBUTING.md) for
more information.

## License

Distributed under the MIT License.
