let s:exec_cache = {}
function! s:CheckExecutable(exe) abort
  if get(s:exec_cache, a:exe, 0)
    return 1
  endif

  if !executable(a:exe)
    echohl WarningMsg
    echo 'vim-bfg: ' . a:exe . ' is not installed or not in your PATH'
    echohl None
    return 0
  endif

  let s:exec_cache[a:exe] = 1
  return 1
endfunction

function! s:fzf(opts, source, sink) abort
  if !s:CheckExecutable('fzf')
    return
  endif

  let l:cmd = 'fzf'
  for l:pair in a:opts
    if len(l:pair) > 1
      let l:cmd .= ' ' . l:pair[0] . ' ' . shellescape(l:pair[1])
    else
      let l:cmd .= ' ' . l:pair[0]
    endif
  endfor

  let l:tmpout = tempname()

  if type(a:source) is# v:t_list
    let l:tmpin = tempname()
    call writefile(a:source, l:tmpin)
    try
      execute 'silent !' . 'cat ' . shellescape(l:tmpin) . ' | ' . l:cmd . ' > ' . shellescape(l:tmpout)
    finally
      call delete(l:tmpin)
    endtry
  else
    execute 'silent !' . a:source . ' | ' . l:cmd . ' > ' . shellescape(l:tmpout)
  endif

  try
    let l:output = readfile(l:tmpout)
  catch
    echohl WarningMsg | echo 'bfg: fzf no output, exit code: ' . v:shell_error | echohl None
    redraw!
    return
  finally
    call delete(l:tmpout)
  endtry

  if v:shell_error != 0 && v:shell_error != 1 && v:shell_error != 130
    echohl WarningMsg | echo 'bfg: fzf error, exit code: ' . v:shell_error | echohl None
    redraw!
    return
  endif

  if v:shell_error != 0
    redraw!
    return
  endif

  call a:sink(l:output)

  redraw!
endfunction


function! bfg#Grep() abort
  if !s:CheckExecutable('rg')
    return
  endif

  let l:cmd = 'rg --color=always --trim --max-columns=1024 --max-columns-preview --column --line-number --no-heading --smart-case --hidden'
  for l:pattern in g:bfg_grep_ignore
    let l:cmd .= ' -g ' . shellescape('\!' . l:pattern)
  endfor
  let l:cmd .= ' -- '
  let l:cmd_source = 'true'
  let l:cmd_reload = 'test -n {q} && ' . l:cmd . '{q} || true'
  let l:opts = [
        \ ['--ansi'],
        \ ['--delimiter', ':'],
        \ ['--disabled'],
        \ ['--multi'],
        \ ['--no-hscroll'],
        \ ['--nth', '4..'],
        \ ['--prompt', 'Grep> '],
        \ ['--query', ''],
        \ ['--reverse'],
        \ ['--scheme', 'default'],
        \ ['--bind', 'alt-a:select-all'],
        \ ['--bind', 'alt-d:deselect-all'],
        \ ['--bind', 'change:reload:' . l:cmd_reload],
        \ ['--bind', 'enter:accept'],
        \ ['--expect', 'alt-q'],
        \ ]
  call s:fzf(l:opts, l:cmd_source, function('s:GrepSink'))
endfunction

function! s:GrepSink(lines) abort
  if empty(a:lines)
    return
  endif
  if a:lines[0] ==# 'alt-q'
    call s:GrepPopulateQuickfix(a:lines[1:])
    return
  endif
  for l:line in a:lines[1:]
    call s:GrepOpenFile(l:line)
  endfor
endfunction

function! s:GrepOpenFile(line) abort
  let l:parts = matchlist(a:line, '^\(.\{-}\):\(\d\+\):\(\d\+\):.*$')
  if !empty(l:parts) && filereadable(l:parts[1])
    let l:file = l:parts[1]
    let l:lnum = l:parts[2]
    let l:col = l:parts[3]
    execute 'silent edit +' . l:lnum . ' ' . fnameescape(l:file)
    call cursor(l:lnum, l:col)
  else
    echohl WarningMsg | echo 'bfg: invalid selection: ' . a:line | echohl None
  endif
endfunction

function! s:GrepPopulateQuickfix(lines) abort
  let l:list = []
  for l:line in a:lines
    let l:parts = matchlist(l:line, '^\(.\{-}\):\(\d\+\):\(\d\+\):\(.*\)$')
    if !empty(l:parts) && filereadable(l:parts[1])
      call add(l:list, {
            \ 'filename': l:parts[1],
            \ 'lnum':     l:parts[2],
            \ 'col':      l:parts[3],
            \ 'text':     l:parts[4],
            \ })
    endif
  endfor
  if !empty(l:list)
    call setqflist(l:list)
    copen
  endif
endfunction


function! bfg#Find() abort
  if !s:CheckExecutable('fd')
    return
  endif

  let l:cmd = 'fd --color=auto --hidden --type f --type l'
  for l:pattern in g:bfg_find_ignore
    let l:cmd .= ' -E ' . shellescape(l:pattern)
  endfor
  let l:cmd_source = l:cmd
  let l:opts = [
        \ ['--ansi'],
        \ ['--multi'],
        \ ['--prompt', 'Find> '],
        \ ['--reverse'],
        \ ['--scheme', 'path'],
        \ ['--bind', 'alt-a:select-all'],
        \ ['--bind', 'alt-d:deselect-all'],
        \ ]
  call s:fzf(l:opts, l:cmd_source, function('s:FindSink'))
endfunction

function! s:FindSink(lines) abort
  if empty(a:lines)
    return
  endif
  for l:file in a:lines
    if filereadable(l:file)
      execute 'silent edit' fnameescape(l:file)
    endif
  endfor
endfunction


function! bfg#Buffer() abort
  let l:buffers = []
  for l:bufnr in filter(range(1, bufnr('$')), 'buflisted(v:val)')
    let l:name = fnamemodify(bufname(l:bufnr), ':.')
    if l:name ==# ''
      let l:name = '[No Name]'
    endif
    let l:flags = ''
    if l:bufnr == bufnr('%')
      let l:flags .= '%'
    elseif l:bufnr == bufnr('#')
      let l:flags .= '#'
    else
      let l:flags .= ' '
    endif
    if bufwinnr(l:bufnr) > -1
      let l:flags .= 'a'
    elseif bufloaded(l:bufnr)
      let l:flags .= 'h'
    else
      let l:flags .= ' '
    endif
    let l:flags .= getbufvar(l:bufnr, '&modified') ? '+' : ' '
    let l:display = printf('%4d %-4s %s', l:bufnr, l:flags, l:name)
    call add(l:buffers, printf('%d:%s', l:bufnr, l:display))
  endfor
  let l:opts = [
        \ ['--ansi'],
        \ ['--delimiter', ':'],
        \ ['--prompt', 'Buffer> '],
        \ ['--reverse'],
        \ ['--with-nth', '2..'],
        \ ]
  call s:fzf(l:opts, l:buffers, function('s:BufferSink'))
endfunction

function! s:BufferSink(lines) abort
  if empty(a:lines)
    return
  endif
  let l:line = a:lines[0]
  let l:bufnr = str2nr(split(l:line, ':')[0])
  if l:bufnr > 0
    execute 'silent buffer' l:bufnr
  endif
endfunction
