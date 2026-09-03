" Copyright (C) 2024 YouCompleteMe contributors
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


let s:highlight_group_for_symbol_kind = {
      \ 'Array': 'Identifier',
      \ 'Boolean': 'Boolean',
      \ 'Class': 'Structure',
      \ 'Constant': 'Constant',
      \ 'Constructor': 'Function',
      \ 'Enum': 'Structure',
      \ 'EnumMember': 'Identifier',
      \ 'Event': 'Identifier',
      \ 'Field': 'Identifier',
      \ 'Function': 'Function',
      \ 'Interface': 'Structure',
      \ 'Key': 'Identifier',
      \ 'Method': 'Function',
      \ 'Module': 'Include',
      \ 'Namespace': 'Type',
      \ 'Null': 'Keyword',
      \ 'Number': 'Number',
      \ 'Object': 'Structure',
      \ 'Operator': 'Operator',
      \ 'Package': 'Include',
      \ 'Property': 'Identifier',
      \ 'String': 'String',
      \ 'Struct': 'Structure',
      \ 'TypeParameter': 'Typedef',
      \ 'Variable': 'Identifier',
      \ }
let s:highlight_group_for_property_type = {
      \ 'YCM-symbol-Normal': 'Normal',
      \ 'YCM-symbol-file': 'Comment',
      \ 'YCM-symbol-filetype': 'Special',
      \ 'YCM-symbol-line-num': 'Number',
      \ }

for [ s:kind, s:highlight_group ] in
      \ items( s:highlight_group_for_symbol_kind )
  let s:highlight_group_for_property_type[
        \ 'YCM-symbol-' . s:kind ] = s:highlight_group
endfor
unlet s:kind
unlet s:highlight_group

let s:initialized_text_properties = v:false


function! youcompleteme#symbol#GetHighlightGroups() abort
  return copy( s:highlight_group_for_property_type )
endfunction


function! youcompleteme#symbol#InitSymbolProperties() abort
  if !s:initialized_text_properties
    for [ property_type, highlight_group ] in
          \ items( s:highlight_group_for_property_type )
      call prop_type_add(
            \ property_type,
            \ { 'highlight': highlight_group } )
    endfor
    let s:initialized_text_properties = v:true
  endif
endfunction

function! youcompleteme#symbol#GetPropForSymbolKind( kind ) abort
  if s:highlight_group_for_symbol_kind->has_key( a:kind )
    return 'YCM-symbol-' . a:kind
  endif

  return 'YCM-symbol-Normal'
endfunction

