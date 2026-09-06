" This file provides the Vim adapter for the shared hover integration tests.
" The actual tests and common setup are in test/shared/hover.vim.

function! YcmTest_HoverWindow() abort
  for window_id in popup_list()
    if popup_getpos( window_id ).visible
      return window_id
    endif
  endfor

  return 0
endfunction


function! YcmTest_HoverWindowAtScreenPosition( position ) abort
  return popup_locate( a:position.row, a:position.col )
endfunction


function! YcmTest_ClearHoverWindows() abort
  call popup_clear()
endfunction


function! s:PrepareForCursorMovement() abort
  call test_override( 'char_avail', 1 )
endfunction


function! s:RestoreCursorMovement() abort
  call test_override( 'ALL', 0 )
endfunction


function! s:MoveCursor( keys ) abort
  call feedkeys( a:keys, 'xt' )
endfunction


function! YcmTest_HoverContentSize() abort
  let position = popup_getpos( YcmTest_HoverWindow() )
  return {
        \ 'height': position.core_height,
        \ 'width': position.core_width,
        \ }
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/hover.vim' )


function! Test_Vim_Hover_MoveCursorWithinWord()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )
  call s:PrepareForCursorMovement()

  call setpos( '.', [ 0, 12, 3 ] )
  doautocmd CursorHold
  let position = screenpos( win_getid(), 11, 3 )
  call WaitForAssert( { ->
        \ assert_notequal(
        \   0,
        \   YcmTest_HoverWindowAtScreenPosition( position ) ) } )

  let window_id = YcmTest_HoverWindowAtScreenPosition( position )
  call assert_equal(
        \ [ 12, 2, 13 ],
        \ popup_getoptions( window_id ).moved )

  call s:MoveCursor( "li\<Esc>" )
  call assert_notequal(
        \ 0,
        \ YcmTest_HoverWindowAtScreenPosition( position ) )

  call s:MoveCursor( "4li\<Esc>" )
  call assert_notequal(
        \ 0,
        \ YcmTest_HoverWindowAtScreenPosition( position ) )

  call s:RestoreCursorMovement()

  call YcmTest_ClearHoverWindows()
endfunction


function! Test_Vim_Long_WrappedLayout()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )
  call cursor( [ 38, 22 ] )
  normal \D

  call WaitForAssert( { ->
        \ assert_notequal( 0, YcmTest_HoverWindow() ) } )
  let position = popup_getpos( YcmTest_HoverWindow() )

  call assert_equal(
        \ screenpos( win_getid(), 27, 1 ).row,
        \ position.line )
  call assert_equal( 1, position.col )
  call assert_equal( 11, position.height )
  call assert_equal( &columns, position.width )

  call YcmTest_ClearHoverWindows()
endfunction
