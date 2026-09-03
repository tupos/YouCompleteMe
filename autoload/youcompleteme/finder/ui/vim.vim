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


function! youcompleteme#finder#ui#vim#Supported() abort
  return py3eval( 'vimsupport.VimSupportsPopupWindows()' )
endfunction


function! youcompleteme#finder#ui#vim#Create(
      \ initial_text,
      \ closed_callback ) abort
  call youcompleteme#symbol#InitSymbolProperties()

  let options = {
        \ 'padding': [ 1, 2, 1, 2 ],
        \ 'wrap': 0,
        \ 'minwidth': &columns / 3 * 2,
        \ 'minheight': &lines / 3 * 2,
        \ 'maxwidth': &columns / 3 * 2,
        \ 'maxheight': &lines / 3 * 2,
        \ 'line': &lines / 6,
        \ 'col': &columns / 6,
        \ 'pos': 'topleft',
        \ 'drag': 1,
        \ 'resize': 1,
        \ 'close': 'button',
        \ 'border': [],
        \ 'callback': a:closed_callback,
        \ 'highlight': 'Normal',
        \ }

  if &ambiwidth ==# 'single' && &encoding ==? 'utf-8'
    let options.borderchars = [
          \ '─',
          \ '│',
          \ '─',
          \ '│',
          \ '╭',
          \ '╮',
          \ '┛',
          \ '╰',
          \ ]
  endif

  return popup_create( a:initial_text, options )
endfunction


function! youcompleteme#finder#ui#vim#BindKeys(
      \ window_id,
      \ prompt_buffer,
      \ key_handler ) abort
  call popup_setoptions(
        \ a:window_id,
        \ { 'filter': a:key_handler } )
endfunction


function! youcompleteme#finder#ui#vim#Close(
      \ window_id,
      \ selected ) abort
  call popup_close( a:window_id, a:selected )
endfunction


function! youcompleteme#finder#ui#vim#SetContents(
      \ window_id,
      \ contents ) abort
  call popup_settext( a:window_id, a:contents )
endfunction


function! youcompleteme#finder#ui#vim#SetTitle(
      \ window_id,
      \ title ) abort
  call popup_setoptions(
        \ a:window_id,
        \ { 'title': a:title } )
endfunction


function! youcompleteme#finder#ui#vim#GetWidth( window_id ) abort
  return popup_getpos( a:window_id ).core_width
endfunction


function! youcompleteme#finder#ui#vim#GetHeight( window_id ) abort
  return popup_getpos( a:window_id ).core_height
endfunction


function! youcompleteme#finder#ui#vim#SetSelected(
      \ window_id,
      \ selected ) abort
  if a:selected < 0
    call win_execute( a:window_id, 'set nocursorline' )
    return
  endif

  " Move the cursor so that cursorline highlights the selected item. Also
  " scroll the window if the selected item is not in view. To make scrolling
  " feel natural we position the current line at the bottom of the window if
  " the new current line is below the current viewport, and at the top if the
  " new current line is above the viewport.
  let line_number = a:selected + 1
  let position = popup_getpos( a:window_id )

  call win_execute(
        \ a:window_id,
        \ 'call cursor( [' . string( line_number ) . ', 1] )' )

  if line_number < position.firstline
    call win_execute( a:window_id, "normal z\<CR>" )
  elseif line_number >= position.firstline + position.core_height
    call win_execute( a:window_id, 'normal z-' )
  endif

  if !getwinvar( a:window_id, '&cursorline' )
    call win_execute(
          \ a:window_id,
          \ 'set cursorline cursorlineopt&' )
  endif
endfunction


function! youcompleteme#finder#ui#vim#Notify( text ) abort
  return popup_notification(
        \ a:text,
        \ {
        \   'line': 1,
        \   'col': &columns - len( a:text ),
        \   'padding': [ 0, 0, 0, 0 ],
        \   'border': [ 0, 0, 0, 0 ],
        \   'highlight': 'PMenu',
        \ } )
endfunction
