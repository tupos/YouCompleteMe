" This file provides the Neovim-specific adapter for the shared inlay-hints
" integration tests. The actual tests and common setup are in
" test/shared/inlay_hints.vim. The functions below translate Neovim extmarks
" into the editor-independent representation used by those tests.

let g:ycm_neovim_ns_id = nvim_create_namespace( 'ycm_id' )
let s:unrelated_namespace = nvim_create_namespace( 'ycm_test_unrelated' )
highlight link YCM_INLAY_Enum Normal
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/inlay_hints.vim' )


function! YcmTest_GetRenderedInlayHints( buffer_number ) abort
  let namespace = get(
        \ nvim_get_namespaces(),
        \ 'ycm_inlay_hints',
        \ -1 )
  if namespace < 0
    return []
  endif

  let rendered_hints = []
    for extmark in nvim_buf_get_extmarks(
        \ a:buffer_number,
        \ namespace,
        \ 0,
        \ -1,
        \ { 'details': v:true } )
      call assert_equal( 'inline', extmark[ 3 ].virt_text_pos )
    let line_number = extmark[ 1 ] + 1
    let column_number = extmark[ 2 ] + 1

    if empty( rendered_hints ) ||
          \ rendered_hints[ -1 ].line != line_number ||
          \ rendered_hints[ -1 ].column != column_number
      call add( rendered_hints, {
            \ 'line': line_number,
            \ 'column': column_number,
            \ 'chunks': [],
            \ } )
    endif

    call extend(
          \ rendered_hints[ -1 ].chunks,
          \ extmark[ 3 ].virt_text )
  endfor

  return rendered_hints
endfunction


function! YcmTest_AddUnrelatedDecoration( buffer_number ) abort
  return nvim_buf_set_extmark(
        \ a:buffer_number,
        \ s:unrelated_namespace,
        \ 0,
        \ 0,
        \ {} )
endfunction


function! YcmTest_UnrelatedDecorationExists(
      \ buffer_number,
      \ decoration_id ) abort
  return !empty( nvim_buf_get_extmark_by_id(
        \ a:buffer_number,
        \ s:unrelated_namespace,
        \ a:decoration_id,
        \ {} ) )
endfunction


function! YcmTest_GetCustomInlayHintHighlight() abort
  return synIDattr(
        \ synIDtrans( hlID( 'YCM_INLAY_Enum' ) ),
        \ 'name' )
endfunction
