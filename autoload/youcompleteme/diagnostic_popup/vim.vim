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


function! youcompleteme#diagnostic_popup#vim#Supported() abort
  return exists( '*popup_create' )
        \ && exists( '*popup_atcursor' )
        \ && exists( '*popup_move' )
        \ && exists( '*popup_hide' )
        \ && exists( '*popup_settext' )
        \ && exists( '*popup_show' )
        \ && exists( '*popup_close' )
endfunction


function! s:GetDiagnosticProperty(
      \ buffer_number,
      \ line_number,
      \ diagnostic ) abort
  let diagnostic_range = a:diagnostic.location_extent
  let range_start = diagnostic_range.start
  let range_end = diagnostic_range.end

  if range_start.line_num == range_end.line_num
    let column = range_start.column_num
    let length = range_end.column_num - range_start.column_num
  elseif range_start.line_num == a:line_number
    let buffer_lines = getbufline( a:buffer_number, a:line_number )
    if empty( buffer_lines )
      return {}
    endif
    let column = range_start.column_num
    let length = strchars( buffer_lines[ 0 ] ) - column + 2
  elseif range_end.line_num == a:line_number
    let column = 1
    let length = range_end.column_num - 1
  else
    let buffer_lines = getbufline( a:buffer_number, a:line_number )
    if empty( buffer_lines )
      return {}
    endif
    let column = 1
    let length = strchars( buffer_lines[ 0 ] ) + 1
  endif

  let property_type = a:diagnostic.kind ==# 'ERROR'
        \ ? 'YcmErrorProperty'
        \ : 'YcmWarningProperty'
  let properties = prop_list( a:line_number, {
        \ 'bufnr': a:buffer_number,
        \ 'types': [ property_type ],
        \ } )

  for property in properties
    if property.col == column && property.length == length
      return property
    endif
  endfor

  return {}
endfunction


function! youcompleteme#diagnostic_popup#vim#Show(
      \ lines,
      \ buffer_number,
      \ cursor_position,
      \ diagnostic ) abort
  let column = a:cursor_position[ 1 ]
  if column > &columns - 2
    let column = 0
  endif

  let options = {
        \ 'col': column,
        \ 'padding': [ 0, 1, 0, 1 ],
        \ 'maxwidth': &columns,
        \ 'close': 'click',
        \ 'fixed': 0,
        \ 'highlight': 'YcmErrorPopup',
        \ 'border': [ 1, 1, 1, 1 ],
        \ 'moved': 'expr',
        \ }

  if !empty( a:diagnostic )
    let property = s:GetDiagnosticProperty(
          \ a:buffer_number,
          \ a:cursor_position[ 0 ],
          \ a:diagnostic )
    if !empty( property )
      let options.textpropid = property.id
      let options.textprop = property.type
      call remove( options, 'col' )
      return popup_create( a:lines, options )
    endif
  endif

  return popup_atcursor( a:lines, options )
endfunction
