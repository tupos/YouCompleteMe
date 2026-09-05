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


function! youcompleteme#hierarchy#ui#vim#Supported() abort
  return py3eval( 'vimsupport.VimSupportsPopupWindows()' )
endfunction


function! youcompleteme#hierarchy#ui#vim#Create(
      \ key_handler,
      \ closed_callback ) abort
  call youcompleteme#list_ui#Initialise()

  let options = #{
        \   filter: a:key_handler,
        \   callback: a:closed_callback,
        \   wrap: 0,
        \   minwidth: &columns * 90 / 100,
        \   maxwidth: &columns * 90 / 100,
        \   maxheight: &lines * 75 / 100,
        \   scrollbar: 1,
        \   padding: [ 0, 0, 0, 0 ],
        \   highlight: 'Normal',
        \   border: [],
        \ }
  if &ambiwidth ==# 'single' && &encoding ==? 'utf-8'
    let options.borderchars = [
          \ '─',
          \ '│',
          \ '─',
          \ '│',
          \ '╭',
          \ '╮',
          \ '╯',
          \ '╰',
          \ ]
  endif

  return popup_create( [], options )
endfunction


function! youcompleteme#hierarchy#ui#vim#Close(
      \ window_id,
      \ result ) abort
  call popup_close( a:window_id, a:result )
endfunction
