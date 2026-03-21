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

let s:fzf_checked = 0
let s:fzf_ok = 0
function! s:VersionAtLeast(version, required) abort
  let l:v = map(split(a:version, '\.'), 'str2nr(v:val)')
  let l:r = map(split(a:required, '\.'), 'str2nr(v:val)')
  for l:i in range(0, 2)
    if get(l:v, l:i, 0) > get(l:r, l:i, 0)
      return 1
    endif
    if get(l:v, l:i, 0) < get(l:r, l:i, 0)
      return 0
    endif
  endfor
  return 1
endfunction

function! s:CheckFzf() abort
  if !s:CheckExecutable('fzf')
    return 0
  endif
  if s:fzf_checked
    return s:fzf_ok
  endif
  let s:fzf_checked = 1
  let l:raw = system('fzf --version')
  let l:version = matchstr(l:raw, '\v\d+\.\d+\.\d+')
  if empty(l:version)
    echohl WarningMsg | echo 'vim-bfg: failed to detect fzf version (need >= 0.51.0)' | echohl None
    return 0
  endif
  if !s:VersionAtLeast(l:version, '0.51.0')
    echohl WarningMsg | echo 'vim-bfg: requires fzf >= 0.51.0 (found ' . l:version . ')' | echohl None
    return 0
  endif
  let s:fzf_ok = 1
  return 1
endfunction

function! s:RestoreWindowLocalOptions(ctx) abort
  if has_key(a:ctx, 'prior_statusline')
    let &l:statusline = a:ctx.prior_statusline
  endif
  if exists('&winbar') && has_key(a:ctx, 'prior_winbar')
    let &l:winbar = a:ctx.prior_winbar
  endif
endfunction

function! s:fzf(opts, source, sink, label) abort
  if !s:CheckFzf()
    return
  endif
  if has('nvim')
    call s:fzf_nvim(a:opts, a:source, a:sink, a:label)
    return
  endif
  call s:fzf_vim(a:opts, a:source, a:sink, a:label)
endfunction

function! s:fzf_vim(opts, source, sink, label) abort
  if !exists('*term_start')
    echohl WarningMsg | echo 'bfg: Vim terminal support is required' | echohl None
    return
  endif
  let l:shell_cmdflag = join(split(&shellcmdflag), ' ')
  let l:with_shell = l:shell_cmdflag ==# '' ? &shell : (&shell . ' ' . l:shell_cmdflag)
  let l:cmd = 'fzf --with-shell ' . shellescape(l:with_shell)
  for l:pair in a:opts
    if len(l:pair) > 1
      let l:cmd .= ' ' . l:pair[0] . ' ' . shellescape(l:pair[1])
      continue
    endif
    let l:cmd .= ' ' . l:pair[0]
  endfor
  let l:tmpout = tempname()
  let l:tmperr = tempname()
  let l:tmpin = ''
  if type(a:source) is# v:t_list
    let l:tmpin = tempname()
    call writefile(a:source, l:tmpin)
    let l:fullcmd = 'cat ' . shellescape(l:tmpin) . ' | ' . l:cmd . ' > ' . shellescape(l:tmpout) . ' 2> ' . shellescape(l:tmperr)
  else
    let l:fullcmd = a:source . ' | ' . l:cmd . ' > ' . shellescape(l:tmpout) . ' 2> ' . shellescape(l:tmperr)
  endif
  let l:ctx = { 'winid': win_getid(), 'bufnr': bufnr('%'), 'view': winsaveview(), 'tmpin': l:tmpin, 'tmpout': l:tmpout, 'tmperr': l:tmperr, 'sink': a:sink, 'term_bufnr': -1, 'scratch_bufnr': -1, 'prior_statusline': &l:statusline }
  if exists('&winbar')
    let l:ctx.prior_winbar = &l:winbar
  endif
  silent keepalt enew
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  let &l:statusline = 'bfg ' . a:label
  let l:ctx.scratch_bufnr = bufnr('%')
  let l:argv = [&shell] + split(&shellcmdflag) + [l:fullcmd]
  let l:term_buf = term_start(l:argv, {'curwin': 1, 'term_name': 'bfg://' . a:label, 'exit_cb': function('s:OnFzfExitVim', [l:ctx]), 'env': {'SHELL': &shell}})
  if l:term_buf == 0
    if !empty(get(l:ctx, 'tmpin', ''))
      call delete(l:ctx.tmpin)
    endif
    call delete(l:ctx.tmpout)
    call delete(l:ctx.tmperr)
    if bufexists(l:ctx.bufnr)
      execute 'silent buffer' l:ctx.bufnr
      call winrestview(l:ctx.view)
    endif
    if win_gotoid(l:ctx.winid)
      call s:RestoreWindowLocalOptions(l:ctx)
    endif
    if l:ctx.scratch_bufnr > 0 && bufexists(l:ctx.scratch_bufnr)
      execute 'silent! bwipeout!' l:ctx.scratch_bufnr
    endif
    echohl WarningMsg | echo 'bfg: failed to start terminal' | echohl None
    return
  endif
  let l:ctx.term_bufnr = l:term_buf
  if l:ctx.scratch_bufnr > 0 && l:ctx.scratch_bufnr != l:term_buf && bufexists(l:ctx.scratch_bufnr)
    execute 'silent! bwipeout!' l:ctx.scratch_bufnr
  endif
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  startinsert
endfunction

