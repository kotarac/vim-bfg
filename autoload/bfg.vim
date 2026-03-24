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

function! s:EscapeBangForShell(cmd) abort
  if type(a:cmd) isnot# v:t_string
    return ''
  endif
  let l:cmd = substitute(a:cmd, '\\\@<!!', '\\!', 'g')
  let l:cmd = substitute(l:cmd, '\\\@<!%', '\\%', 'g')
  return substitute(l:cmd, '\\\@<!#', '\\#', 'g')
endfunction

function! s:fzf(opts, source, sink) abort
  if !s:CheckExecutable('fzf')
    return
  endif
  let l:source_type = type(a:source)
  if l:source_type isnot# v:t_list && l:source_type isnot# v:t_string
    echohl WarningMsg | echo 'bfg: invalid source type' | echohl None
    return
  endif
  if l:source_type is# v:t_string && a:source =~# '^\s*$'
    echohl WarningMsg | echo 'bfg: empty source command' | echohl None
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
  if l:source_type is# v:t_list
    let l:tmpin = tempname()
    call writefile(a:source, l:tmpin)
    try
      let l:shell_cmd = 'cat ' . shellescape(l:tmpin) . ' | ' . l:cmd . ' > ' . shellescape(l:tmpout)
      execute 'silent ! ' . s:EscapeBangForShell(l:shell_cmd)
    finally
      call delete(l:tmpin)
    endtry
  else
    let l:shell_cmd = a:source . ' | ' . l:cmd . ' > ' . shellescape(l:tmpout)
    execute 'silent ! ' . s:EscapeBangForShell(l:shell_cmd)
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
  if !s:CheckExecutable('awk')
    return
  endif
  let l:cmd = 'rg --color=always --trim --max-columns=1024 --max-columns-preview --column --line-number --no-heading --smart-case --hidden'
  for l:pattern in g:bfg_grep_ignore
    if type(l:pattern) isnot# v:t_string || l:pattern ==# '' || l:pattern ==# '!' || l:pattern[0] ==# '!'
      continue
    endif
    let l:cmd .= ' -g ' . shellescape('!' . l:pattern)
  endfor
  let l:cmd .= ' -- '
  let l:cmd_source = 'true'
  let l:cmd_build = 'q=$1; main=$(printf "%s" "$q" | awk ''{main=""; i=1; s=$0; n=length(s); while(i<=n){c=substr(s,i,1); if(c=="\\" && substr(s,i+1,1)=="!"){main=main "!"; i+=2; continue} if(c=="!" && (i==1 || substr(s,i-1,1) ~ /[[:blank:]]/)){sub(/[[:blank:]]+$/, "", main); j=i+1; while(j<=n && substr(s,j,1) !~ /[[:blank:]]/) j++; i=j; k=i; while(k<=n && substr(s,k,1) ~ /[[:blank:]]/) k++; if(k>n){i=n+1; continue} if(main=="") while(i<=n && substr(s,i,1) ~ /[[:blank:]]/) i++; continue} main=main c; i++} print main}'' ); excl=$(printf "%s" "$q" | awk ''{i=1; s=$0; n=length(s); while(i<=n){c=substr(s,i,1); if(c=="\\" && substr(s,i+1,1)=="!"){i+=2; continue} if(c=="!" && (i==1 || substr(s,i-1,1) ~ /[[:blank:]]/)){j=i+1; while(j<=n && substr(s,j,1) !~ /[[:blank:]]/) j++; term=substr(s,i+1,j-i-1); if(term!="") print term; i=j; continue} i++}}'' )'
  let l:cmd_filter = 'BFG_EXCL="$excl" awk ''BEGIN{excl=ENVIRON["BFG_EXCL"]; n=split(excl,terms,"\n"); for(i=1;i<=n;i++){t=terms[i]; if(t!=""){a[t]=1; lo[t]=tolower(t); cs[t]=(t ~ /[A-Z]/)}}} {raw=$0; s=$0; gsub(/\033\[[0-9;]*m/,"",s); sl=tolower(s); for(t in a){if(cs[t]){if(index(s,t)>0) next}else{if(index(sl,lo[t])>0) next}} print raw}'''
  let l:cmd_run = 'test -n "$main" || exit 0; if test -n "$excl"; then ' . l:cmd . '"$main" | ' . l:cmd_filter . ' || true; else ' . l:cmd . '"$main" || true; fi'
  let l:cmd_script = l:cmd_build . '; ' . l:cmd_run
  let l:cmd_reload = 'sh -c ' . shellescape(l:cmd_script) . ' sh {q}'
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
  if !s:CheckExecutable('rg')
    return
  endif
  let l:cmd = 'rg --files --hidden'
  for l:pattern in g:bfg_find_ignore
    if type(l:pattern) isnot# v:t_string || l:pattern ==# '' || l:pattern ==# '!' || l:pattern[0] ==# '!'
      continue
    endif
    let l:cmd .= ' --glob ' . shellescape('!' . l:pattern)
  endfor
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
        \ ['--scheme', 'default'],
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
