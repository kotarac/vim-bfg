if exists('g:loaded_bfg') || &compatible
  finish
endif
if !has('nvim') && (v:version < 800 || !has('terminal') || !has('timers') || !exists('*win_getid') || !exists('*win_gotoid'))
  echohl WarningMsg | echo 'vim-bfg: requires Vim 8.0+ with +terminal +timers' | echohl None
  finish
endif
let g:loaded_bfg = 1
let g:bfg_find_ignore = get(g:, 'bfg_find_ignore', ['.git'])
let g:bfg_grep_ignore = get(g:, 'bfg_grep_ignore', ['.git'])
command! Grep call bfg#Grep()
command! Find call bfg#Find()
command! Buffer call bfg#Buffer()
