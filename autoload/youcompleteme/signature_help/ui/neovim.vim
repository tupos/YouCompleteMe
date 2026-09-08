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


function! s:Namespace() abort
  return nvim_create_namespace( 'ycm_signature_help' )
endfunction


function! youcompleteme#signature_help#ui#neovim#Supported() abort
  return youcompleteme#editor_support#FeatureSupported(
        \ 'signature_help' )
endfunction


function! youcompleteme#signature_help#ui#neovim#Initialise() abort
  if !youcompleteme#signature_help#ui#neovim#Supported()
    return v:false
  endif

  highlight default YCMInverse term=reverse cterm=reverse gui=reverse
  call s:Namespace()
  return v:true
endfunction


function! s:ContentSize( source_window_id, lines ) abort
  let maximum_width = max( [
        \ 1,
        \ min( [ nvim_win_get_width( a:source_window_id ), &columns ] ) - 2,
        \ ] )
  let width = 1
  for line in a:lines
    let width = max( [ width, strdisplaywidth( line ) ] )
  endfor
  let width = min( [ width, maximum_width ] )

  let height = 0
  for line in a:lines
    let line_width = max( [ 1, strdisplaywidth( line ) ] )
    let height += ( line_width + width - 1 ) / width
  endfor

  return [ width, max( [ 1, height ] ) ]
endfunction


function! s:MakeLayout(
      \ source_window_id,
      \ anchor,
      \ screen_position,
      \ width,
      \ desired_height,
      \ available_height,
      \ position ) abort
  let height = min( [ a:desired_height, a:available_height ] )
  let outer_width = a:width + 2
  let outer_height = height + 2
  let anchor_row = a:screen_position.row - 1
  let maximum_top = max( [
        \ 0,
        \ &lines - &cmdheight - outer_height,
        \ ] )

  if a:position ==# 'above'
    let top = anchor_row - outer_height
    let anchor = 'SW'
    let row = 0
  else
    let top = anchor_row + 1
    let anchor = 'NW'
    let row = 1
  endif

  let top = max( [ 0, min( [ top, maximum_top ] ) ] )
  let left = max( [
        \ 0,
        \ min( [
        \   a:screen_position.curscol - 2,
        \   &columns - outer_width,
        \ ] ),
        \ ] )

  return {
        \ 'top': top,
        \ 'left': left,
        \ 'outer_width': outer_width,
        \ 'outer_height': outer_height,
        \ 'config': {
        \   'relative': 'win',
        \   'win': a:source_window_id,
        \   'bufpos': a:anchor,
        \   'row': row,
        \   'col': -1,
        \   'width': a:width,
        \   'height': height,
        \   'anchor': anchor,
        \   'style': 'minimal',
        \   'focusable': v:false,
        \   'mouse': v:false,
        \   'border': 'single',
        \   'hide': v:true,
        \ },
        \ }
endfunction


function! s:Layouts(
      \ source_window_id,
      \ anchor,
      \ lines ) abort
  let screen_position = screenpos(
        \ a:source_window_id,
        \ a:anchor[ 0 ] + 1,
        \ a:anchor[ 1 ] + 1 )
  if screen_position.row <= 0 || screen_position.curscol <= 0
    return []
  endif

  let [ width, desired_height ] =
        \ s:ContentSize( a:source_window_id, a:lines )
  let anchor_row = screen_position.row - 1
  let above_height = anchor_row - 2
  let below_height =
        \ &lines - &cmdheight - anchor_row - 3

  if above_height >= desired_height
    let positions = [ 'above', 'below' ]
  elseif below_height >= desired_height
    let positions = [ 'below', 'above' ]
  elseif above_height >= below_height
    let positions = [ 'above', 'below' ]
  else
    let positions = [ 'below', 'above' ]
  endif

  let layouts = []
  for position in positions
    let available_height = position ==# 'above'
          \ ? above_height
          \ : below_height
    if available_height < 1
      continue
    endif

    call add(
          \ layouts,
          \ s:MakeLayout(
          \   a:source_window_id,
          \   a:anchor,
          \   screen_position,
          \   width,
          \   desired_height,
          \   available_height,
          \   position ) )
  endfor

  return layouts
endfunction


function! s:RectanglesOverlap(
      \ first_top,
      \ first_left,
      \ first_height,
      \ first_width,
      \ second_top,
      \ second_left,
      \ second_height,
      \ second_width ) abort
  return a:first_top < a:second_top + a:second_height
        \ && a:second_top < a:first_top + a:first_height
        \ && a:first_left < a:second_left + a:second_width
        \ && a:second_left < a:first_left + a:first_width
endfunction


function! s:OverlapsCursor( source_window_id, layout ) abort
  let cursor = nvim_win_get_cursor( a:source_window_id )
  let cursor_position = screenpos(
        \ a:source_window_id,
        \ cursor[ 0 ],
        \ cursor[ 1 ] + 1 )
  if cursor_position.row <= 0 || cursor_position.curscol <= 0
    return v:false
  endif

  return s:RectanglesOverlap(
        \ a:layout.top,
        \ a:layout.left,
        \ a:layout.outer_height,
        \ a:layout.outer_width,
        \ cursor_position.row - 1,
        \ cursor_position.curscol - 1,
        \ 1,
        \ 1 )
endfunction


