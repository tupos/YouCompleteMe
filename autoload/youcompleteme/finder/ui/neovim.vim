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


let s:highlight_namespace = nvim_create_namespace( 'ycm_finder' )


function! youcompleteme#finder#ui#neovim#Supported() abort
  return has( 'nvim-0.9' )
        \ && exists( '*nvim_open_win' )
        \ && exists( '*nvim_buf_set_extmark' )
        \ && exists( '*prompt_setprompt' )
        \ && exists( '##WinClosed' )
endfunction


function! s:InvokeClosedCallback(
      \ Callback,
      \ window_id,
      \ selected,
      \ timer_id ) abort
  call call(
        \ a:Callback,
        \ [ a:window_id, a:selected ] )
endfunction


function! youcompleteme#finder#ui#neovim#WindowClosed(
      \ window_id,
      \ buffer_number ) abort
  let Callback = getbufvar(
        \ a:buffer_number,
        \ 'ycm_finder_closed_callback',
        \ v:null )
  if type( Callback ) != v:t_func
    return
  endif

  let selected = getbufvar(
        \ a:buffer_number,
        \ 'ycm_finder_selected',
        \ -1 )
  call setbufvar(
        \ a:buffer_number,
        \ 'ycm_finder_closed_callback',
        \ v:null )

  " WinClosed runs before the window has been removed. Defer finder cleanup
  " until Neovim returns to its main loop and finishes closing the window.
  call timer_start(
        \ 0,
        \ function(
        \   's:InvokeClosedCallback',
        \   [ Callback, a:window_id, selected ] ) )
endfunction


