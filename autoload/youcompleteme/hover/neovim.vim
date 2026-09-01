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

let s:supported_popup_params = [
      \ 'anchor_bias',
      \ 'border',
      \ 'close_events',
      \ 'focus',
      \ 'focus_id',
      \ 'focusable',
      \ 'height',
      \ 'max_height',
      \ 'max_width',
      \ 'offset_x',
      \ 'offset_y',
      \ 'relative',
      \ 'title',
      \ 'title_pos',
      \ 'width',
      \ 'wrap',
      \ 'wrap_at',
      \ 'zindex',
      \ ]


function! youcompleteme#hover#neovim#Supported() abort
  return exists( '*nvim_open_win' ) && exists( '*luaeval' )
endfunction


function! youcompleteme#hover#neovim#Close( window_id ) abort
  if a:window_id > 0 && nvim_win_is_valid( a:window_id )
    call nvim_win_close( a:window_id, v:true )
  endif
endfunction


function! youcompleteme#hover#neovim#Hide( window_id ) abort
  call youcompleteme#hover#neovim#Close( a:window_id )
endfunction


function! youcompleteme#hover#neovim#IsVisible( window_id ) abort
  return a:window_id > 0 && nvim_win_is_valid( a:window_id )
endfunction


function! s:ConvertPopupParams( popup_params ) abort
  let options = {
        \ 'focus': v:false,
        \ 'focusable': v:false,
        \ }

  for option_name in s:supported_popup_params
    if has_key( a:popup_params, option_name )
      let options[ option_name ] = a:popup_params[ option_name ]
    endif
  endfor

  " Accept Vim's names for the two commonly customised size limits.
  if ( has_key( a:popup_params, 'maxwidth' ) &&
       \ !has_key( options, 'max_width' ) )
    let options.max_width = a:popup_params.maxwidth
  endif
  if ( has_key( a:popup_params, 'maxheight' ) &&
       \ !has_key( options, 'max_height' ) )
    let options.max_height = a:popup_params.maxheight
  endif

  " Translate Vim's border character order to Neovim's order.
  let borderchars = get( a:popup_params, 'borderchars', [] )
  if type( borderchars ) == v:t_list && len( borderchars ) == 8
    let options.border = [
          \ borderchars[ 4 ], borderchars[ 0 ],
          \ borderchars[ 5 ], borderchars[ 1 ],
          \ borderchars[ 6 ], borderchars[ 2 ],
          \ borderchars[ 7 ], borderchars[ 3 ],
          \ ]
  elseif ( has_key( options, 'border' ) &&
         \ type( options.border ) == v:t_list &&
         \ empty( options.border ) )
    " In Vim, an empty border list enables the default border.
    let options.border = 'single'
  endif

  return options
endfunction


function! youcompleteme#hover#neovim#Show(
      \ lines,
      \ syntax,
      \ popup_params ) abort
  let popup = luaeval(
        \ '{ vim.lsp.util.open_floating_preview( ' .
        \ '_A.lines, _A.syntax, _A.options ) }', {
        \   'lines': a:lines,
        \   'syntax': a:syntax,
        \   'options': s:ConvertPopupParams( a:popup_params ),
        \ } )
  return popup[ 1 ]
endfunction
