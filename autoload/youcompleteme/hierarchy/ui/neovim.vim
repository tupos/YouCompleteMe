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


function! youcompleteme#hierarchy#ui#neovim#Supported() abort
  return has( 'nvim-0.9' )
        \ && exists( '*nvim_open_win' )
        \ && exists( '*nvim_set_option_value' )
        \ && exists( '##WinClosed' )
endfunction


function! s:MappingRhs( key ) abort
  " Prevent key notation in the argument from being expanded as part of the
  " mapping itself.
  let escaped_key = substitute( a:key, '<', '<lt>', 'g' )
  return '<Cmd>call '
        \ . 'youcompleteme#hierarchy#ui#neovim#HandleKey('
        \ . string( escaped_key )
        \ . ')<CR>'
endfunction


function! s:BindKeys( buffer_number ) abort
  let mapping_options = {
        \ 'noremap': v:true,
        \ 'silent': v:true,
        \ 'nowait': v:true,
        \ }
  let mappings = [
        \ '<Tab>',
        \ '<S-Tab>',
        \ '<CR>',
        \ '<Down>',
        \ '<C-n>',
        \ '<C-j>',
        \ 'j',
        \ '<Up>',
        \ '<C-p>',
        \ '<C-k>',
        \ 'k',
        \ '<Esc>',
        \ '<C-c>',
        \ 'q',
        \ ]

  for lhs in mappings
    call nvim_buf_set_keymap(
          \ a:buffer_number,
          \ 'n',
          \ lhs,
          \ s:MappingRhs( lhs ),
          \ mapping_options )
  endfor
endfunction


function! youcompleteme#hierarchy#ui#neovim#HandleKey( key ) abort
  let KeyHandler = getbufvar(
        \ bufnr(),
        \ 'ycm_hierarchy_key_handler',
        \ v:null )
  if type( KeyHandler ) != v:t_func
    return
  endif

  let window_id = getbufvar(
        \ bufnr(),
        \ 'ycm_hierarchy_window_id',
        \ -1 )
  let key = nvim_replace_termcodes(
        \ a:key,
        \ v:true,
        \ v:true,
        \ v:true )
  call call( KeyHandler, [ window_id, key ] )
endfunction


function! s:InvokeClosedCallback(
      \ Callback,
      \ window_id,
      \ result,
      \ timer_id ) abort
  call call(
        \ a:Callback,
        \ [ a:window_id, a:result ] )
endfunction


function! youcompleteme#hierarchy#ui#neovim#WindowClosed(
      \ window_id,
      \ buffer_number ) abort
  let Callback = getbufvar(
        \ a:buffer_number,
        \ 'ycm_hierarchy_closed_callback',
        \ v:null )
  if type( Callback ) != v:t_func
    return
  endif

  let result = getbufvar(
        \ a:buffer_number,
        \ 'ycm_hierarchy_close_result',
        \ v:null )
  if type( result ) != v:t_list
    let selected = youcompleteme#list_ui#GetSelected( a:window_id )
    let result = [
          \ max( [ 0, selected ] ),
          \ 'cancel',
          \ v:null,
          \ ]
  endif

  call setbufvar(
        \ a:buffer_number,
        \ 'ycm_hierarchy_closed_callback',
        \ v:null )

  " WinClosed runs before the window has been removed. Defer controller
  " actions until Neovim has finished closing the floating window.
  call timer_start(
        \ 0,
        \ function(
        \   's:InvokeClosedCallback',
        \   [ Callback, a:window_id, result ] ) )
endfunction


function! youcompleteme#hierarchy#ui#neovim#Create(
      \ key_handler,
      \ closed_callback ) abort
  call youcompleteme#list_ui#Initialise()

  let buffer_number = nvim_create_buf( v:false, v:true )
  call setbufvar( buffer_number, '&bufhidden', 'wipe' )
  call setbufvar( buffer_number, '&modifiable', v:false )
  call setbufvar(
        \ buffer_number,
        \ 'ycm_hierarchy_window',
        \ v:true )
  call setbufvar(
        \ buffer_number,
        \ 'ycm_hierarchy_key_handler',
        \ a:key_handler )
  call setbufvar(
        \ buffer_number,
        \ 'ycm_hierarchy_closed_callback',
        \ a:closed_callback )
  call setbufvar(
        \ buffer_number,
        \ 'ycm_hierarchy_close_result',
        \ v:null )

  let width = max( [ 1, &columns * 90 / 100 ] )
  let height = 1
  let border = 'single'
  if &ambiwidth ==# 'single' && &encoding ==? 'utf-8'
    let border = [
          \ '╭',
          \ '─',
          \ '╮',
          \ '│',
          \ '╯',
          \ '─',
          \ '╰',
          \ '│',
          \ ]
  endif

  let window_id = nvim_open_win(
        \ buffer_number,
        \ v:true,
        \ {
        \   'relative': 'editor',
        \   'row': max( [ 0, ( &lines - height - 2 ) / 2 ] ),
        \   'col': max( [ 0, ( &columns - width - 2 ) / 2 ] ),
        \   'width': width,
        \   'height': height,
        \   'anchor': 'NW',
        \   'style': 'minimal',
        \   'focusable': v:true,
        \   'border': border,
        \ } )
  call setbufvar(
        \ buffer_number,
        \ 'ycm_hierarchy_window_id',
        \ window_id )
  call nvim_set_option_value(
        \ 'winhighlight',
        \ 'NormalFloat:Normal,FloatBorder:Normal,CursorLine:PmenuSel',
        \ { 'win': window_id } )
  call nvim_set_option_value(
        \ 'wrap',
        \ v:false,
        \ { 'win': window_id } )

  call s:BindKeys( buffer_number )

  augroup YCMHierarchyNeovim
    execute 'autocmd WinClosed '
          \ . window_id
          \ . ' ++once call '
          \ . 'youcompleteme#hierarchy#ui#neovim#WindowClosed('
          \ . window_id
          \ . ', '
          \ . buffer_number
          \ . ')'
  augroup END

  return window_id
endfunction


function! youcompleteme#hierarchy#ui#neovim#UpdateLayout(
      \ window_id,
      \ line_count ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  let width = max( [ 1, &columns * 90 / 100 ] )
  let maximum_height = max( [ 1, &lines * 75 / 100 ] )
  let height = max( [
        \ 1,
        \ min( [ a:line_count, maximum_height ] ),
        \ ] )
  call nvim_win_set_config(
        \ a:window_id,
        \ {
        \   'relative': 'editor',
        \   'row': max( [ 0, ( &lines - height - 2 ) / 2 ] ),
        \   'col': max( [ 0, ( &columns - width - 2 ) / 2 ] ),
        \   'width': width,
        \   'height': height,
        \ } )
endfunction


function! youcompleteme#hierarchy#ui#neovim#Close(
      \ window_id,
      \ result ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  call setbufvar(
        \ nvim_win_get_buf( a:window_id ),
        \ 'ycm_hierarchy_close_result',
        \ a:result )
  call nvim_win_close( a:window_id, v:true )
endfunction
