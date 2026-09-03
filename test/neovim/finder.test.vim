" This file provides the Neovim-specific adapter for the shared finder
" integration tests. The actual tests and common setup are in
" test/lib/finder.vim.

let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )
execute 'set runtimepath^=' . fnameescape(
      \ s:repository_directory . '/test/lib' )
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/lib/finder.vim' )


function! YcmTest_FinderWindowIsVisible( window_id ) abort
  return a:window_id > 0 && nvim_win_is_valid( a:window_id )
endfunction


function! YcmTest_FinderWindowTitle( window_id ) abort
  let title = nvim_win_get_config( a:window_id ).title
  return join(
        \ map(
        \   copy( title ),
        \   { _, chunk -> chunk[ 0 ] } ),
        \ '' )
endfunction


function! YcmTest_FinderWindowBuffer( window_id ) abort
  return nvim_win_get_buf( a:window_id )
endfunction


function! YcmTest_FinderWindowLines( window_id ) abort
  return nvim_buf_get_lines(
        \ YcmTest_FinderWindowBuffer( a:window_id ),
        \ 0,
        \ -1,
        \ v:true )
endfunction


function! YcmTest_FinderWindowLineCount( window_id ) abort
  return len( YcmTest_FinderWindowLines( a:window_id ) )
endfunction


function! YcmTest_FinderWindowSelectedLine( window_id ) abort
  return nvim_win_get_cursor( a:window_id )[ 0 ]
endfunction


function! YcmTest_FinderWindowFirstVisibleLine( window_id ) abort
  return line( 'w0', a:window_id )
endfunction


function! YcmTest_FinderWindowHighlights( window_id ) abort
  let namespace = get(
        \ nvim_get_namespaces(),
        \ 'ycm_finder',
        \ -1 )
  if namespace < 0
    return []
  endif

  let highlights = []
  for extmark in nvim_buf_get_extmarks(
        \ YcmTest_FinderWindowBuffer( a:window_id ),
        \ namespace,
        \ 0,
        \ -1,
        \ { 'details': v:true } )
    let details = extmark[ 3 ]
    call add(
          \ highlights,
          \ {
          \   'line': extmark[ 1 ] + 1,
          \   'column': extmark[ 2 ] + 1,
          \   'length': details.end_col - extmark[ 2 ],
          \   'group': details.hl_group,
          \ } )
  endfor
  return highlights
endfunction


function! YcmTest_FinderNotifications() abort
  let notifications = []
  for window_id in nvim_list_wins()
    let config = nvim_win_get_config( window_id )
    if config.relative ==# 'editor'
          \ && config.anchor ==# 'NE'
          \ && config.row == 0
          \ && config.col == &columns
          \ && get( config, 'zindex', 0 ) == 300
      call add( notifications, window_id )
    endif
  endfor
  return notifications
endfunction


function! YcmTest_SetCharAvailOverride( enabled ) abort
  " test_override() is a Vim-only test API. Neovim does not need its
  " char_avail override for this scenario.
endfunction
