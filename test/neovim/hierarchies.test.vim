" This file provides the Neovim-specific adapter for the shared hierarchy
" integration tests. The actual tests and common setup are in
" test/lib/hierarchies.vim.

let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )
execute 'set runtimepath^=' . fnameescape(
      \ s:repository_directory . '/test/lib' )
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/lib/hierarchies.vim' )


function! YcmTest_HierarchyWindows() abort
  let hierarchy_windows = []
  for window_id in nvim_list_wins()
    let buffer_number = nvim_win_get_buf( window_id )
    if getbufvar(
          \ buffer_number,
          \ 'ycm_hierarchy_window',
          \ v:false )
      call add( hierarchy_windows, window_id )
    endif
  endfor
  return hierarchy_windows
endfunction


function! YcmTest_HierarchyWindowLines( window_id ) abort
  return nvim_buf_get_lines(
        \ nvim_win_get_buf( a:window_id ),
        \ 0,
        \ -1,
        \ v:true )
endfunction


function! YcmTest_HierarchyWindowSelectedLine( window_id ) abort
  return nvim_win_get_cursor( a:window_id )[ 0 ]
endfunction


function! YcmTest_HierarchyWindowFirstVisibleLine( window_id ) abort
  return line( 'w0', a:window_id )
endfunction


function! YcmTest_HierarchyWindowHeight( window_id ) abort
  return nvim_win_get_height( a:window_id )
endfunction


function! YcmTest_SetHierarchyWindowHeight(
      \ window_id,
      \ height ) abort
  call nvim_win_set_height(
        \ a:window_id,
        \ a:height )
endfunction


function! YcmTest_CloseHierarchyWindow( window_id ) abort
  call nvim_win_close( a:window_id, v:true )
endfunction


function! YcmTest_HierarchyWindowHighlights( window_id ) abort
  let namespace = get(
        \ nvim_get_namespaces(),
        \ 'ycm_hierarchy',
        \ -1 )
  if namespace < 0
    return []
  endif

  let highlights = []
  let buffer_number = nvim_win_get_buf( a:window_id )
  for extmark in nvim_buf_get_extmarks(
        \ buffer_number,
        \ namespace,
        \ 0,
        \ -1,
        \ {
        \   'details': v:true,
        \   'hl_name': v:true,
        \ } )
    let details = extmark[ 3 ]
    if get( details, 'hl_group', '' ) !~# '^YCM-symbol-'
      continue
    endif
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


function! YcmTest_HierarchyWindowSelectionHighlight(
      \ window_id,
      \ line_number ) abort
  if !nvim_get_option_value(
        \ 'cursorline',
        \ { 'win': a:window_id } )
    return v:false
  endif
  return nvim_win_get_cursor( a:window_id )[ 0 ] ==
        \ a:line_number
endfunction


function! YcmTest_HierarchyUnknownKeyCloses() abort
  return v:false
endfunction
