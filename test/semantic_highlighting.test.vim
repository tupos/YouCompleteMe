" This file provides the Vim-specific adapter for the shared semantic
" highlighting tests. The actual tests and common setup are in
" test/lib/semantic_highlighting.vim.

highlight default link Identifier Normal
highlight default link Number Normal
let g:ycm_neovim_ns_id = -1
call prop_type_add(
      \ 'YCM_HL_ycmTestCustom',
      \ { 'highlight': 'ErrorMsg' } )
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


function! YcmTest_GetCustomSemanticHighlight() abort
  return prop_type_get( 'YCM_HL_ycmTestCustom' ).highlight
endfunction


function! YcmTest_AddUnrelatedDecoration( buffer_number ) abort
  let property_type = 'YcmTestUnrelatedSemanticProperty'
  if empty( prop_type_get( property_type ) )
    call prop_type_add(
          \ property_type,
          \ { 'highlight': 'Normal' } )
  endif

  let property_id = 42
  call prop_add(
        \ 1,
        \ 1,
        \ {
        \   'bufnr': a:buffer_number,
        \   'id': property_id,
        \   'type': property_type,
        \ } )
  return property_id
endfunction


function! YcmTest_UnrelatedDecorationExists(
      \ buffer_number,
      \ decoration_id ) abort
  return !empty( prop_list(
        \ 1,
        \ {
        \   'bufnr': a:buffer_number,
        \   'ids': [ a:decoration_id ],
        \ } ) )
endfunction
