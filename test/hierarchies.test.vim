" This file provides the Vim-specific adapter for the shared hierarchy
" integration tests. The actual tests and common setup are in
" test/lib/hierarchies.vim.
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h' ) . '/lib/hierarchies.vim' )


function! YcmTest_HierarchyWindows() abort
  return popup_list()
endfunction


function! YcmTest_HierarchyWindowLines( window_id ) abort
  return getbufline(
        \ winbufnr( a:window_id ),
        \ 1,
        \ '$' )
endfunction


function! YcmTest_HierarchyWindowSelectedLine( window_id ) abort
  return getcurpos( a:window_id )[ 1 ]
endfunction


function! YcmTest_HierarchyWindowFirstVisibleLine( window_id ) abort
  return popup_getpos( a:window_id ).firstline
endfunction


function! YcmTest_HierarchyWindowHeight( window_id ) abort
  return popup_getpos( a:window_id ).core_height
endfunction


function! YcmTest_HierarchyWindowHighlights( window_id ) abort
  let highlights = []
  let buffer_number = winbufnr( a:window_id )
  let lines = YcmTest_HierarchyWindowLines( a:window_id )

  for line_number in range( 1, len( lines ) )
    for property in prop_list(
          \ line_number,
          \ { 'bufnr': buffer_number } )
      if property.type !~# '^YCM-symbol-'
        continue
      endif
      call add(
            \ highlights,
            \ {
            \   'line': line_number,
            \   'column': property.col,
            \   'length': property.length,
            \   'group': property.type,
            \ } )
    endfor
  endfor
  return highlights
endfunction
