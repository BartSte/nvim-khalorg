# Contributing to nvim-khalorg

Thank you for considering contributing to the `nvim-khalorg` project! We welcome contributions from everyone.

## Getting Started

1. Fork the repository on GitHub.
2. Clone your forked repository (`git clone https://github.com/your_username/nvim-khalorg.git`).
3. Create a new branch (`git checkout -b my_branch_name`).
4. Make your changes.
5. Commit your changes (`git commit -am "Add some feature"`).
6. Push your changes to your forked repository (`git push origin my_branch_name`).
7. Create a pull request on GitHub.

## Code of Conduct

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms.

## Reporting Bugs

Run the regression tests with Neovim 0.11 or later:

```console
ORG_MODE_PATH=/path/to/orgmode nvim --headless -u NONE -l tests/run.lua
```

Use an orgmode checkout with its Org parser installed. CI builds the parser before the tests.

Run the integration suite against a separate khalorg installation with sync support:

```console
ORG_MODE_PATH=/path/to/orgmode KHALORG_INTEGRATION_BIN=/path/to/venv/bin/khalorg nvim --headless -u NONE -l tests/integration.lua
```

The suite creates a temporary khal configuration, calendar, database, log, and sync state.
It does not use your calendar configuration. CI installs a pinned khalorg commit in a separate virtual environment.

If you encounter any bugs or issues, please report them on the issue tracker at:

https://github.com/BartSte/nvim-khalorg/issues

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