function! s:OverlapsCompletionMenu( layout ) abort
  if !pumvisible()
    return v:false
  endif

  let position = pum_getpos()
  let height = get( position, 'height', 0 )
  let width = get( position, 'width', 0 )
  if height <= 0 || width <= 0
    return v:false
  endif

  return s:RectanglesOverlap(
        \ a:layout.top,
        \ a:layout.left,
        \ a:layout.outer_height,
        \ a:layout.outer_width,
        \ get( position, 'row', 0 ),
        \ get( position, 'col', 0 ),
        \ height,
        \ width )
endfunction


function! s:SetContents( buffer_number, presentation, syntax ) abort
  call setbufvar( a:buffer_number, '&modifiable', v:true )
  call nvim_buf_set_lines(
        \ a:buffer_number,
        \ 0,
        \ -1,
        \ v:true,
        \ a:presentation.lines )
  call setbufvar( a:buffer_number, '&modifiable', v:false )
  call nvim_set_option_value(
        \ 'syntax',
        \ a:syntax,
        \ { 'buf': a:buffer_number } )

  let namespace = s:Namespace()
  call nvim_buf_clear_namespace(
        \ a:buffer_number,
        \ namespace,
        \ 0,
        \ -1 )

  for range in a:presentation.active_parameter_ranges
    if range.line < 0 || range.line >= len( a:presentation.lines )
      continue
    endif

    let line_length = strlen( a:presentation.lines[ range.line ] )
    let start_column = max( [ 0, range.column ] )
    let end_column = min( [
          \ line_length,
          \ start_column + range.length,
          \ ] )
    if start_column >= end_column
      continue
    endif

    call nvim_buf_set_extmark(
          \ a:buffer_number,
          \ namespace,
          \ range.line,
          \ start_column,
          \ {
          \   'end_row': range.line,
          \   'end_col': end_column,
          \   'hl_group': 'YCMInverse',
          \   'hl_mode': 'combine',
          \   'priority': 50,
          \ } )
  endfor
endfunction


function! s:ConfigureWindow( window_id, presentation ) abort
  call nvim_set_option_value(
        \ 'winhighlight',
        \ 'NormalFloat:Normal,FloatBorder:Normal,CursorLine:CursorLine',
        \ { 'win': a:window_id } )
  call nvim_set_option_value(
        \ 'wrap',
        \ v:true,
        \ { 'win': a:window_id } )
  call nvim_set_option_value(
        \ 'cursorlineopt',
        \ 'line',
        \ { 'win': a:window_id } )
  call nvim_set_option_value(
        \ 'cursorline',
        \ v:true,
        \ { 'win': a:window_id } )

  let active_signature = max( [
        \ 0,
        \ min( [
        \   a:presentation.active_signature,
        \   len( a:presentation.lines ) - 1,
        \ ] ),
        \ ] )
  call nvim_win_set_cursor(
        \ a:window_id,
        \ [ active_signature + 1, 0 ] )
  call setwinvar(
        \ a:window_id,
        \ 'ycm_signature_help',
        \ v:true )
endfunction


function! youcompleteme#signature_help#ui#neovim#Render(
      \ window_id,
      \ presentation,
      \ anchor,
      \ hidden,
      \ syntax ) abort
  let source_window_id = win_getid()
  let layouts = s:Layouts(
        \ source_window_id,
        \ a:anchor,
        \ a:presentation.lines )
  let layout = {}
  for candidate in layouts
    if !s:OverlapsCursor( source_window_id, candidate )
          \ && !s:OverlapsCompletionMenu( candidate )
      let layout = candidate
      break
    endif
  endfor

  if empty( layout )
    call youcompleteme#signature_help#ui#neovim#Close(
          \ a:window_id )
    return 0
  endif

  let window_id = a:window_id
  if window_id > 0 && nvim_win_is_valid( window_id )
    let buffer_number = nvim_win_get_buf( window_id )
    call nvim_win_set_config( window_id, layout.config )
  else
    let buffer_number = nvim_create_buf( v:false, v:true )
    call setbufvar( buffer_number, '&bufhidden', 'wipe' )
    let window_id = nvim_open_win(
          \ buffer_number,
          \ v:false,
          \ layout.config )
  endif

  call s:SetContents(
        \ buffer_number,
        \ a:presentation,
        \ a:syntax )
  call s:ConfigureWindow(
        \ window_id,
        \ a:presentation )
  call nvim_win_set_config(
        \ window_id,
        \ { 'hide': a:hidden } )

  return window_id
endfunction


function! youcompleteme#signature_help#ui#neovim#Close(
      \ window_id ) abort
  if a:window_id > 0 && nvim_win_is_valid( a:window_id )
    call nvim_win_close( a:window_id, v:true )
  endif
endfunction


function! youcompleteme#signature_help#ui#neovim#Hide(
      \ window_id ) abort
  if a:window_id > 0 && nvim_win_is_valid( a:window_id )
    call nvim_win_set_config(
          \ a:window_id,
          \ { 'hide': v:true } )
  endif
endfunction


function! youcompleteme#signature_help#ui#neovim#Show(
      \ window_id ) abort
  if a:window_id > 0 && nvim_win_is_valid( a:window_id )
    call nvim_win_set_config(
          \ a:window_id,
          \ { 'hide': v:false } )
  endif
endfunction
