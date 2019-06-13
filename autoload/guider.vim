
let g:guider#tabsize = get(g:, 'guider#tabsize', 16)
let g:guider#bufname = '[guider]'

let g:guider_stack = []
let s:prompt_buffer = 0

let s:mode_to_map = {
    \ 'n': 'nmap',
    \ 'i': 'imap',
    \ 'c': 'cmap',
    \ 'v': 'vmap', 'V': 'vmap', "\<c-v>": 'vmap',
\ }

let s:char_to_show = {
    \ ' ': '<space>', "\t": '<tab>', "\n": '<cr>',
    \ "\<m-a>": '<m-a>',
    \ "\<m-b>": '<m-b>',
    \ "\<m-c>": '<m-c>',
    \ "\<m-d>": '<m-d>',
    \ "\<m-e>": '<m-e>',
    \ "\<m-f>": '<m-f>',
    \ "\<m-g>": '<m-g>',
    \ "\<m-h>": '<m-h>',
    \ "\<m-i>": '<m-i>',
    \ "\<m-j>": '<m-j>',
    \ "\<m-k>": '<m-k>',
    \ "\<m-l>": '<m-l>',
    \ "\<m-m>": '<m-m>',
    \ "\<m-n>": '<m-n>',
    \ "\<m-o>": '<m-o>',
    \ "\<m-p>": '<m-p>',
    \ "\<m-q>": '<m-q>',
    \ "\<m-r>": '<m-r>',
    \ "\<m-s>": '<m-s>',
    \ "\<m-t>": '<m-t>',
    \ "\<m-u>": '<m-u>',
    \ "\<m-v>": '<m-v>',
    \ "\<m-w>": '<m-w>',
    \ "\<m-x>": '<m-x>',
    \ "\<m-y>": '<m-y>',
    \ "\<m-z>": '<m-z>',
    \ "\<m-\>": '<m-\>',
\ }

runtime! autoload/guider/keymap.vim
com! -nargs=+ Guider call guider#(<f-args>)
au FileType guider call guider#syntax()

