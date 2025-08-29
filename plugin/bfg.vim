if exists('g:loaded_bfg') || v:version < 700 || &compatible
  finish
endif
let g:loaded_bfg = 1

let g:bfg_find_ignore = get(g:, 'bfg_find_ignore', ['.git'])
let g:bfg_grep_ignore = get(g:, 'bfg_grep_ignore', ['.git'])


command! Grep call bfg#Grep()
command! Find call bfg#Find()
command! Buffer call bfg#Buffer()
