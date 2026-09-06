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
" This is the editor-independent detailed-diagnostic popup interface.

let s:is_neovim = has( 'nvim' )


function! youcompleteme#diagnostic_popup#Supported() abort
  if s:is_neovim
    return youcompleteme#diagnostic_popup#neovim#Supported()
  endif
  return youcompleteme#diagnostic_popup#vim#Supported()
endfunction


function! youcompleteme#diagnostic_popup#Show(
      \ lines,
      \ buffer_number,
      \ cursor_position,
      \ diagnostic ) abort
  if s:is_neovim
    return youcompleteme#diagnostic_popup#neovim#Show(
          \ a:lines,
          \ a:buffer_number,
          \ a:cursor_position,
          \ a:diagnostic )
  endif
  return youcompleteme#diagnostic_popup#vim#Show(
        \ a:lines,
        \ a:buffer_number,
        \ a:cursor_position,
        \ a:diagnostic )
endfunction
