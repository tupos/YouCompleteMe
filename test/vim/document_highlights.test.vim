" This file provides the Vim-specific adapter for the shared document-
" highlights integration tests. The actual tests and common setup are in
" test/shared/document_highlights.vim.
let g:ycm_neovim_ns_id = -1
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/document_highlights.vim' )


function! YcmTest_GetRenderedDocumentHighlights(
      \ buffer_number ) abort
  let highlights = []
  let document_highlight_groups = [
        \ 'YcmDocumentHighlightText',
        \ 'YcmDocumentHighlightRead',
        \ 'YcmDocumentHighlightWrite',
        \ ]

  for line_number in range(
        \ 1,
        \ len( getbufline( a:buffer_number, 1, '$' ) ) )
    for property in prop_list(
          \ line_number,
          \ { 'bufnr': a:buffer_number } )
      if index( document_highlight_groups, property.type ) < 0
        continue
      endif

      call add( highlights, {
            \ 'line': line_number,
            \ 'column': property.col,
            \ 'length': property.length,
            \ 'group': property.type,
            \ } )
    endfor
  endfor

  return highlights
endfunction


function! YcmTest_AddUnrelatedDocumentHighlightDecoration(
      \ buffer_number ) abort
  let property_type = 'YcmTestUnrelatedDocumentHighlight'
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


function! YcmTest_UnrelatedDocumentHighlightDecorationExists(
      \ buffer_number,
      \ decoration_id ) abort
  return !empty( prop_list(
        \ 1,
        \ {
        \   'bufnr': a:buffer_number,
        \   'ids': [ a:decoration_id ],
        \ } ) )
endfunction


function! Test_DocumentHighlights_OutrankSemanticTextProperties() abort
  if !py3eval( 'YCM_TEST_DOCUMENT_HIGHLIGHTS_SUPPORTED' )
    throw 'Skipped: document highlights are not supported'
  endif

  let semantic_property_type = 'YcmTestSemanticHighlight'
  call prop_type_add(
        \ semantic_property_type,
        \ {
        \   'highlight': 'Normal',
        \   'priority': 0,
        \ } )

  try
    let semantic_priority =
          \ prop_type_get( semantic_property_type ).priority
    for document_highlight_type in [
          \ 'YcmDocumentHighlightText',
          \ 'YcmDocumentHighlightRead',
          \ 'YcmDocumentHighlightWrite',
          \ ]
      call assert_true(
            \ prop_type_get( document_highlight_type ).priority
            \ > semantic_priority )
    endfor
  finally
    call prop_type_delete( semantic_property_type )
  endtry
endfunction
