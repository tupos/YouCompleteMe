" This file provides the Neovim-specific adapter for the shared document-
" highlights integration tests. The actual tests and common setup are in
" test/shared/document_highlights.vim.
let g:ycm_neovim_ns_id = nvim_create_namespace( 'ycm_id' )
let s:unrelated_namespace = nvim_create_namespace(
      \ 'ycm_test_unrelated_document_highlight' )
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/document_highlights.vim' )


function! YcmTest_GetRenderedDocumentHighlights(
      \ buffer_number ) abort
  let namespace = get(
        \ nvim_get_namespaces(),
        \ 'ycm_document_highlights',
        \ -1 )
  if namespace < 0
    return []
  endif

  let highlights = []
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
          \ 'group': details.hl_group,
          \ } )
  endfor

  return highlights
endfunction


function! YcmTest_AddUnrelatedDocumentHighlightDecoration(
      \ buffer_number ) abort
  return nvim_buf_set_extmark(
        \ a:buffer_number,
        \ s:unrelated_namespace,
        \ 0,
        \ 0,
        \ {} )
endfunction


function! YcmTest_UnrelatedDocumentHighlightDecorationExists(
      \ buffer_number,
      \ decoration_id ) abort
  return !empty( nvim_buf_get_extmark_by_id(
        \ a:buffer_number,
        \ s:unrelated_namespace,
        \ a:decoration_id,
        \ {} ) )
endfunction