fun! guider#(key)
    let k = get(s:char_to_show, a:key, a:key)
    let tree = {}
    let local_dict = {}

    let map_cmd = get(s:mode_to_map, mode(), '')
    if empty(map_cmd)
        echoerr 'Not support this mode: ' . mode()
    else
        for line in split(execute(map_cmd . ' ' . k), "\n")
            let lhs = split(line[3:])[0]
            let mapd = guider#maparg(lhs)
            if empty(mapd)
                return guider#nop()
            endif
            call guider#insert(mapd.buffer ? local_dict : tree, lhs, mapd)
        endfor
        let tree = extend(tree, local_dict)

        let prefix = guider#split(k)
        call timer_start(0, {t->guider#guide(prefix, tree)})
    endif
    return guider#nop()
endf

fun! guider#get_info(key, buffer)
    if a:buffer
        return ''
    endif

    let k = a:key
    let empty_config = {}
    if mode() =~? '^i'
        return get(get(g:, 'guider#config#insert', empty_config), k, '')
    endif
    if mode() =~? '^v' || mode() == "\<c-v>"
        if has_key(get(g:, 'guider#config#visual', empty_config), k)
            return g:guider#config#visual[k]
        end
    endif
    return get(get(g:, 'guider#config', empty_config), k, '')
endf

fun! guider#maparg(lhs)
    " let l:ret = a:mapping
    " let l:ret = substitute(l:ret, '\c<cr>$', '', '')
    " let l:ret = substitute(l:ret, '^:', '', '')
    " let l:ret = substitute(l:ret, '^\c<c-u>', '', '')
    " let l:ret = substitute(l:ret, '^<Plug>', '', '')
    " return l:ret
    " echo a:lhs | call getchar()
    let mapd = maparg(a:lhs, mode(), 0, 1)
    if mapd.rhs =~ '^\s*:' && mapd.silent
        let rhs = substitute(mapd.rhs, '^\s*', '', '')
        let mapd.rhs = substitute(rhs, '<cr>$', '', '')
    endif
    return mapd
endf

fun! guider#chars(l)
    let stack = copy(a:l)
    return map(stack, {i,v->len(v) > 1 ? eval(printf('"\%s"',v)): v})
endf

fun! guider#guide(prefix, tree)
    let g:guider_stack = a:prefix
    " 缓存光标位置，因为第二次弹框时获取到的位置是在屏幕底部
    let s:screenrow = screenrow()
    let s:screencol = screencol()
    if guider#popup(a:tree)
        call feedkeys(join(guider#chars(g:guider_stack), ''), 't')
    endif
endf

" 构建按键映射树-插入节点
fun! guider#insert(tree, lhs, mapinfo)
    let d = a:tree
    " echom a:lhs
    let lhs = guider#split(a:lhs)
    if len(lhs) < 2 | return | endif
    let l = guider#chars(lhs)

    let tail = l[-1]
    for c in l[1:-2]
        let s = get(d, c)
        let s = type(s) != v:t_dict ? {} : s
        let d[c] = s
        let d = s
    endfor
    let d[tail] = a:mapinfo
endf

fun! guider#popup(tree)
    " 构造要显示的buffer内容
    let ld = [] | let li = [] | let lli = []
    let prefix_chars = join(guider#chars(g:guider_stack), '')
    " let sep = "\t│ "
    let sep = "\t "
    for [k, v] in items(a:tree)
        let sk = get(s:char_to_show, k, strtrans(k))
        let buffer = get(v, 'buffer')
        let info = guider#get_info(prefix_chars . k, buffer)
        let info = len(info) ? info : get(v, 'rhs', '')
        let line = join([sk, info, ''], sep)
        if has_key(v, 'lhs')
            call add(buffer ? lli : li, line)
        else
            let line .= '...'
            call add(ld, line)
        endif
    endfor
    let li += ld
    if len(lli)
        " call add(lli, join(repeat([repeat('─', g:guider#tabsize)], 3), '┼'))
        call add(lli, '-----------------------------')
        let li = lli + li
    endif

    " 弹出窗口并获取用户输入
    let c = guider#prompt(li)
    call add(g:guider_stack, c)

    let v = get(a:tree, c, 0)
    if empty(v)
        return 0
    elseif !has_key(v, 'lhs')
        return guider#popup(v)
    else
        return 1
    endif
endf

fun! guider#prompt(l)
    let bnr = get(s:, 'prompt_buffer')
    if empty(bnr)
        if has('nvim')
            let bnr = nvim_create_buf(0, 0)
        else
            exec 'badd' g:guider#bufname
            let bnr = bufnr(g:guider#bufname)
        endif
        let s:prompt_buffer = bnr
        call setbufvar(bnr, '&tabstop', g:guider#tabsize)
        call setbufvar(bnr, '&buflisted', 0)
        call setbufvar(bnr, '&buftype', 'nofile')
        call setbufvar(bnr, '&ft', 'guider')
        call setbufvar(bnr, '&wrap', 0)
        call setbufvar(bnr, '&number', 0)
    endif

    let _ = has('nvim') ? nvim_buf_set_lines(bnr, 0, -1, 0, a:l)
                      \ : setbufline(bnr, 1, a:l)

    " Popup the prompt window, 默认在下方展示
    let win_conf = {
        \ 'relative': 'editor', 'anchor': 'SW',
        \ 'height': len(a:l), 'width': get(g:, 'guider#width', 64),
        \ 'row': &lines, 'col': 0, 'focusable': 0,
    \ }
    let position = get(g:, 'guider#position', 'bottom')
    if position == 'cursor'
        let win_conf.anchor = 'NW'
        let win_conf.row = s:screenrow
        let win_conf.col = s:screencol
        " let win_conf.width = min([win_conf.width, &columns - s:screencol])
    elseif position == 'right'
        " TODO
    endif
    let wid = nvim_open_win(bnr, 0, win_conf)
    call setwinvar(wid, '&signcolumn', 'yes')
    call setwinvar(wid, '&cursorline', 0)
    call setwinvar(wid, '&list', 0)
    " call setwinvar(wid, '&listchars', 'tab:  |')
    call setwinvar(wid, '&winhl', 'SignColumn:CursorLineNr')

    let sep = ' - '
    echon "\r" | echohl Comment
    echon join(g:guider_stack, sep)
    echon sep | echohl Normal
    redraw!

    let c = guider#getch()
    call nvim_win_close(wid, 0)
    return c
endf

fun! guider#getch()
    let ch = getchar()
    return type(ch) == v:t_number ? nr2char(ch): ch
endf

fun! guider#split(lhs)
    let result = []
    call substitute(a:lhs,
                 \ '\v\c\<[mcs]-([^>]+)\>|\<f\d+\>|\<\w+\>|"|.',
                 \ {m->[add(result, m[0]),''][-1]}, 'g')
    return result
endf

fun! guider#syntax()
    syn match Title /\.\.\./
    syn match Directory /<.*>/
    syn match CursorLineNr /^\S\+/
endf

fun! guider#nop()
    let ch = "\<F12>"
    if mode() =~ '[Ric].\?'
        let ch = "\<c-r>\<esc>"
    elseif mode() =~ 'n.\?'
        let ch = "\<esc>"
    endif
    " redraw
    call feedkeys(ch, 'n') | return ''
endf
