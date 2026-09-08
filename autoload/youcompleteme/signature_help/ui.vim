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
" This is the editor-independent signature-help UI interface.

let s:is_neovim = has( 'nvim' )


function! youcompleteme#signature_help#ui#Supported() abort
  if s:is_neovim
    return v:false
  endif
  return youcompleteme#signature_help#ui#vim#Supported()
endfunction


function! youcompleteme#signature_help#ui#Render(
      \ window_id,
      \ presentation,
      \ anchor,
      \ hidden,
      \ syntax ) abort
  if s:is_neovim
    return 0
  endif
  return youcompleteme#signature_help#ui#vim#Render(
        \ a:window_id,
        \ a:presentation,
        \ a:anchor,
        \ a:hidden,
        \ a:syntax )
endfunction


function! youcompleteme#signature_help#ui#Close( window_id ) abort
  if s:is_neovim
    return
  endif
  call youcompleteme#signature_help#ui#vim#Close( a:window_id )
endfunction


function! youcompleteme#signature_help#ui#Hide( window_id ) abort
  if s:is_neovim
    return
  endif
  call youcompleteme#signature_help#ui#vim#Hide( a:window_id )
endfunction


function! youcompleteme#signature_help#ui#Show( window_id ) abort
  if s:is_neovim
    return
  endif
  call youcompleteme#signature_help#ui#vim#Show( a:window_id )
endfunction
