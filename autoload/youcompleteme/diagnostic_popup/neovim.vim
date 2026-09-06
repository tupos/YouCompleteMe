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


function! youcompleteme#diagnostic_popup#neovim#Supported() abort
  return exists( '*nvim_create_buf' )
        \ && exists( '*nvim_buf_set_lines' )
        \ && exists( '*nvim_open_win' )
        \ && exists( '*nvim_win_is_valid' )
        \ && exists( '*nvim_win_close' )
        \ && exists( '*nvim_set_option_value' )
        \ && exists( '*nvim_create_autocmd' )
endfunction


function! youcompleteme#diagnostic_popup#neovim#Close(
      \ window_id ) abort
  if a:window_id > 0 && nvim_win_is_valid( a:window_id )
    call nvim_win_close( a:window_id, v:true )
  endif
endfunction


function! s:ContentSize( lines ) abort
  let maximum_width = max( [ 1, &columns - 4 ] )
  let width = 1
  for line in a:lines
    let width = max( [ width, strdisplaywidth( line ) ] )
  endfor
  let width = min( [ width, maximum_width ] )

  let height = 0
  for line in a:lines
    let line_width = max( [ 1, strdisplaywidth( line ) ] )
    let height += ( line_width + width - 1 ) / width
  endfor
  let maximum_height = max( [ 1, &lines - 4 ] )

  return [ width, min( [ max( [ 1, height ] ), maximum_height ] ) ]
endfunction


function! youcompleteme#diagnostic_popup#neovim#Show(
      \ lines,
      \ buffer_number,
      \ cursor_position,
      \ diagnostic ) abort
  let source_window_id = win_getid()
  if winbufnr( source_window_id ) != a:buffer_number
    return -1
  endif

  let popup_buffer = nvim_create_buf( v:false, v:true )
  call setbufvar( popup_buffer, '&bufhidden', 'wipe' )
  call nvim_buf_set_lines(
        \ popup_buffer,
        \ 0,
        \ -1,
        \ v:true,
        \ a:lines )
  call setbufvar( popup_buffer, '&modifiable', v:false )

  let [ width, height ] = s:ContentSize( a:lines )
  let window_id = nvim_open_win(
        \ popup_buffer,
        \ v:false,
        \ {
        \   'relative': 'win',
        \   'win': source_window_id,
        \   'bufpos': [
        \     a:cursor_position[ 0 ] - 1,
        \     a:cursor_position[ 1 ] - 1,
        \   ],
        \   'width': width,
        \   'height': height,
        \   'anchor': 'NW',
        \   'style': 'minimal',
        \   'focusable': v:false,
        \   'mouse': v:false,
        \   'border': 'single',
        \ } )
  call nvim_set_option_value(
        \ 'winhighlight',
        \ 'Normal:YcmErrorPopup,FloatBorder:YcmErrorPopup',
        \ { 'win': window_id } )
  call nvim_set_option_value(
        \ 'wrap',
        \ v:true,
        \ { 'win': window_id } )

  call setwinvar(
        \ window_id,
        \ 'ycm_diagnostic_popup',
        \ v:true )

  let close_command =
        \ 'call youcompleteme#diagnostic_popup#neovim#Close('
        \ . window_id
        \ . ')'
  call nvim_create_autocmd(
        \ [ 'CursorMoved', 'CursorMovedI', 'BufLeave' ],
        \ {
        \   'buffer': a:buffer_number,
        \   'command': close_command,
        \   'desc': 'Close YCM detailed diagnostic popup',
        \   'once': v:true,
        \ } )

  return window_id
endfunction
