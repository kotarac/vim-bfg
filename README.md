# vim-bfg

Small plugin that integrates `fzf`, `rg`, `fd`.

It requires `fzf`, `rg`, `fd` to be installed and available in your `PATH`.

## Installation

Use your favorite plugin manager.

## Commands

### `:Buffer`

Search through open buffers.

- `<Return>` switch to selected

### `:Find`

Find files using `fd`.

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

## Configuration

### `g:bfg_grep_ignore`

You can configure ignore patterns for `:Grep`.

Default: `['.git']`

Example:
```vim
let g:bfg_grep_ignore = ['.git', '**/__generated__/**']
```

### `g:bfg_find_ignore`

You can configure ignore patterns for `:Find`.

Default: `['.git']`

Example:
```vim
let g:bfg_find_ignore = ['.git', '**/__generated__/**']
```