function! youcompleteme#finder#ui#neovim#Create(
      \ initial_text,
      \ closed_callback ) abort
  for [ highlight_group, default_highlight_group ] in
        \ items( youcompleteme#symbol#GetHighlightGroups() )
    execute 'highlight default link '
          \ . highlight_group
          \ . ' '
          \ . default_highlight_group
  endfor

  let buffer_number = nvim_create_buf( v:false, v:true )
  call setbufvar( buffer_number, '&bufhidden', 'wipe' )
  call nvim_buf_set_lines(
        \ buffer_number,
        \ 0,
        \ -1,
        \ v:true,
        \ [ a:initial_text ] )
  call setbufvar( buffer_number, '&modifiable', v:false )
  call setbufvar(
        \ buffer_number,
        \ 'ycm_finder_closed_callback',
        \ a:closed_callback )
  call setbufvar(
        \ buffer_number,
        \ 'ycm_finder_selected',
        \ -1 )

  let border = 'single'
  if &ambiwidth ==# 'single' && &encoding ==? 'utf-8'
    let border = [
          \ '╭',
          \ '─',
          \ '╮',
          \ '│',
          \ '┛',
          \ '─',
          \ '╰',
          \ '│',
          \ ]
  endif

  let window_id = nvim_open_win(
        \ buffer_number,
        \ v:false,
        \ {
        \   'relative': 'editor',
        \   'row': &lines / 6,
        \   'col': &columns / 6,
        \   'width': max( [ 1, &columns / 3 * 2 ] ),
        \   'height': max( [ 1, &lines / 3 * 2 ] ),
        \   'anchor': 'NW',
        \   'style': 'minimal',
        \   'focusable': v:false,
        \   'mouse': v:false,
        \   'border': border,
        \ } )
  call nvim_set_option_value(
        \ 'winhighlight',
        \ 'NormalFloat:Normal,FloatBorder:Normal,FloatTitle:Normal',
        \ { 'win': window_id } )
  call setwinvar( window_id, '&wrap', 0 )

  augroup YCMFinderNeovim
    autocmd!
    execute 'autocmd WinClosed '
          \ . window_id
          \ . ' ++once call '
          \ . 'youcompleteme#finder#ui#neovim#WindowClosed('
          \ . window_id
          \ . ', '
          \ . buffer_number
          \ . ')'
  augroup END

  return window_id
endfunction


function! s:MappingRhs( key ) abort
  " Prevent key notation in the argument from being expanded as part of the
  " mapping itself.
  let escaped_key = substitute( a:key, '<', '<lt>', 'g' )
  return '<Cmd>call '
        \ . 'youcompleteme#finder#ui#neovim#HandleMappedKey('
        \ . string( escaped_key )
        \ . ')<CR>'
endfunction


function! youcompleteme#finder#ui#neovim#HandleMappedKey( key ) abort
  let KeyHandler = getbufvar(
        \ bufnr(),
        \ 'ycm_finder_key_handler',
        \ v:null )
  if type( KeyHandler ) != v:t_func
    return
  endif

  let window_id = getbufvar(
        \ bufnr(),
        \ 'ycm_finder_window_id',
        \ -1 )
  let key = nvim_replace_termcodes(
        \ a:key,
        \ v:true,
        \ v:true,
        \ v:true )
  call call( KeyHandler, [ window_id, key ] )
endfunction


function! youcompleteme#finder#ui#neovim#PromptInterrupted() abort
  call youcompleteme#finder#ui#neovim#HandleMappedKey( '<C-c>' )
endfunction


function! youcompleteme#finder#ui#neovim#MapEnter() abort
  let window_id = getbufvar(
        \ bufnr(),
        \ 'ycm_finder_window_id',
        \ -1 )
  if window_id <= 0 || !nvim_win_is_valid( window_id )
    return '<CR>'
  endif

  let selected = getbufvar(
        \ nvim_win_get_buf( window_id ),
        \ 'ycm_finder_selected',
        \ -1 )
  if selected < 0
    return '<CR>'
  endif

  " Leave Insert mode after closing the float so that Neovim can return to its
  " event loop and run the deferred WinClosed callback.
  return s:MappingRhs( '<CR>' ) . '<C-\><C-N>'
endfunction


function! youcompleteme#finder#ui#neovim#BindKeys(
      \ window_id,
      \ prompt_buffer,
      \ key_handler ) abort
  call setbufvar(
        \ a:prompt_buffer,
        \ 'ycm_finder_window_id',
        \ a:window_id )
  call setbufvar(
        \ a:prompt_buffer,
        \ 'ycm_finder_key_handler',
        \ a:key_handler )
  call prompt_setinterrupt(
        \ a:prompt_buffer,
        \ function(
        \   'youcompleteme#finder#ui#neovim#PromptInterrupted' ) )

  let mapping_options = {
        \ 'noremap': v:true,
        \ 'silent': v:true,
        \ 'nowait': v:true,
        \ }
  let mappings = [
        \ '<C-j>',
        \ '<Down>',
        \ '<C-n>',
        \ '<Tab>',
        \ '<C-k>',
        \ '<Up>',
        \ '<C-p>',
        \ '<S-Tab>',
        \ '<PageDown>',
        \ '<kPageDown>',
        \ '<PageUp>',
        \ '<kPageUp>',
        \ '<Home>',
        \ '<kHome>',
        \ '<End>',
        \ '<kEnd>',
        \ '<C-f>',
        \ ]

  for lhs in mappings
    for mode in [ 'i', 'n' ]
      call nvim_buf_set_keymap(
            \ a:prompt_buffer,
            \ mode,
            \ lhs,
            \ s:MappingRhs( lhs ),
            \ mapping_options )
    endfor
  endfor

  call nvim_buf_set_keymap(
        \ a:prompt_buffer,
        \ 'n',
        \ '<C-c>',
        \ s:MappingRhs( '<C-c>' ),
        \ mapping_options )

  for mode in [ 'i', 'n' ]
    call nvim_buf_set_keymap(
          \ a:prompt_buffer,
          \ mode,
          \ '<CR>',
          \ 'youcompleteme#finder#ui#neovim#MapEnter()',
          \ extend(
          \   copy( mapping_options ),
          \   {
          \     'expr': v:true,
          \     'replace_keycodes': v:true,
          \   } ) )
  endfor
endfunction


function! youcompleteme#finder#ui#neovim#Close(
      \ window_id,
      \ selected ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  call setbufvar(
        \ nvim_win_get_buf( a:window_id ),
        \ 'ycm_finder_selected',
        \ a:selected )
  call nvim_win_close( a:window_id, v:true )
endfunction