function! s:fzf_nvim(opts, source, sink, label) abort
  let l:shell_cmdflag = join(split(&shellcmdflag), ' ')
  let l:with_shell = l:shell_cmdflag ==# '' ? &shell : (&shell . ' ' . l:shell_cmdflag)
  let l:cmd = 'fzf --with-shell ' . shellescape(l:with_shell)
  for l:pair in a:opts
    if len(l:pair) > 1
      let l:cmd .= ' ' . l:pair[0] . ' ' . shellescape(l:pair[1])
      continue
    endif
    let l:cmd .= ' ' . l:pair[0]
  endfor
  let l:tmpout = tempname()
  let l:tmperr = tempname()
  let l:tmpin = ''
  if type(a:source) is# v:t_list
    let l:tmpin = tempname()
    call writefile(a:source, l:tmpin)
    let l:fullcmd = 'cat ' . shellescape(l:tmpin) . ' | ' . l:cmd . ' > ' . shellescape(l:tmpout) . ' 2> ' . shellescape(l:tmperr)
  else
    let l:fullcmd = a:source . ' | ' . l:cmd . ' > ' . shellescape(l:tmpout) . ' 2> ' . shellescape(l:tmperr)
  endif
  let l:ctx = { 'winid': win_getid(), 'bufnr': bufnr('%'), 'view': winsaveview(), 'tmpin': l:tmpin, 'tmpout': l:tmpout, 'tmperr': l:tmperr, 'sink': a:sink, 'prior_statusline': &l:statusline }
  if exists('&winbar')
    let l:ctx.prior_winbar = &l:winbar
  endif
  silent keepalt enew
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  if exists('&winbar')
    let &l:winbar = ''
  endif
  let &l:statusline = 'bfg ' . a:label
  execute 'silent! file ' . fnameescape('bfg://' . a:label)
  let l:ctx.term_bufnr = bufnr('%')
  let l:argv = [&shell] + split(&shellcmdflag) + [l:fullcmd]
  let l:job = termopen(l:argv, {'on_exit': function('s:OnFzfExit', [l:ctx]), 'env': {'SHELL': &shell}})
  if l:job == 0
    if !empty(get(l:ctx, 'tmpin', ''))
      call delete(l:ctx.tmpin)
    endif
    call delete(l:ctx.tmpout)
    call delete(l:ctx.tmperr)
    if win_gotoid(l:ctx.winid)
      if bufexists(l:ctx.bufnr)
        execute 'silent buffer' l:ctx.bufnr
        call winrestview(l:ctx.view)
      endif
      call s:RestoreWindowLocalOptions(l:ctx)
    endif
    if bufexists(get(l:ctx, 'term_bufnr', -1))
      execute 'silent! bwipeout!' l:ctx.term_bufnr
    endif
    echohl WarningMsg | echo 'bfg: failed to start terminal' | echohl None
    redraw!
    return
  endif
  startinsert
endfunction

function! s:OnFzfExit(ctx, jobid, exit_code, event) abort
  let a:ctx.exit_code = a:exit_code
  call nvim_input("\<C-\\>\<C-n>")
  call timer_start(0, function('s:FinalizeFzf', [a:ctx]))
endfunction

