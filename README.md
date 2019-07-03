
## Introduction

`guider.nvim` is a vim keymap-display plugin inspired by
- https://github.com/liuchengxu/vim-which-key
- https://github.com/hecal3/vim-leader-guide

The improvement of `guider.nvim` is it can show guider's window under insert,
visual, operator-pending mode.

## Examples

```viml
let guider#config = {
    \ ' f': 'File',
    \ ' fc': 'CD Current File',
    \ ' fr': 'Recent Files',
    \ ' fs': 'New Scratch',
    \ ' fy': 'Copy FullPath To Clipboard',
    \ ' q': 'Quit',
\ }
nn <silent><space>fc    :cd %:h<cr>
nn <silent><space>fr    :Denite file/old'<cr>
nn <silent><space>fs    :call vwm#scrach()<cr>
nn         <space>ft    :conf e $TEMP/
nn <silent><space>fy    :let @+=expand('%:p')<cr>
nn <silent><space>q     :confirm qa<cr>

" Guide for mappings with <space> prefix
nore  <expr><space> guider#(' ')
" Guide for mappings with 'g' prefix
nore  <expr>g       guider#('g')
" Guide for all local-buffer mappings
nore  <expr>\       guider#('<buffer>')
```

## ScreenShots

normal-mode:
![](https://user-images.githubusercontent.com/9403405/60603176-cfc04000-9de7-11e9-80ff-e82a89e9d6b1.gif)

operator-pending mode:
![](https://user-images.githubusercontent.com/9403405/60603187-d51d8a80-9de7-11e9-89da-969d123e9dde.gif)

insert mode:
![](https://user-images.githubusercontent.com/9403405/60603203-df3f8900-9de7-11e9-9594-8bbe527c506b.gif)

