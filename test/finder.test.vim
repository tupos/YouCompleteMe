" This file provides the Vim-specific adapter for the shared finder
" integration tests. The actual tests and common setup are in
" test/lib/finder.vim.
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h' ) . '/lib/finder.vim' )


function! YcmTest_FinderWindowIsVisible( window_id ) abort
  return get(
        \ popup_getpos( a:window_id ),
        \ 'visible',
        \ 0 )
endfunction


function! YcmTest_FinderWindowTitle( window_id ) abort
  return popup_getoptions( a:window_id ).title
endfunction


function! YcmTest_FinderWindowBuffer( window_id ) abort
  return winbufnr( a:window_id )
endfunction


function! YcmTest_FinderWindowLines( window_id ) abort
  return getbufline(
        \ YcmTest_FinderWindowBuffer( a:window_id ),
        \ 1,
        \ '$' )
endfunction


function! YcmTest_FinderWindowLineCount( window_id ) abort
  return len( YcmTest_FinderWindowLines( a:window_id ) )
endfunction


function! YcmTest_FinderWindowSelectedLine( window_id ) abort
  return getcurpos( a:window_id )[ 1 ]
endfunction


function! YcmTest_FinderWindowFirstVisibleLine( window_id ) abort
  return popup_getpos( a:window_id ).firstline
endfunction


function! YcmTest_FinderWindowHighlights( window_id ) abort
  let highlights = []
  let buffer_number = YcmTest_FinderWindowBuffer( a:window_id )

  for line_number in range(
        \ 1,
        \ YcmTest_FinderWindowLineCount( a:window_id ) )
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


function! YcmTest_FinderNotifications() abort
  if exists( '*popup_list' )
    return popup_list()
  endif

  let notification_id = popup_locate( 1, &columns - 1 )
  return notification_id > 0 ? [ notification_id ] : []
endfunction


function! YcmTest_SetCharAvailOverride( enabled ) abort
  if a:enabled
    call test_override( 'char_avail', 1 )
    return
  endif

  call test_override( 'ALL', 0 )
endfunction
