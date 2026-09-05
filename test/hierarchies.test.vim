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


function! YcmTest_SetHierarchyWindowHeight( window_id, height ) abort
  call popup_setoptions(
        \ a:window_id,
        \ {
        \   'minheight': a:height,
        \   'maxheight': a:height,
        \ } )
endfunction


function! YcmTest_CloseHierarchyWindow( window_id ) abort
  call popup_close( a:window_id )
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


function! Test_Hierarchy_Vim_Redraws_Selection_After_Expansion()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  setlocal cursorline
  call cursor( [ 13, 8 ] )

  call youcompleteme#hierarchy#StartRequest( 'type' )
  call WaitForAssert( { ->
        \ assert_equal( 1, len( popup_list() ) ) } )

  let window_id = popup_list()[ 0 ]
  redraw
  let position = popup_getpos( window_id )
  let selected_attribute =
        \ screenattr( position.core_line, position.core_col )

  " B0 is inserted above B1. The popup cursor and its visible cursorline must
  " both follow B1 from the first row to the second row.
  call feedkeys( "\<S-Tab>", 'xt' )
  call WaitForAssert( { ->
        \ assert_equal(
        \   2,
        \   len(
        \     getbufline(
        \       winbufnr( popup_list()[ 0 ] ),
        \       1,
        \       '$' ) ) ) } )

  let window_id = popup_list()[ 0 ]
  call assert_equal( 2, getcurpos( window_id )[ 1 ] )
  let position = popup_getpos( window_id )
  call assert_notequal(
        \ selected_attribute,
        \ screenattr( position.core_line, position.core_col ) )
  call assert_equal(
        \ selected_attribute,
        \ screenattr( position.core_line + 1, position.core_col ) )

  call feedkeys( "\<C-c>", 'xt' )
  call WaitForAssert( { ->
        \ assert_equal( 0, len( popup_list() ) ) } )

  %bwipe!
endfunction