function! s:OnFzfExitVim(ctx, job, exit_code) abort
  let a:ctx.exit_code = a:exit_code
  call feedkeys("\<C-\\>\<C-n>", 'n')
  call timer_start(0, function('s:FinalizeFzf', [a:ctx]))
endfunction

function! s:FinalizeFzf(ctx, timer) abort
  if !empty(get(a:ctx, 'tmpin', ''))
    call delete(a:ctx.tmpin)
  endif
  let l:err = []
  try
    let l:err = readfile(a:ctx.tmperr)
  catch
  endtry
  let l:output = []
  let l:output_ok = 1
  try
    let l:output = readfile(a:ctx.tmpout)
  catch
    let l:output_ok = 0
  endtry
  call delete(a:ctx.tmpout)
  call delete(a:ctx.tmperr)
  if bufexists(get(a:ctx, 'term_bufnr', -1))
    execute 'silent! bwipeout!' a:ctx.term_bufnr
  endif
  if !win_gotoid(a:ctx.winid)
    return
  endif
  if bufexists(a:ctx.bufnr)
    execute 'silent buffer' a:ctx.bufnr
    call winrestview(a:ctx.view)
  endif
  call s:RestoreWindowLocalOptions(a:ctx)
  let l:exit_code = get(a:ctx, 'exit_code', -1)
  if !l:output_ok
    let l:err_text = empty(l:err) ? '' : (': ' . join(l:err, "\n"))
    echohl WarningMsg | echo 'bfg: fzf no output, exit code: ' . l:exit_code . l:err_text | echohl None
    redraw!
    return
  endif
  if l:exit_code != 0 && l:exit_code != 1 && l:exit_code != 130
    let l:err_text = empty(l:err) ? '' : (': ' . join(l:err, "\n"))
    echohl WarningMsg | echo 'bfg: fzf error, exit code: ' . l:exit_code . l:err_text | echohl None
    redraw!
    return
  endif
  if l:exit_code != 0
    redraw!
    return
  endif
  call a:ctx.sink(l:output)
  redraw!
endfunction

function! s:HasGlobChars(pattern) abort
  return a:pattern =~# '\v[\*\?\[]'
endfunction

function! s:AppendRgIgnore(cmd, patterns) abort
  let l:cmd = a:cmd
  let l:seen = {}
  for l:pattern in a:patterns
    if s:HasGlobChars(l:pattern)
      if has_key(l:seen, l:pattern)
        continue
      endif
      let l:cmd .= ' -g ' . shellescape('!' . l:pattern)
      let l:seen[l:pattern] = 1
      continue
    endif
    let l:p = l:pattern
    if l:p =~# '/$'
      let l:p = l:p[:-2]
    endif
    for l:g in [l:p, l:p . '/**']
      if has_key(l:seen, l:g)
        continue
      endif
      let l:cmd .= ' -g ' . shellescape('!' . l:g)
      let l:seen[l:g] = 1
    endfor
  endfor
  return l:cmd
endfunction

function! bfg#Grep() abort
  if !s:CheckExecutable('rg')
    return
  endif
  let l:cmd = 'rg --color=always --trim --max-columns=1024 --max-columns-preview --column --line-number --no-heading --smart-case --hidden'
  let l:cmd = s:AppendRgIgnore(l:cmd, g:bfg_grep_ignore)
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
  call s:fzf(l:opts, l:cmd_source, function('s:GrepSink'), 'Grep')
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
  if !s:CheckExecutable('rg')
    return
  endif
  let l:cmd = 'rg --files --hidden'
  let l:cmd = s:AppendRgIgnore(l:cmd, g:bfg_find_ignore)
  let l:cmd_source = l:cmd
  let l:opts = [
        \ ['--ansi'],
        \ ['--multi'],
        \ ['--prompt', 'Find> '],
        \ ['--reverse'],
        \ ['--scheme', 'default'],
        \ ['--bind', 'alt-a:select-all'],
        \ ['--bind', 'alt-d:deselect-all'],
        \ ]
  call s:fzf(l:opts, l:cmd_source, function('s:FindSink'), 'Find')
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
        \ ['--scheme', 'default'],
        \ ['--with-nth', '2..'],
        \ ]
  call s:fzf(l:opts, l:buffers, function('s:BufferSink'), 'Buffer')
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