function! youcompleteme#finder#ui#neovim#SetContents(
      \ window_id,
      \ contents ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  let buffer_number = nvim_win_get_buf( a:window_id )
  if type( a:contents ) == v:t_list
    let lines = map(
          \ copy( a:contents ),
          \ { _, line -> line.text } )
  else
    let lines = [ a:contents ]
  endif

  call setbufvar( buffer_number, '&modifiable', v:true )
  call nvim_buf_set_lines(
        \ buffer_number,
        \ 0,
        \ -1,
        \ v:true,
        \ lines )
  call setbufvar( buffer_number, '&modifiable', v:false )
  call nvim_buf_clear_namespace(
        \ buffer_number,
        \ s:highlight_namespace,
        \ 0,
        \ -1 )

  if type( a:contents ) != v:t_list
    return
  endif

  let line_number = 0
  for line in a:contents
    for highlight in line.highlights
      let start_column = highlight.column - 1
      call nvim_buf_set_extmark(
            \ buffer_number,
            \ s:highlight_namespace,
            \ line_number,
            \ start_column,
            \ {
            \   'end_col': start_column + highlight.length,
            \   'hl_group': highlight.group,
            \ } )
    endfor
    let line_number += 1
  endfor
endfunction


function! youcompleteme#finder#ui#neovim#SetTitle(
      \ window_id,
      \ title ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  call nvim_win_set_config(
        \ a:window_id,
        \ {
        \   'title': a:title,
        \   'title_pos': 'left',
        \ } )
endfunction


function! youcompleteme#finder#ui#neovim#GetWidth( window_id ) abort
  return nvim_win_get_width( a:window_id )
endfunction


function! youcompleteme#finder#ui#neovim#GetHeight( window_id ) abort
  return nvim_win_get_height( a:window_id )
endfunction


function! youcompleteme#finder#ui#neovim#SetSelected(
      \ window_id,
      \ selected ) abort
  if a:window_id <= 0 || !nvim_win_is_valid( a:window_id )
    return
  endif

  call setbufvar(
        \ nvim_win_get_buf( a:window_id ),
        \ 'ycm_finder_selected',
        \ a:selected )

  if a:selected < 0
    call nvim_set_option_value(
          \ 'cursorline',
          \ v:false,
          \ { 'win': a:window_id } )
    return
  endif

  " Move the cursor so that cursorline highlights the selected item. Also
  " scroll the window if the selected item is not in view. To make scrolling
  " feel natural we position the current line at the bottom of the window if
  " the new current line is below the current viewport, and at the top if the
  " new current line is above the viewport.
  let line_number = a:selected + 1
  let first_line = line( 'w0', a:window_id )
  let window_height = nvim_win_get_height( a:window_id )

  call nvim_win_set_cursor(
        \ a:window_id,
        \ [ line_number, 0 ] )

  if line_number < first_line
    call win_execute( a:window_id, 'normal! zt' )
  elseif line_number >= first_line + window_height
    call win_execute( a:window_id, 'normal! zb' )
  endif

  call nvim_set_option_value(
        \ 'cursorlineopt',
        \ 'both',
        \ { 'win': a:window_id } )
  call nvim_set_option_value(
        \ 'cursorline',
        \ v:true,
        \ { 'win': a:window_id } )
endfunction


function! s:CloseNotification( window_id, timer_id ) abort
  if a:window_id > 0 && nvim_win_is_valid( a:window_id )
    call nvim_win_close( a:window_id, v:true )
  endif
endfunction


function! youcompleteme#finder#ui#neovim#Notify( text ) abort
  let buffer_number = nvim_create_buf( v:false, v:true )
  call setbufvar( buffer_number, '&bufhidden', 'wipe' )
  call nvim_buf_set_lines(
        \ buffer_number,
        \ 0,
        \ -1,
        \ v:true,
        \ [ a:text ] )
  call setbufvar( buffer_number, '&modifiable', v:false )

  let width = min( [
        \ max( [ 1, strdisplaywidth( a:text ) ] ),
        \ &columns,
        \ ] )
  let window_id = nvim_open_win(
        \ buffer_number,
        \ v:false,
        \ {
        \   'relative': 'editor',
        \   'row': 0,
        \   'col': &columns,
        \   'width': width,
        \   'height': 1,
        \   'anchor': 'NE',
        \   'style': 'minimal',
        \   'focusable': v:false,
        \   'mouse': v:false,
        \   'zindex': 300,
        \ } )
  call nvim_set_option_value(
        \ 'winhighlight',
        \ 'Normal:PMenu',
        \ { 'win': window_id } )
  call timer_start(
        \ 3000,
        \ function(
        \   's:CloseNotification',
        \   [ window_id ] ) )

  return window_id
endfunction
