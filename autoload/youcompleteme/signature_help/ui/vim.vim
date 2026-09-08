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


function! youcompleteme#signature_help#ui#vim#Supported() abort
  return exists( '*screenpos' ) &&
        \ exists( '*pum_getpos' ) &&
        \ exists( '*popup_create' ) &&
        \ exists( '*popup_move' ) &&
        \ exists( '*popup_hide' ) &&
        \ exists( '*popup_settext' ) &&
        \ exists( '*popup_show' ) &&
        \ exists( '*popup_close' )
endfunction


function! s:MakePopupBuffer( presentation ) abort
  let popup_buffer = []
  for line in a:presentation.lines
    call add( popup_buffer, {
          \ 'text': line,
          \ 'props': [],
          \ } )
  endfor

  for range in a:presentation.active_parameter_ranges
    if range.line < 0 || range.line >= len( popup_buffer )
      continue
    endif

    call add( popup_buffer[ range.line ].props, {
          \ 'col': range.column + 1,
          \ 'length': range.length,
          \ 'type': 'YCM-signature-help-current-argument',
          \ } )
  endfor

  return popup_buffer
endfunction


function! youcompleteme#signature_help#ui#vim#Render(
      \ window_id,
      \ presentation,
      \ anchor,
      \ hidden,
      \ syntax ) abort
  let popup_buffer = s:MakePopupBuffer( a:presentation )
  let screen_position = screenpos(
        \ win_getid(),
        \ a:anchor[ 0 ] + 1,
        \ a:anchor[ 1 ] + 1 )

  " Display above the anchor by default.
  let popup_line = screen_position.row - 1
  let popup_position = 'botleft'

  if screen_position.row <= len( popup_buffer )
    " There is no room above the anchor, so display below it.
    let popup_line = screen_position.row + 1
    let popup_position = 'topleft'
  endif

  " Do not allow the popup to overlap the cursor.
  let cursor_line = line( '.' )
  if popup_position ==# 'topleft' &&
        \ popup_line < cursor_line &&
        \ popup_line + len( popup_buffer ) >= cursor_line
    let popup_line = 0
  endif

  " Do not allow the popup to overlap the completion menu.
  if popup_line > 0 && pumvisible()
    let pum_line = pum_getpos().row + 1
    if popup_position ==# 'botleft' && pum_line <= popup_line
      let popup_line = 0
    elseif popup_position ==# 'topleft' &&
          \ pum_line >= popup_line &&
          \ pum_line < popup_line + len( popup_buffer )
      let popup_line = 0
    endif
  endif

  if popup_line <= 0
    call youcompleteme#signature_help#ui#vim#Close( a:window_id )
    return 0
  endif

  if screen_position.curscol <= 1
    let popup_column = 1
  else
    " Remove one column for padding and one for the trigger character. The
    " anchor is currently recorded after that character is inserted.
    let popup_column = screen_position.curscol - 2
  endif

  let max_line_length = empty( a:presentation.lines )
        \ ? 0
        \ : max( map(
        \     copy( a:presentation.lines ),
        \     { _, line -> strchars( line ) } ) )
  let available_width = &columns - max( [ popup_column, 1 ] )
  if max_line_length > available_width
    let popup_column = &columns - max_line_length - 1
  endif
  if popup_column <= 0
    let popup_column = 1
  endif

  let popup_options = {
        \ 'line': popup_line,
        \ 'col': popup_column,
        \ 'pos': popup_position,
        \ 'wrap': 0,
        \ 'flip': 1,
        \ 'fixed': 1,
        \ 'padding': [ 0, 1, 0, 1 ],
        \ 'hidden': a:hidden,
        \ }

  let window_id = a:window_id
  if window_id <= 0
    let window_id = popup_create( popup_buffer, popup_options )
  else
    call popup_settext( window_id, popup_buffer )
  endif

  call popup_move( window_id, popup_options )
  if !a:hidden
    call popup_show( window_id )
  endif

  call setbufvar( winbufnr( window_id ), '&syntax', a:syntax )
  call win_execute(
        \ window_id,
        \ 'setlocal cursorline wrap | call cursor( [ ' .
        \ ( a:presentation.active_signature + 1 ) .
        \ ', 1 ] )' )

  return window_id
endfunction


function! youcompleteme#signature_help#ui#vim#Close( window_id ) abort
  if a:window_id > 0
    call popup_close( a:window_id )
  endif
endfunction


function! youcompleteme#signature_help#ui#vim#Hide( window_id ) abort
  if a:window_id > 0
    call popup_hide( a:window_id )
  endif
endfunction


function! youcompleteme#signature_help#ui#vim#Show( window_id ) abort
  if a:window_id > 0
    call popup_show( a:window_id )
  endif
endfunction
