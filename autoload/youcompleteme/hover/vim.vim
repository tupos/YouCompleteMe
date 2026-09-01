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


function! youcompleteme#hover#vim#Supported() abort
  return exists( '*popup_atcursor' )
endfunction


function! youcompleteme#hover#vim#Close( window_id ) abort
  if a:window_id > 0
    call popup_close( a:window_id )
  endif
endfunction


function! youcompleteme#hover#vim#Hide( window_id ) abort
  if a:window_id > 0
    call popup_hide( a:window_id )
  endif
endfunction


function! youcompleteme#hover#vim#IsVisible( window_id ) abort
  if a:window_id <= 0
    return v:false
  endif
  let position = popup_getpos( a:window_id )
  return !empty( position ) && position.visible
endfunction


function! youcompleteme#hover#vim#Show(
      \ lines,
      \ syntax,
      \ custom_popup_params ) abort
  " Find the longest line (FIXME: probably doesn't work well for multi-byte).
  let longest_line = max( map( copy( a:lines ), 'len( v:val )' ) )

  let wrap = 0
  let column = 'cursor'

  " Maximum width is the number of screen columns minus horizontal padding.
  if longest_line >= (&columns - 2)
    let column = 1
    let wrap = 1
  endif

  let popup_params = {
        \ 'col': column,
        \ 'wrap': wrap,
        \ 'padding': [ 0, 1, 0, 1 ],
        \ 'moved': 'word',
        \ 'maxwidth': &columns,
        \ 'close': 'click',
        \ 'fixed': 0,
        \ }
  let popup_params = extend( popup_params, a:custom_popup_params )

  let window_id = popup_atcursor( a:lines, popup_params )
  call setbufvar( winbufnr( window_id ), '&syntax', a:syntax )
  return window_id
endfunction
