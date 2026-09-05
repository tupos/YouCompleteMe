" This file provides the Vim-specific adapter for the shared inlay-hints
" integration tests. The actual tests and common setup are in
" test/shared/inlay_hints.vim. The functions below translate Vim text properties
" into the editor-independent representation used by those tests.

let g:ycm_neovim_ns_id = -1
call prop_type_add(
      \ 'YCM_INLAY_Enum',
      \ { 'highlight': 'Normal' } )
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/inlay_hints.vim' )


function! YcmTest_GetRenderedInlayHints( buffer_number ) abort
  let rendered_hints = []

  for line_number in range(
        \ 1,
        \ len( getbufline( a:buffer_number, 1, '$' ) ) )
    for property in prop_list(
          \ line_number,
          \ { 'bufnr': a:buffer_number } )
      if property.type !~# '^YCM_INLAY_'
        continue
      endif

      if empty( rendered_hints ) ||
            \ rendered_hints[ -1 ].line != line_number ||
            \ rendered_hints[ -1 ].column != property.col
        call add( rendered_hints, {
              \ 'line': line_number,
              \ 'column': property.col,
              \ 'chunks': [],
              \ } )
      endif

      " prop_list() returns same-column virtual text properties in the
      " opposite order from that in which Vim displays them.
      call insert(
            \ rendered_hints[ -1 ].chunks,
            \ [ property.text, property.type ],
            \ 0 )
    endfor
  endfor

  return rendered_hints
endfunction


function! YcmTest_AddUnrelatedDecoration( buffer_number ) abort
  let property_type = 'YcmTestUnrelatedProperty'
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


function! YcmTest_GetCustomInlayHintHighlight() abort
  return prop_type_get( 'YCM_INLAY_Enum' ).highlight
endfunction
