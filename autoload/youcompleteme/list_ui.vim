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
" This is the editor-independent interface for rendering selectable lists.

let s:is_neovim = has( 'nvim' )


function! youcompleteme#list_ui#Initialise() abort
  if s:is_neovim
    call youcompleteme#list_ui#neovim#Initialise()
    return
  endif
  call youcompleteme#list_ui#vim#Initialise()
endfunction


function! youcompleteme#list_ui#GetWidth( window_id ) abort
  if s:is_neovim
    return youcompleteme#list_ui#neovim#GetWidth( a:window_id )
  endif
  return youcompleteme#list_ui#vim#GetWidth( a:window_id )
endfunction


function! youcompleteme#list_ui#GetHeight( window_id ) abort
  if s:is_neovim
    return youcompleteme#list_ui#neovim#GetHeight( a:window_id )
  endif
  return youcompleteme#list_ui#vim#GetHeight( a:window_id )
endfunction


function! youcompleteme#list_ui#GetSelected( window_id ) abort
  if s:is_neovim
    return youcompleteme#list_ui#neovim#GetSelected( a:window_id )
  endif
  return youcompleteme#list_ui#vim#GetSelected( a:window_id )
endfunction


function! youcompleteme#list_ui#SetContents(
      \ window_id,
      \ contents,
      \ highlight_namespace ) abort
  if s:is_neovim
    call youcompleteme#list_ui#neovim#SetContents(
          \ a:window_id,
          \ a:contents,
          \ a:highlight_namespace )
    return
  endif
  call youcompleteme#list_ui#vim#SetContents(
        \ a:window_id,
        \ a:contents,
        \ a:highlight_namespace )
endfunction


function! youcompleteme#list_ui#SetSelected(
      \ window_id,
      \ selected ) abort
  if s:is_neovim
    call youcompleteme#list_ui#neovim#SetSelected(
          \ a:window_id,
          \ a:selected )
    return
  endif
  call youcompleteme#list_ui#vim#SetSelected(
        \ a:window_id,
        \ a:selected )
endfunction


function! youcompleteme#list_ui#SetTabstop(
      \ window_id,
      \ tabstop ) abort
  if s:is_neovim
    call youcompleteme#list_ui#neovim#SetTabstop(
          \ a:window_id,
          \ a:tabstop )
    return
  endif
  call youcompleteme#list_ui#vim#SetTabstop(
        \ a:window_id,
        \ a:tabstop )
endfunction
