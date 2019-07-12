
let g:guider#tabsize = get(g:, 'guider#tabsize', 16)
let g:guider#mapfile = get(g:, 'guider#mapfile', 'guider-map.vim')

let g:guider_stack = []
let s:prompt_buffer = 0

let s:mode_to_map = {
    \ 'n': 'nmap',
    \ 'i': 'imap',
    \ 'c': 'cmap',
    \ 'v': 'vmap', 'V': 'vmap', "\<c-v>": 'vmap',
    \ 'no': 'omap',
    \ 'nov': 'xmap', 'noV': 'xmap', "no\<c-v>": 'xmap',
    \ 'niI': 'nmap', 'niR': 'nmap', 'niV': 'nmap',
\ }

let s:mode_to_mode = {
    \ 'n': 'n', 'i': 'i', 'c': 'c',
    \ 'v': 'v', 'V': 'v', "\<c-v>": 'v',
    \ 'no': 'o', 'nov': 'x', 'noV': 'x', "no\<c-v>": 'x',
\ }

let g:guider#bufname = '[guider]'
exec 'runtime!' g:guider#mapfile
com! -nargs=+ Guider call guider#(<f-args>)
au FileType guider call guider#syntax()

fun! guider#(key)
    let k = guider#tokey(a:key)
    let prefix = guider#split(k)
    " 获取用户输入的多余字符，在映射分支走向岔路的时候会发生
    while 1
        let ch = guider#getch(0)
        if empty(ch) | break | endif
        call add(prefix, ch)
    endw
    let prefix_keys = guider#keys(prefix)

    let global_tree = {}        " 全局按键映射树
    let local_tree = {}         " Buffer内按键映射树

    let g:guider_mode = mode(1)
    let map_cmd = get(s:mode_to_map, g:guider_mode, '')

    if empty(map_cmd)
        echoerr 'Not support this mode: ' . g:guider_mode
    else
        let map_cmd = map_cmd . ' ' . join(prefix_keys, '')
        if k =~ '<buffer>'
            let prefix = []
            let prefix_keys = []
            let map_cmd = map_cmd . ' ' . '<buffer>'
        endif

        for line in split(execute(map_cmd), "\n")
            let lhs = split(line[3:])[0]
            let mapd = guider#maparg(lhs)
            if empty(mapd)
                return guider#nop()
            endif
            let lhs_keys = guider#split(lhs)[len(prefix):]
            call guider#insert(mapd.buffer ? local_tree : global_tree, lhs_keys, mapd)
        endfor
        let global_tree = extend(global_tree, local_tree)

        if empty(global_tree)
            " 如果没有找到prefix的前缀映射，将用户输入的按键序列返回
            return join(guider#chars(prefix), '')
        else
            call timer_start(0, {t->guider#guide(prefix_keys, global_tree)})
        endif
    endif
    return guider#nop()
endf

fun! guider#get_info(key, buffer)
    if a:buffer
        return ''
    endif

    let k = a:key
    let empty_config = {}
    if g:guider_mode =~? '^i'
        return get(get(g:, 'guider#config#insert', empty_config), k, '')
    endif
    if g:guider_mode =~? '^v' || g:guider_mode == "\<c-v>"
        if has_key(get(g:, 'guider#config#visual', empty_config), k)
            return g:guider#config#visual[k]
        end
    endif
    return get(get(g:, 'guider#config', empty_config), k, '')
endf

fun! guider#maparg(lhs)
    let m = get(s:mode_to_mode, g:guider_mode, g:guider_mode[0])
    let mapd = maparg(a:lhs, m, 0, 1)
    if empty(mapd)
        echoerr 'There is no mapping for' a:lhs 'in' g:guider_mode 'mode'
    elseif mapd.rhs =~ '^\s*:' && mapd.silent && !mapd.expr
        let mapd.rhs = substitute(mapd.rhs, '^\s*', '', '')
        let mapd.rhs = substitute(mapd.rhs, '\c<cr>$', '', '')
        let mapd.rhs = substitute(mapd.rhs, '\c^:\s*call\s*', '', '')
        let mapd.rhs = substitute(mapd.rhs, '\c^:<c-u>\s*call\s*', '', '')
    elseif match(mapd.rhs, '\C^<Plug>(') >= 0
        let mapd.rhs = substitute(mapd.rhs, '\c^<Plug>(', '', '')
        let mapd.rhs = substitute(mapd.rhs, ')$', '', '')
    endif
    return mapd
endf

let s:char_to_show = {
    \ ' ': 'space', "\t": 'tab', "\n": 'cr', "\<bs>": 'bs',
    \ "\<LeftMouse>": 'LeftMouse', "\<LeftRelease>": 'LeftRelease',
    \ "\<RightMouse>": 'RightMouse', "\<RightRelease>": 'RightRelease',
    \ "\<up>": 'up', "\<down>": 'down', "\<left>": 'left', "\<right>": 'right',
\ }
let s:char_control = {
    \ 'U': 'left', 'V': 'right',
\ }

fun! s:single_key(char, angle)
    let c = a:char
    let a = a:angle
    if has_key(s:char_to_show, c)
        return printf(a ? '<%s>' : '%s', s:char_to_show[c])
    elseif len(c) == 1 && char2nr(c) <= 32
        return printf('<c-%s>', nr2char(char2nr(c) + char2nr('a') - 1))
    elseif c[:1] ==# "\<F1>"[:1]
        return printf(a ? '<F%s>' : 'F%s', c[len(c)-1])
    elseif c[:1] ==# "\<F11>"[:1]
        return printf(a ? '<F1%s>': 'F1%s', c[len(c)-1])
    endif
    return c
endf

fun! guider#tokey(char)
    let c = a:char
    if c[:2] ==# "\<m-a>"[:2]
        return printf('<m-%s>', s:single_key(c[3:], 0))
    elseif c[:1] ==# "\<c-left>"[:1]
        return printf('<c-%s>', get(s:char_control, c[len(c)-1], '?'))
    elseif c[:2] ==# "\<c-.>"[:2]
        return printf('<c-%s>', s:single_key(c[3:], 0))
    else
        return s:single_key(c, 1)
    endif
endf

fun! guider#keys(l)
    let l = copy(a:l)
    return map(l, {i,v->guider#tokey(v)})
endf

fun! guider#chars(l)
    let l = copy(a:l)
    " 长度大于1，且可打印
    return map(l, {i,v->len(v) > 1 && v =~ '\v^\p+$' ? eval(printf('"\%s"',v)): v})
endf

fun! guider#guide(prefix, tree)
    let g:guider_stack = a:prefix
    " 缓存光标位置，否则第二次弹框时会因为调用getchar()的原因，获取到的位置是在屏幕底部
    let s:screenrow = screenrow()
    let s:screencol = screencol()
    let has_map = guider#popup(a:tree)
    let chars = join(guider#chars(g:guider_stack), '')
    " Operating-Mode
    let chars = g:guider_mode =~ 'o' ? v:operator . chars : chars
    if has_map
        sil! call repeat#set(chars, v:count)
        call feedkeys(chars, 't')
    else
        call feedkeys(chars, 'n')
    endif
endf

" 构建按键映射树-插入节点
fun! guider#insert(tree, lhs_keys, mapinfo)
    let d = a:tree
    if empty(a:lhs_keys) | return | endif
    let l = guider#chars(a:lhs_keys)

    let tail = l[-1]
    for c in l[:-2]
        let s = get(d, c)
        let s = type(s) != v:t_dict ? {} : s
        let d[c] = s
        let d = s
    endfor
    let d[tail] = a:mapinfo
endf

fun! s:tobufline(l)
    " let sep = "\t│ "
    let sep = "\t "
    return map(sort(a:l, 'i'), {i,v->join([v.k, v.info], sep)})
endf

fun! guider#popup(tree)
    " 构造要显示的buffer内容
    let ld = [] | let li = [] | let lli = []
    let prefix_chars = join(guider#chars(g:guider_stack), '')
    for [k, v] in items(a:tree)
        let sk = guider#tokey(k)
        let buffer = get(v, 'buffer')
        let info = guider#get_info(prefix_chars . k, buffer)
        let info = len(info) ? info : get(v, 'rhs', '')
        let line = {'k': sk, 'info': info}
        if has_key(v, 'lhs')
            call add(buffer ? lli : li, line)
        else
            let line['info'] .= "\t..."
            call add(ld, line)
        endif
    endfor

    let li = s:tobufline(li)
    let ld = s:tobufline(ld)
    let lli = s:tobufline(lli)

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
    let position = get(g:, 'guider#position', 'cursor')
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
    call setwinvar(wid, '&winhl', 'SignColumn:Directory')

    let sep = ' - '
    echon "\r" | echohl Comment
    echon join(g:guider_stack, sep)
    echon sep | echohl Normal
    redraw!

    let c = guider#getch()
    call nvim_win_close(wid, 0)
    return c
endf

fun! guider#getch(...)
    let ch = a:0 ? getchar(a:1): getchar()
    return type(ch) == v:t_number && ch > 0 ? nr2char(ch): ch
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
    syn match Directory /^\S\+/
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
