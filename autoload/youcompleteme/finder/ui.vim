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
" This is the editor-independent symbol-finder UI interface.

let s:is_neovim = has( 'nvim' )


function! youcompleteme#finder#ui#Supported() abort
  if s:is_neovim
    return youcompleteme#finder#ui#neovim#Supported()
  endif
  return youcompleteme#finder#ui#vim#Supported()
endfunction


function! youcompleteme#finder#ui#Create(
      \ initial_text,
      \ closed_callback ) abort
  if s:is_neovim
    return youcompleteme#finder#ui#neovim#Create(
          \ a:initial_text,
          \ a:closed_callback )
  endif
  return youcompleteme#finder#ui#vim#Create(
        \ a:initial_text,
        \ a:closed_callback )
endfunction


function! youcompleteme#finder#ui#BindKeys(
      \ window_id,
      \ prompt_buffer,
      \ key_handler ) abort
  if s:is_neovim
    call youcompleteme#finder#ui#neovim#BindKeys(
          \ a:window_id,
          \ a:prompt_buffer,
          \ a:key_handler )
    return
  endif
  call youcompleteme#finder#ui#vim#BindKeys(
        \ a:window_id,
        \ a:prompt_buffer,
        \ a:key_handler )
endfunction


function! youcompleteme#finder#ui#Close(
      \ window_id,
      \ selected ) abort
  if s:is_neovim
    call youcompleteme#finder#ui#neovim#Close(
          \ a:window_id,
          \ a:selected )
    return
  endif
  call youcompleteme#finder#ui#vim#Close(
        \ a:window_id,
        \ a:selected )
endfunction


function! youcompleteme#finder#ui#SetContents(
      \ window_id,
      \ contents ) abort
  if s:is_neovim
    call youcompleteme#finder#ui#neovim#SetContents(
          \ a:window_id,
          \ a:contents )
    return
  endif
  call youcompleteme#finder#ui#vim#SetContents(
        \ a:window_id,
        \ a:contents )
endfunction


function! youcompleteme#finder#ui#SetTitle(
      \ window_id,
      \ title ) abort
  if s:is_neovim
    call youcompleteme#finder#ui#neovim#SetTitle(
          \ a:window_id,
          \ a:title )
    return
  endif
  call youcompleteme#finder#ui#vim#SetTitle(
        \ a:window_id,
        \ a:title )
endfunction


function! youcompleteme#finder#ui#GetWidth( window_id ) abort
  if s:is_neovim
    return youcompleteme#finder#ui#neovim#GetWidth( a:window_id )
  endif
  return youcompleteme#finder#ui#vim#GetWidth( a:window_id )
endfunction


function! youcompleteme#finder#ui#GetHeight( window_id ) abort
  if s:is_neovim
    return youcompleteme#finder#ui#neovim#GetHeight( a:window_id )
  endif
  return youcompleteme#finder#ui#vim#GetHeight( a:window_id )
endfunction


function! youcompleteme#finder#ui#SetSelected(
      \ window_id,
      \ selected ) abort
  if s:is_neovim
    call youcompleteme#finder#ui#neovim#SetSelected(
          \ a:window_id,
          \ a:selected )
    return
  endif
  call youcompleteme#finder#ui#vim#SetSelected(
        \ a:window_id,
        \ a:selected )
endfunction


function! youcompleteme#finder#ui#Notify( text ) abort
  if s:is_neovim
    return youcompleteme#finder#ui#neovim#Notify( a:text )
  endif
  return youcompleteme#finder#ui#vim#Notify( a:text )
endfunction
