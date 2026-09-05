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
" This is the editor-independent hierarchy-window interface.

let s:is_neovim = has( 'nvim' )


function! youcompleteme#hierarchy#ui#Supported() abort
  if s:is_neovim
    return youcompleteme#hierarchy#ui#neovim#Supported()
  endif
  return youcompleteme#hierarchy#ui#vim#Supported()
endfunction


function! youcompleteme#hierarchy#ui#Create(
      \ key_handler,
      \ closed_callback ) abort
  if s:is_neovim
    return youcompleteme#hierarchy#ui#neovim#Create(
          \ a:key_handler,
          \ a:closed_callback )
  endif
  return youcompleteme#hierarchy#ui#vim#Create(
        \ a:key_handler,
        \ a:closed_callback )
endfunction


function! youcompleteme#hierarchy#ui#UpdateLayout(
      \ window_id,
      \ line_count ) abort
  if s:is_neovim
    call youcompleteme#hierarchy#ui#neovim#UpdateLayout(
          \ a:window_id,
          \ a:line_count )
  endif
endfunction


function! youcompleteme#hierarchy#ui#Close(
      \ window_id,
      \ result ) abort
  if s:is_neovim
    call youcompleteme#hierarchy#ui#neovim#Close(
          \ a:window_id,
          \ a:result )
    return
  endif
  call youcompleteme#hierarchy#ui#vim#Close(
        \ a:window_id,
        \ a:result )
endfunction
