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
"
" This is the editor-independent hover-window interface.

let s:is_neovim = has( 'nvim' )


function! youcompleteme#hover#Supported() abort
  if s:is_neovim
    return youcompleteme#hover#neovim#Supported()
  endif
  return youcompleteme#hover#vim#Supported()
endfunction


function! youcompleteme#hover#Close( window_id ) abort
  if s:is_neovim
    call youcompleteme#hover#neovim#Close( a:window_id )
    return
  endif
  call youcompleteme#hover#vim#Close( a:window_id )
endfunction


function! youcompleteme#hover#Hide( window_id ) abort
  if s:is_neovim
    call youcompleteme#hover#neovim#Hide( a:window_id )
    return
  endif
  call youcompleteme#hover#vim#Hide( a:window_id )
endfunction


function! youcompleteme#hover#IsVisible( window_id ) abort
  if s:is_neovim
    return youcompleteme#hover#neovim#IsVisible( a:window_id )
  endif
  return youcompleteme#hover#vim#IsVisible( a:window_id )
endfunction


function! youcompleteme#hover#Show( lines, syntax, popup_params ) abort
  if s:is_neovim
    return youcompleteme#hover#neovim#Show(
          \ a:lines,
          \ a:syntax,
          \ a:popup_params )
  endif
  return youcompleteme#hover#vim#Show(
        \ a:lines,
        \ a:syntax,
        \ a:popup_params )
endfunction
