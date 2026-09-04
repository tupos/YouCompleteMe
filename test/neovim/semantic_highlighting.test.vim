" This file provides the Neovim-specific adapter for the shared semantic
" highlighting tests. The actual tests and common setup are in
" test/lib/semantic_highlighting.vim. The function below translates Neovim
" extmarks into the editor-independent representation used by those tests.

let g:ycm_neovim_ns_id = nvim_create_namespace( 'ycm_id' )
let s:unrelated_namespace = nvim_create_namespace( 'ycm_test_unrelated' )
highlight default link Identifier Normal
highlight default link Number Normal
highlight link YCM_HL_ycmTestCustom ErrorMsg
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/lib/semantic_highlighting.vim' )


function! YcmTest_GetRenderedSemanticHighlights(
      \ buffer_number ) abort
  let highlights = []
  let namespaces = nvim_get_namespaces()

  for namespace_name in [
        \ 'ycm_semantic_highlighting_0',
        \ 'ycm_semantic_highlighting_1',
        \ ]
    let namespace = get( namespaces, namespace_name, -1 )
    if namespace < 0
      continue
    endif

    for extmark in nvim_buf_get_extmarks(
          \ a:buffer_number,
          \ namespace,
          \ 0,
          \ -1,
          \ {
          \   'details': v:true,
          \   'hl_name': v:true,
          \ } )
      let details = extmark[ 3 ]
      call add( highlights, {
            \ 'line': extmark[ 1 ] + 1,
            \ 'column': extmark[ 2 ] + 1,
            \ 'length': details.end_col - extmark[ 2 ],
            \ 'type': details.hl_group,
            \ } )
    endfor
  endfor

  call sort(
        \ highlights,
        \ { left, right ->
        \   left.line == right.line
        \     ? left.column - right.column
        \     : left.line - right.line } )
  return highlights
endfunction


function! YcmTest_GetCustomSemanticHighlight() abort
  return synIDattr(
        \ synIDtrans( hlID( 'YCM_HL_ycmTestCustom' ) ),
        \ 'name' )
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
