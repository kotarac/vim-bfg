# vim-bfg

Small plugin that integrates `fzf` and `rg`.

It requires a POSIX-compatible operating system and shell, with `fzf`, `rg`, `awk` installed and available in your `PATH`.

## Installation

Use your favorite plugin manager.

## Commands

### `:Buffer`

Search through open buffers.

- `<Return>` switch to selected

### `:Find`

Find files using `rg --files`.

- `<Return>` open selected
- `<Tab>` select one
- `<Alt-A>` select all
- `<Alt-D>` deselect all

### `:Grep`

Search for a pattern in files using `rg`.

- `<Return>` open selected
- `<Tab>` select one
- `<Alt-A>` select all
- `<Alt-D>` deselect all
- `<Alt-Q>` send selected to quickfix list

You can exclude result lines by adding one or more `!TERM` words to the query.
Example: `TODO !vendor/ !generated`

If the query contains only exclusions, no search is run and the result list will be empty.

To search for a literal term starting with `!`, escape it as `\!TERM`.
Example: `\!important`

## Configuration

### `g:bfg_grep_ignore`

You can configure ignore patterns for `:Grep`.

Patterns are ripgrep path globs (as used by `rg --glob`). bfg passes each pattern to `rg` as a negated glob by prefixing it with `!`.

Do not include a leading `!` in your patterns.

Default: `['.git/']`

Example:
```vim
let g:bfg_grep_ignore = ['.git/', '**/__generated__/**']
```

### `g:bfg_find_ignore`

You can configure ignore patterns for `:Find`.

Patterns are ripgrep path globs (as used by `rg --glob`). bfg passes each pattern to `rg` as a negated glob by prefixing it with `!`.

Do not include a leading `!` in your patterns.

Default: `['.git/']`

Example:
```vim
let g:bfg_find_ignore = ['.git/', '**/__generated__/**']
```
