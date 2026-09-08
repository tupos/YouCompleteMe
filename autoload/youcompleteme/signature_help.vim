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
" This module owns editor-independent signature-help state and presentation.

let s:STATE_ACTIVE = 'ACTIVE'
let s:STATE_INACTIVE = 'INACTIVE'
let s:STATE_ACTIVE_SUPPRESSED = 'ACTIVE_SUPPRESSED'

let s:state = s:STATE_INACTIVE
let s:anchor = []
let s:window_id = 0


function! youcompleteme#signature_help#Supported() abort
  return youcompleteme#signature_help#ui#Supported()
endfunction


function! s:MakePresentation( signature_info ) abort
  let presentation = {
        \ 'lines': [],
        \ 'active_parameter_ranges': [],
        \ 'active_signature': get(
        \   a:signature_info,
        \   'activeSignature',
        \   0 ),
        \ }
  let active_parameter = get(
        \ a:signature_info,
        \ 'activeParameter',
        \ 0 )
  let signature_index = 0

  for signature in get( a:signature_info, 'signatures', [] )
    call add(
          \ presentation.lines,
          \ get( signature, 'label', '' ) )

    let parameters = get( signature, 'parameters', [] )
    if active_parameter >= 0 && active_parameter < len( parameters )
      let parameter_label = get(
            \ parameters[ active_parameter ],
            \ 'label',
            \ [] )
      if type( parameter_label ) == v:t_list &&
            \ len( parameter_label ) >= 2
        let begin = parameter_label[ 0 ]
        let end = parameter_label[ 1 ]
        call add( presentation.active_parameter_ranges, {
              \ 'line': signature_index,
              \ 'column': begin,
              \ 'length': end - begin,
              \ } )
      endif
    endif

    let signature_index += 1
  endfor

  return presentation
endfunction


function! s:ResetState() abort
  let s:state = s:STATE_INACTIVE
  let s:anchor = []
  let s:window_id = 0
endfunction


function! youcompleteme#signature_help#Update( signature_info ) abort
  if !youcompleteme#signature_help#Supported()
    return
  endif

  let presentation = s:MakePresentation( a:signature_info )
  if empty( presentation.lines )
    call youcompleteme#signature_help#Clear()
    return
  endif

  if s:state ==# s:STATE_INACTIVE
    let s:anchor = [ line( '.' ) - 1, col( '.' ) - 1 ]
    let s:state = s:STATE_ACTIVE
  endif

  let syntax = get( g:, 'ycm_signature_help_disable_syntax', v:false )
        \ ? ''
        \ : &syntax
  let s:window_id = youcompleteme#signature_help#ui#Render(
        \ s:window_id,
        \ presentation,
        \ s:anchor,
        \ s:state ==# s:STATE_ACTIVE_SUPPRESSED,
        \ syntax )

  if s:window_id <= 0
    call s:ResetState()
  endif
endfunction


function! youcompleteme#signature_help#Clear() abort
  call youcompleteme#signature_help#ui#Close( s:window_id )
  call s:ResetState()
endfunction


function! youcompleteme#signature_help#ToggleVisibility() abort
  if s:state ==# s:STATE_ACTIVE
    call youcompleteme#signature_help#ui#Hide( s:window_id )
    let s:state = s:STATE_ACTIVE_SUPPRESSED
  elseif s:state ==# s:STATE_ACTIVE_SUPPRESSED
    call youcompleteme#signature_help#ui#Show( s:window_id )
    let s:state = s:STATE_ACTIVE
  endif
endfunction


function! youcompleteme#signature_help#StateForRequest() abort
  if s:state ==# s:STATE_INACTIVE
    return s:STATE_INACTIVE
  endif
  return s:STATE_ACTIVE
endfunction


function! youcompleteme#signature_help#WindowID() abort
  return s:window_id
endfunction


function! youcompleteme#signature_help#Anchor() abort
  return copy( s:anchor )
endfunction


function! youcompleteme#signature_help#State() abort
  return s:state
endfunction
