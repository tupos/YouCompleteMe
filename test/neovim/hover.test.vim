let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )


function! YcmTest_HoverWindow() abort
  for window_id in nvim_list_wins()
    let config = nvim_win_get_config( window_id )
    if !empty( config.relative ) &&
          \ getwinvar( window_id, 'lsp_floating_bufnr', 0 ) != 0
      return window_id
    endif
  endfor

  return 0
endfunction


function! YcmTest_HoverWindowAtScreenPosition( position ) abort
  for window_id in nvim_list_wins()
    let config = nvim_win_get_config( window_id )
    if empty( config.relative ) ||
          \ getwinvar( window_id, 'lsp_floating_bufnr', 0 ) == 0
      continue
    endif

    let window_position = nvim_win_get_position( window_id )
    let first_row = window_position[ 0 ] + 1
    let first_column = window_position[ 1 ] + 1
    let last_row = first_row + nvim_win_get_height( window_id ) - 1
    let last_column = first_column + nvim_win_get_width( window_id ) - 1

    if a:position.row >= first_row &&
          \ a:position.row <= last_row &&
          \ a:position.col >= first_column &&
          \ a:position.col <= last_column
      return window_id
    endif
  endfor

  return 0
endfunction


function! YcmTest_ClearHoverWindows() abort
  for window_id in nvim_list_wins()
    if getwinvar( window_id, 'lsp_floating_bufnr', 0 ) != 0
      call youcompleteme#hover#Close( window_id )
    endif
  endfor
endfunction


function! YcmTest_HoverContentSize() abort
  let window_id = YcmTest_HoverWindow()
  return {
        \ 'height': nvim_win_get_height( window_id ),
        \ 'width': nvim_win_get_width( window_id ),
        \ }
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/hover.vim' )


function! Test_Neovim_Hover_MoveCursor() abort
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/python/doc.py',
        \ {} )

  call setpos( '.', [ 0, 12, 3 ] )
  doautocmd CursorHold
  call WaitForAssert( { ->
        \ assert_notequal( 0, YcmTest_HoverWindow() ) } )
  let window_id = YcmTest_HoverWindow()

  call feedkeys( "wi\<Esc>", 'xt' )
  doautocmd CursorMoved
  call WaitForAssert( { ->
        \ assert_false(
        \   youcompleteme#hover#IsVisible( window_id ) ) } )

  call feedkeys( 'b', 'xt' )
  call assert_equal( 3, col( '.' ) )
  normal \D
  call WaitForAssert( { ->
        \ assert_notequal( 0, YcmTest_HoverWindow() ) } )

  call YcmTest_ClearHoverWindows()
endfunction


function! Test_Neovim_Hover_Popup_Interface() abort
  call assert_true( youcompleteme#hover#Supported() )

  let expected_lines = [ 'Heading', '', 'Documentation' ]
  let window_id = youcompleteme#hover#Show(
        \ expected_lines,
        \ 'markdown',
        \ { 'maxwidth': 10 } )

  call assert_true( youcompleteme#hover#IsVisible( window_id ) )
  let popup_buffer = winbufnr( window_id )
  call assert_equal(
        \ expected_lines,
        \ nvim_buf_get_lines( popup_buffer, 0, -1, v:true ) )
  call assert_true(
        \ getbufvar( popup_buffer, '&syntax' ) ==# 'markdown' ||
        \ getbufvar( popup_buffer, '&filetype' ) ==# 'markdown' )
  call assert_true( nvim_win_get_config( window_id ).width <= 10 )

  call youcompleteme#hover#Hide( window_id )
  call assert_false( youcompleteme#hover#IsVisible( window_id ) )

  let window_id = youcompleteme#hover#Show(
        \ expected_lines,
        \ 'markdown',
        \ {} )
  call youcompleteme#hover#Close( window_id )
  call assert_false( youcompleteme#hover#IsVisible( window_id ) )

  let window_id = youcompleteme#hover#Show(
        \ expected_lines,
        \ 'markdown',
        \ {} )
  doautocmd CursorMoved
  sleep 10m
  call assert_false( youcompleteme#hover#IsVisible( window_id ) )
endfunction
