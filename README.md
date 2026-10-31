# nvim-khalorg

A Neovim interface for [khalorg](https://github.com/BartSte/khalorg) and the khal calendar.
Export one Org event to create, edit, or delete its calendar event.
Commands run asynchronously without a shell. Event text passes directly through stdin.

![Neovim demo](https://github.com/BartSte/khalorg/blob/main/demo/neovim-plugin.gif?raw=true)

## Requirements

- Neovim 0.11 or later.
- [nvim-orgmode](https://github.com/nvim-orgmode/orgmode) with its Org Tree-sitter parser installed.
- `khalorg` and `khal` available on `PATH`, with a configured khal calendar.

Orgmode installs its parser during setup. A separate nvim-treesitter installation is optional.

## Installation and configuration

Install `nvim-orgmode/orgmode` and `BartSte/nvim-khalorg` with your plugin manager.
Then configure both plugins:

```lua
local khalorg = require('khalorg')
khalorg.setup({ calendar = 'my_calendar' })

require('orgmode').setup({
  org_custom_exports = {
    n = { label = 'Add a khal event', action = khalorg.new },
    e = { label = 'Edit a khal event', action = khalorg.edit },
    E = { label = 'Edit a khal event and its dates', action = khalorg.edit_all },
    d = { label = 'Delete a khal event', action = khalorg.delete },
  },
})
```

`setup()` and `setup({})` both select the `default` calendar.
Calendar names must contain at least one non-space character.
The public functions also work before setup and use the default calendar.

## Usage

Place the cursor inside an Org event. Open the orgmode export menu with `<leader>oe` and select an action.
You can also call a function directly:

```vim
:lua require('khalorg').new()
:lua require('khalorg').edit()
:lua require('khalorg').edit_all()
:lua require('khalorg').delete()
```

Place one active event timestamp directly below the headline. A single `SCHEDULED` or `DEADLINE` timestamp also works.
Explicit ranges such as `<2030-01-01 Tue>--<2030-01-02 Wed>` remain intact. Repeaters remain intact.
The plugin rejects multiple independent active timestamps, including separate scheduled and deadline dates.
Inactive timestamps do not define the event dates. Child sections do not enter the export.

Edits and deletion require the existing event's `UID` property.
`edit()` updates properties and the description. `edit_all()` also updates dates and recurrence.
Deletion removes the whole recurring series. Khalorg does not support deletion of one occurrence.

## Lua API

| Function | Action |
| --- | --- |
| `setup(opts)` | Apply the configuration. The default calendar is `default`. |
| `new()` | Create the event under the cursor. |
| `edit()` | Update event properties and the description. |
| `edit_props()` | Alias for `edit()`. |
| `edit_all()` | Update event properties, description, dates, and recurrence. |
| `delete()` | Delete the calendar event under the cursor. |
| `get_item_in_fold_under_cursor()` | Return the selected event text, or an empty string without an active timestamp. |
| `make_exporter(argv)` | Create a custom action from an argument array. |

Public actions work directly and through `org_custom_exports`. No exporter callback is required.
Existing callback arguments from orgmode are accepted and ignored.

Custom commands must use argument arrays:

```lua
local show_event = require('khalorg').make_exporter({ 'cat' })
show_event()
```

Migration: replace shell strings such as `'khalorg new work'` with `{ 'khalorg', 'new', 'work' }`.
Shell pipes and substitutions are not supported.

## Troubleshooting

Report plugin errors at [nvim-khalorg issues](https://github.com/BartSte/nvim-khalorg/issues).
Report calendar conversion errors at [khalorg issues](https://github.com/BartSte/khalorg/issues).

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the regression test command and contribution steps.

## License

Distributed under the [MIT License](./LICENSE).
