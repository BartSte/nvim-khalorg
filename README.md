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

### Multiple calendars

Map calendar names to Org files:

```lua
require('khalorg').setup({
  calendar = 'personal',
  executable = 'khalorg',
  calendars = {
    personal = { org_file = '~/org/personal.org' },
    work = { org_file = '~/org/work.org' },
  },
})
```

Actions select the calendar for the current file. Other files use the default `calendar` value.
An explicit Lua option overrides file selection: `require('khalorg').edit({ calendar = 'work' })`.
Each file can map to only one calendar. Paths expand `~` and resolve existing symbolic links.
Set `executable` to use a khalorg installation outside `PATH`. Paths with spaces are supported.

### UID writeback

By default, `new()` writes the created event's UID into the source buffer.
It fills an empty `UID` property or adds a property drawer. Save the buffer to retain the UID on disk.
Existing UIDs block creation. Use `edit()` for those events.

The plugin compares structured calendar reads before and after creation. It requires one new UID with the expected title and times.
Ambiguous matches leave the source unchanged. Calendar reads must succeed before creation starts.
If the source buffer changes during creation, the plugin reports the UID without altering the buffer.
Switching buffers or moving the cursor does not redirect writeback. Overlap protection also covers event edits and deletion.

Set `write_uid = false` in setup to disable this behavior. A call can also override it: `new({ write_uid = false })`.
UID writeback requires `khalorg list --format`. Titles or UIDs with tabs or newlines cannot use the structured lookup.
For those events, disable writeback and use list or sync to retrieve the UID.

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

## Sync

After setup, use `:KhalorgSync [calendar]` to synchronize a whole Org file with khal.
Use `:KhalorgSyncDryRun [calendar]` to preview changes. Calendar names support command completion.
The current file's mapping supplies the calendar and path. Without a mapping, sync uses the current named `.org` file.
Save the file before sync. Unsaved changes block the command.

Sync runs asynchronously and opens a results buffer. Overlapping operations for the same calendar or file are rejected.
Clean buffers reload after sync. Edits made during sync remain in the buffer, with a message about disk changes.

Configure global defaults or per-calendar overrides:

```lua
require('khalorg').setup({
  calendars = {
    work = {
      org_file = '~/org/work.org',
      sync = { start = 'today', stop = '30d' },
    },
  },
  sync = {
    start = 'today', stop = '90d',
    conflict_resolution = 'khal', -- or 'org'
    edit_dates = false,
    delete_on_sync = false,
    -- state_dir = '~/.local/share/khalorg',
    -- format = '* {title}\n{timestamps}\n:PROPERTIES:\n:UID: {uid}\n:END:\n{description}',
    filetags = {},
  },
})
```

Lua calls accept overrides: `require('khalorg').sync({ calendar = 'work', dry_run = true })`.
`sync_dry_run(opts)` always enables the preview. The `on_complete(result)` option receives the process result.
Khalorg owns UID matching, conflict resolution, and persistent sync state. Keep its state files between runs.
Deletion propagation is disabled by default. `delete_on_sync = true` propagates deletions between sources.
Preview changes before enabling this option. Sync can rewrite the Org file using khalorg's event format.

Sync requires a khalorg version with the `sync` command. The plugin detects missing support and reports an upgrade requirement.
Remote CalDAV synchronization still requires `vdirsyncer`.

## List and import

- `:KhalorgList [calendar] [start] [stop]` opens calendar events in a separate Org buffer.
- `:KhalorgCalendar` opens a calendar picker, then lists its events.
- `:KhalorgImport [calendar] [start] [stop]` writes events to a new mapped Org file.

The default range comes from the sync configuration (`today` through `90d`).
Calendar names and common date ranges support command completion. Escape spaces in command arguments with a backslash.
List buffers preserve the source file and unsaved edits. Save a list buffer with `:write /path/to/calendar.org`.
Import refuses to overwrite existing files. Use sync to update an existing calendar file.

Lua equivalents are `list(opts)` and `import(opts)`:

```lua
require('khalorg').list({ calendar = 'work', start = 'today', stop = '7d' })
require('khalorg').import({ calendar = 'work', org_file = '~/org/new-calendar.org' })
```

The optional `on_complete(result, bufnr)` callback receives the process result and any preview buffer.
The `format` option overrides the Org output template for list, import, and sync. Keep the UID field in sync templates.

## Lua API

| Function | Action |
| --- | --- |
| `setup(opts)` | Apply the configuration. The default calendar is `default`. |
| `new(opts)` | Create the event and write its UID into the source buffer. |
| `edit(opts)` | Update event properties and the description. |
| `edit_props()` | Alias for `edit()`. |
| `edit_all()` | Update event properties, description, dates, and recurrence. |
| `delete()` | Delete the calendar event under the cursor. |
| `get_item_in_fold_under_cursor()` | Return the selected event text, or an empty string without an active timestamp. |
| `make_exporter(argv)` | Create a custom action from an argument array. |
| `sync(opts)` | Synchronize a whole file with khal. |
| `sync_dry_run(opts)` | Preview sync changes. |
| `list(opts)` | Open calendar events in a separate Org buffer. |
| `import(opts)` | Create an Org file from calendar events. |

Public actions work directly and through `org_custom_exports`. No exporter callback is required.
Existing callback arguments from orgmode are accepted and ignored.
Event actions accept `calendar` and `on_complete(result)` options. `new()` also accepts `write_uid`.
With UID writeback, the callback receives `on_complete(result, uid)` after the final calendar read.

Custom commands must use argument arrays:

```lua
local show_event = require('khalorg').make_exporter({ 'cat' })
show_event()
```

Migration: replace shell strings such as `'khalorg new work'` with `{ 'khalorg', 'new', 'work' }`.
Shell pipes and substitutions are not supported.

## Troubleshooting

Run `:checkhealth khalorg` for dependency and configuration diagnostics.
The report checks Neovim, orgmode, the Org parser, khalorg CLI commands, khal, optional vdirsyncer, and mapped directories.
CLI capability probes have a five-second timeout. Health checks do not change calendar data.

Report plugin errors at [nvim-khalorg issues](https://github.com/BartSte/nvim-khalorg/issues).
Report calendar conversion errors at [khalorg issues](https://github.com/BartSte/khalorg/issues).

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the regression test command and contribution steps.

## License

Distributed under the [MIT License](./LICENSE).
