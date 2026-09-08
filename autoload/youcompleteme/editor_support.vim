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

let s:is_neovim = has( 'nvim' )
let s:minimum_vim_version = '9.1.0016'
let s:minimum_neovim_version = '0.5'

" Feature versions belong here rather than in their implementations.
let s:minimum_neovim_feature_versions = {
      \ 'completion_info_popup': '0.10',
      \ 'finder': '0.9',
      \ 'hierarchy': '0.9',
      \ 'popup_windows': '0.5',
      \ 'semantic_highlighting': '0.5',
      \ 'signature_help': '0.10',
      \ 'virtual_text': '0.10',
      \ }


function! s:VersionAtLeast( version ) abort
  let version_feature = s:is_neovim ? 'nvim-' : 'patch-'
  return has( version_feature . a:version )
        \ ? v:true
        \ : v:false
endfunction


function! youcompleteme#editor_support#MinimumVersion() abort
  return s:is_neovim
        \ ? s:minimum_neovim_version
        \ : s:minimum_vim_version
endfunction


function! youcompleteme#editor_support#Supported() abort
  return s:VersionAtLeast(
        \ youcompleteme#editor_support#MinimumVersion() )
endfunction


function! youcompleteme#editor_support#FeatureSupported( feature ) abort
  if !has_key( s:minimum_neovim_feature_versions, a:feature )
    throw 'Unknown YCM editor feature: ' . a:feature
  endif

  if !youcompleteme#editor_support#Supported()
    return v:false
  endif

  if !s:is_neovim
    return v:true
  endif

  return s:VersionAtLeast(
        \ s:minimum_neovim_feature_versions[ a:feature ] )
endfunction
