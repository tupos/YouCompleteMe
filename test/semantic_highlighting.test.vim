" This file provides the Vim-specific adapter for the shared semantic
" highlighting tests. The actual tests and common setup are in
" test/lib/semantic_highlighting.vim.

highlight default link Identifier Normal
highlight default link Number Normal
let g:ycm_neovim_ns_id = -1
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h' ) . '/lib/semantic_highlighting.vim' )


function! YcmTest_GetRenderedSemanticHighlights(
      \ buffer_number ) abort
  let highlights = []

  for line_number in range(
        \ 1,
        \ len( getbufline( a:buffer_number, 1, '$' ) ) )
    for property in prop_list(
          \ line_number,
          \ { 'bufnr': a:buffer_number } )
      if property.type !~# '^YCM_HL_'
        continue
      endif

      call add( highlights, {
            \ 'line': line_number,
            \ 'column': property.col,
            \ 'length': property.length,
            \ 'type': property.type,
            \ } )
    endfor
  endfor

  return highlights
endfunction
