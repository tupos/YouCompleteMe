let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )


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
