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


function! youcompleteme#list_ui#vim#Initialise() abort
  call youcompleteme#symbol#InitSymbolProperties()
endfunction


function! youcompleteme#list_ui#vim#GetWidth( window_id ) abort
  return popup_getpos( a:window_id ).core_width
endfunction


function! youcompleteme#list_ui#vim#GetHeight( window_id ) abort
  return popup_getpos( a:window_id ).core_height
endfunction


function! youcompleteme#list_ui#vim#GetSelected( window_id ) abort
  let line_number = getcurpos( a:window_id )[ 1 ]
  if line_number <= 0
    return -1
  endif
  return line_number - 1
endfunction


function! youcompleteme#list_ui#vim#SetContents(
      \ window_id,
      \ contents,
      \ highlight_namespace ) abort
  if type( a:contents ) != v:t_list
    call popup_settext( a:window_id, a:contents )
    return
  endif

  let popup_lines = []
  for line in a:contents
    let properties = []
    for highlight in line.highlights
      call add(
            \ properties,
            \ {
            \   'col': highlight.column,
            \   'length': highlight.length,
            \   'type': highlight.group,
            \ } )
    endfor

    call add(
          \ popup_lines,
          \ {
          \   'text': line.text,
          \   'props': properties,
          \ } )
  endfor

  call popup_settext( a:window_id, popup_lines )
endfunction


function! youcompleteme#list_ui#vim#SetSelected(
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


function! youcompleteme#list_ui#vim#SetTabstop(
      \ window_id,
      \ tabstop ) abort
  call win_execute(
        \ a:window_id,
        \ 'setlocal tabstop=' . string( a:tabstop ) )
endfunction
