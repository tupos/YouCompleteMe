" Copyright (C) 2026 YouCompleteMe contributors
"
" This file is part of YouCompleteMe.
"
" YouCompleteMe is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" YouCompleteMe is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with YouCompleteMe.  If not, see <http://www.gnu.org/licenses/>.


function! youcompleteme#list_ui#neovim#Initialise() abort
  for [ highlight_group, default_highlight_group ] in
        \ items( youcompleteme#symbol#GetHighlightGroups() )
    execute 'highlight default link '
          \ . highlight_group
          \ . ' '
          \ . default_highlight_group
  endfor
endfunction


function! youcompleteme#list_ui#neovim#GetWidth( window_id ) abort
  return nvim_win_get_width( a:window_id )
endfunction


function! youcompleteme#list_ui#neovim#GetHeight( window_id ) abort
  return nvim_win_get_height( a:window_id )
endfunction


function! youcompleteme#list_ui#neovim#GetSelected( window_id ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return -1
  endif

  return nvim_win_get_cursor( a:window_id )[ 0 ] - 1
endfunction


function! youcompleteme#list_ui#neovim#SetContents(
      \ window_id,
      \ contents,
      \ highlight_namespace ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  let buffer_number = nvim_win_get_buf( a:window_id )
  if type( a:contents ) == v:t_list
    let lines = map(
          \ copy( a:contents ),
          \ { _, line -> line.text } )
  else
    let lines = [ a:contents ]
  endif

  call setbufvar( buffer_number, '&modifiable', v:true )
  call nvim_buf_set_lines(
        \ buffer_number,
        \ 0,
        \ -1,
        \ v:true,
        \ lines )
  call setbufvar( buffer_number, '&modifiable', v:false )

  let namespace = nvim_create_namespace( a:highlight_namespace )
  call nvim_buf_clear_namespace(
        \ buffer_number,
        \ namespace,
        \ 0,
        \ -1 )

  if type( a:contents ) != v:t_list
    return
  endif

  let line_number = 0
  for line in a:contents
    for highlight in line.highlights
      let start_column = highlight.column - 1
      call nvim_buf_set_extmark(
            \ buffer_number,
            \ namespace,
            \ line_number,
            \ start_column,
            \ {
            \   'end_col': start_column + highlight.length,
            \   'hl_group': highlight.group,
            \ } )
    endfor
    let line_number += 1
  endfor
endfunction


function! youcompleteme#list_ui#neovim#SetSelected(
      \ window_id,
      \ selected ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  if a:selected < 0
    call nvim_set_option_value(
          \ 'cursorline',
          \ v:false,
          \ { 'win': a:window_id } )
    return
  endif

  " Move the cursor so that cursorline highlights the selected item. Also
  " scroll the window if the selected item is not in view. To make scrolling
  " feel natural we position the current line at the bottom of the window if
  " the new current line is below the current viewport, and at the top if the
  " new current line is above the viewport.
  let line_number = a:selected + 1
  let first_line = line( 'w0', a:window_id )
  let window_height = nvim_win_get_height( a:window_id )

  call nvim_win_set_cursor(
        \ a:window_id,
        \ [ line_number, 0 ] )

  if line_number < first_line
    call win_execute( a:window_id, 'normal! zt' )
  elseif line_number >= first_line + window_height
    call win_execute( a:window_id, 'normal! zb' )
  endif

  call nvim_set_option_value(
        \ 'cursorlineopt',
        \ 'both',
        \ { 'win': a:window_id } )
  call nvim_set_option_value(
        \ 'cursorline',
        \ v:true,
        \ { 'win': a:window_id } )
endfunction


function! youcompleteme#list_ui#neovim#SetTabstop(
      \ window_id,
      \ tabstop ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  call nvim_set_option_value(
        \ 'tabstop',
        \ a:tabstop,
        \ { 'buf': nvim_win_get_buf( a:window_id ) } )
endfunction
