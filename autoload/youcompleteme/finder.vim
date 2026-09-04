" Copyright (C) 2021 YouCompleteMe contributors
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

" This is basic vim plugin boilerplate
let s:save_cpo = &cpoptions
set cpoptions&vim

scriptencoding utf-8

"
" Explanation for how this module works:
"
" The entry point is youcompleteme#finder#FindSymbol, which takes a scope
" argument:
"
" * 'document' scope - search document symbols - GoToDocumentOutline
" * 'workspace' scope - search workspace symbols - GoToSymbol
"
" In general, the approach is:
" - create a prompt buffer, and display it to use for input of a query
" - open up a popup to display the results in the middle of the screen
" - as the query changes, re-query the server to get the newly filtered results
" - as the server returns results, update the contents of the results-popup
" - use a popup-filter to implement some interractivity with the results, such
"   as down/up, and select item
" - when an item is selected, open its buffer in the window that was current
"   when the search started and jump to the selected item.
" - then populate the quickfix list with any matching results and close the
"   popup and prompt buffer.
"
" However, there is an important wrinke/distinction that leads to the code being
" a little more complicated than that: the 'search' mechanism for workspace and
" document symbols is different.
"
" The reaosn for this differece is what the servers provide in response to the 2
" requests:
"
" * 'document' scope - we use ycmd's filtering and sorting.
"    GoToDocumentOutline (LSP documentSymbol) request does not take any filter
"    argument. It returns all symbols in the current document. Therefore, we use
"    ycmd's filter_and_sort_candidates endpoint to use our own fuzzy search on
"    the results. This is a _great_ experience, it's _super_ fast and familar to
"    YCM users.
" * 'workspace' scope - we have to rely on the downstream server's filtering and
"   sorting.
"   GoToSymbol (LSP workspaceSymbol) request takes a query parameter to search
"   with. While the LSP spec states that an empty query means 'return
"   everything', no servers actually implement that, so we have to pass our
"   query down to the server.
"
" The result of this is that while a lot of the code is shared, there are
" slightly different steps involved in the process:
"
" * for 'document' requests, as soon as the popup is opened, we issue a
"   GoToDocumentOutline request, storing the results as `raw_results`, then
"   then immediately start filtering it with filter_and_sort_candidates, storing
"   the filtered results in `results`
" * for 'workspace' requests, as soon as the popup is opened, we issue a
"   GoToSymbol request with an empty query. This usually returns nothing, but if
"   any servers return anything then it would be stored in 'results'. As the
"   user types, we repeat the GoToSymbol request and update the 'results'
"
" In order to simplify the re-query code, we put the function used to filter
" results in the state variable as 'query_func'.
"
" As the expereince of completely different filtering and sorting for workspace
" vs document is so jarring, by default we actually pass all restuls from
" 'workspace' search through filter_and_sort_candidates too. This isn't perfect
" because it breaks the mental model when the server's filtering is dumb, but it
" at least means that sorting is consistent. This can be disabled by setting
" g:ycm_refilter_workspace_symbols to 0.
"
" The key functions are:
"
"  - FindSymbol - initiate the request - open the popup/prompt buffer, set up
"  the state object to defaults and initiate the first request
"  (RequestDocumentSymbols for 'documnt' and SearchWorkspace for 'workspace' )
"
"  - RequestDocumentSymbols - perform the GoToDocumentOutline request and store
"    the results in 'raw_results'
"
"  - SearchDocument - perform filter_and_sort_candidates request on the
"    'raw_results', and store the results in 'results', then call
"    "HandleSymbolSearchResults"
"
"  - SearchWorkspace - perform GoToSymbol request for all open filetypes,
"     and store the results in 'raw_results' as a dict mapping
"     filetype->results. Merge the results in to 'results', then call
"     "HandleSymbolSearchResults"
"
"  - HandleSymbolSearchResults - redraw the popup with the 'results'
"
"  - HandleKeyPress - handle a keypress while the popup is visible, intercepts
"    things to handle interractivity
"
"  - PopupClosed - callback when the popup is closed. This openes the result in
"    the original window.
"
" The other functions are utility for the most part and handle things like
" TextChangedI event, starting/stopping drawing the spinner and such.

let s:icon_spinner = [ '/', '-', '\', '|', '/', '-', '\', '|' ]
let s:icon_done = 'X'
let s:spinner_delay = 100
let s:prompt = 'Find Symbol: '
let s:find_symbol_status = {}

" Entry point {{{

function! youcompleteme#finder#FindSymbol( scope ) abort
  if !youcompleteme#finder#ui#Supported()
    echo 'Sorry, this feature is not supported in your editor'
    return
  endif

  let s:find_symbol_status = {
        \ 'selected': -1,
        \ 'query': '',
        \ 'results': [],
        \ 'raw_results': v:null,
        \ 'all_filetypes': v:true,
        \ 'pending': [],
        \ 'winid': win_getid(),
        \ 'bufnr': bufnr(),
        \ 'prompt_bufnr': -1,
        \ 'prompt_winid': -1,
        \ 'filter': v:null,
        \ 'id': v:null,
        \ 'cursorline_match': v:null,
        \ 'spinner': 0,
        \ 'spinner_timer': -1,
        \ }

  if a:scope ==# 'document'
    let s:find_symbol_status.query_func = function( 's:SearchDocument' )
  else
    let s:find_symbol_status.query_func = function( 's:SearchWorkspace' )
  endif

  let s:find_symbol_status.id = youcompleteme#finder#ui#Create(
        \ 'Type to query for stuff',
        \ function( 's:PopupClosed' ) )

  " Kick off the request now
  if a:scope ==# 'document'
    call s:RequestDocumentSymbols()
  else
    call s:SearchWorkspace( '', v:true )
  endif

  let bufnr = bufadd( '_ycm_filter_' )
  silent call bufload( bufnr )
  silent topleft 1split _ycm_filter_
  " Disable ycm/completion in this buffer
  call setbufvar( bufnr, 'ycm_largefile', 1 )

  let s:find_symbol_status.prompt_bufnr = bufnr
  let s:find_symbol_status.prompt_winid = win_getid()

  setlocal buftype=prompt noswapfile modifiable nomodified noreadonly
  setlocal nobuflisted bufhidden=delete textwidth=0
  call prompt_setprompt( bufnr(), s:prompt )
  call youcompleteme#finder#ui#BindKeys(
        \ s:find_symbol_status.id,
        \ s:find_symbol_status.prompt_bufnr,
        \ function( 's:HandleKeyPress' ) )

  augroup YCMPromptFindSymbol
    autocmd!
    autocmd TextChanged,TextChangedI <buffer> call s:OnQueryTextChanged()
    autocmd WinLeave <buffer> ++nested
          \ call s:Cancel()
    autocmd CmdLineEnter <buffer> ++nested
          \ call s:Cancel()
  augroup END
  startinsert
endfunction

function! s:OnQueryTextChanged() abort
  if s:find_symbol_status.id < 0
    return
  endif

  let bufnr = s:find_symbol_status.prompt_bufnr
  let query = getbufline( bufnr, '$' )[ 0 ]
  let s:find_symbol_status.query = query[ len( s:prompt ) : ]

  " really, re-query if we can
  call s:RequeryFinderPopup( v:true )

  call win_execute( s:find_symbol_status.prompt_winid, 'setlocal nomodified' )
endfunction


function! s:Cancel() abort
  if s:find_symbol_status.id < 0
    return
  endif

  call youcompleteme#finder#ui#Close(
        \ s:find_symbol_status.id,
        \ -1 )
endfunction
" }}}

" Popup and keyboard events {{{

function! s:HandleKeyPress( id, key ) abort
  let redraw = 0
  let handled = 0
  let requery = 0

  " The input for the search/query is taken from the prompt buffer and the
  " TextChangedI event
  if a:key ==# "\<C-j>" ||
        \ a:key ==# "\<Down>" ||
        \ a:key ==# "\<C-n>" ||
        \ a:key ==# "\<Tab>"
    let s:find_symbol_status.selected += 1
    " wrap
    if s:find_symbol_status.selected >= len( s:find_symbol_status.results )
      let s:find_symbol_status.selected = 0
    endif
    let redraw = 1
    let handled = 1
  elseif a:key ==# "\<C-k>" ||
        \ a:key ==# "\<Up>" ||
        \ a:key ==# "\<C-p>" ||
        \ a:key ==# "\<S-Tab>"
    let s:find_symbol_status.selected -= 1
    " wrap
    if s:find_symbol_status.selected < 0
      let s:find_symbol_status.selected =
            \ len( s:find_symbol_status.results ) - 1
    endif
    let redraw = 1
    let handled = 1
  elseif a:key ==# "\<PageDown>" || a:key ==# "\<kPageDown>"
    let s:find_symbol_status.selected +=
          \ youcompleteme#finder#ui#GetHeight(
          \   s:find_symbol_status.id )
    " Don't wrap
    if s:find_symbol_status.selected >= len( s:find_symbol_status.results )
      let s:find_symbol_status.selected =
            \ len( s:find_symbol_status.results ) - 1
    endif
    let redraw = 1
    let handled = 1
  elseif a:key ==# "\<PageUp>" || a:key ==# "\<kPageUp>"
    let s:find_symbol_status.selected -=
          \ youcompleteme#finder#ui#GetHeight(
          \   s:find_symbol_status.id )
    " Don't wrap
    if s:find_symbol_status.selected < 0
      let s:find_symbol_status.selected = 0
    endif
    let redraw = 1
    let handled = 1
  elseif a:key ==# "\<C-c>"
    call youcompleteme#finder#ui#Close(
          \ a:id,
          \ -1 )
    let handled = 1
  elseif a:key ==# "\<CR>"
    if s:find_symbol_status.selected >= 0
      call youcompleteme#finder#ui#Close(
            \ a:id,
            \ s:find_symbol_status.selected )
      let handled = 1
    endif
  elseif a:key ==# "\<Home>" || a:key ==# "\<kHome>"
    let s:find_symbol_status.selected = 0
    let redraw = 1
    let handled = 1
  elseif a:key ==# "\<End>" || a:key ==# "\<kEnd>"
    let s:find_symbol_status.selected = len( s:find_symbol_status.results ) - 1
    let redraw = 1
    let handled = 1
  elseif a:key ==# "\<C-f>"
    " TOggle filetypes?
    let s:find_symbol_status.all_filetypes = !s:find_symbol_status.all_filetypes
    let redraw = 0
    let requery = 1
    let handled = 1
  endif

  if requery
    call s:RequeryFinderPopup( v:true )
  elseif redraw
    call s:RedrawFinderPopup()
  endif

  return handled
endfunction


function! s:JumpToSelection( selected, timer_id ) abort
  py3 vimsupport.JumpToLocation(
        \ filename = vimsupport.ToUnicode(
        \   vim.eval( 'a:selected.filepath' ) ),
        \ line = int( vim.eval( 'a:selected.line_num' ) ),
        \ column = int( vim.eval( 'a:selected.column_num' ) ),
        \ modifiers = '',
        \ command = 'same-buffer'
        \ )
endfunction


" Handle the popup closing: jump to the selected item
function! s:PopupClosed( id, selected ) abort
  stopinsert

  let prompt_buffer = s:find_symbol_status.prompt_bufnr
  if bufexists( prompt_buffer )
    execute 'silent bwipe! ' . prompt_buffer
  endif

  " Return to original window
  call win_gotoid( s:find_symbol_status.winid )

  if a:selected >= 0
    let selected = s:find_symbol_status.results[ a:selected ]

    " Vim finishes leaving Insert mode after this popup callback returns.
    " Defer the jump so that process does not move its cursor one character
    " to the left.
    call timer_start(
          \ 0,
          \ function( 's:JumpToSelection', [ selected ] ) )

    if len( s:find_symbol_status.results ) > 1
      " Also, populate the quickfix list
      py3 vimsupport.SetQuickFixList(
            \ [ vimsupport.BuildQfListItem( x ) for x in
            \ vim.eval( 's:find_symbol_status.results' ) ] )


      " Emulate :echo, to avoid a redraw getting rid of the message.
      let txt = 'Added ' . len( getqflist() ) . ' entries to quickfix list.'
      call youcompleteme#finder#ui#Notify( txt )

      " But don't open it, as this could take up valuable actual screen space
      " py3 vimsupport.OpenQuickFixList()
    endif
  endif


  call s:EndRequest()
  let s:find_symbol_status.id = -1
endfunction

"}}}

" Results handling and re-query {{{

" Render a set of results returned from the filter/search function
function! s:HandleSymbolSearchResults( results ) abort
  let s:find_symbol_status.results = []

  if s:find_symbol_status.id < 0
    " Popup was closed, ignore this event
    return
  endif

  let s:find_symbol_status.results = a:results
  call s:RedrawFinderPopup()

  " Re-query but no change in the query text
  call s:RequeryFinderPopup( v:false )
endfunction


" Set the popup text
function! s:RedrawFinderPopup() abort
  " Clamp selected. If there are any results, the first one is selected by
  " default
  let s:find_symbol_status.selected = max( [
        \   s:find_symbol_status.selected,
        \   len( s:find_symbol_status.results ) > 0 ? 0 : -1
        \ ] )
  let s:find_symbol_status.selected = min( [
        \   s:find_symbol_status.selected,
        \   len( s:find_symbol_status.results ) - 1
        \ ] )

  if empty( s:find_symbol_status.results )
    call youcompleteme#finder#ui#SetContents(
          \ s:find_symbol_status.id,
          \ 'No results' )
    let s:find_symbol_status.selected = -1
  else
    let popup_width = youcompleteme#finder#ui#GetWidth(
          \ s:find_symbol_status.id )

    let buffer = []

    let len_filetype = 0

    for result in s:find_symbol_status.results
      let len_filetype = max( [ len_filetype, len( result[ 'filetype' ] ) ] )
    endfor

    if len_filetype > 0
      let filetype_sep = ' '
    else
      let filetype_sep = ''
    endif

    let available_width = popup_width - len_filetype - len( filetype_sep )

    for result in s:find_symbol_status.results
      " Calculate  the text to use. Try and include the full path and line
      " number, (right aligned), but truncate if there isn't space for the
      " description and the file path. Include at least 8 spaces between them
      " (if there's room).
      if result->has_key( 'extra_data' )
        let kind = result[ 'extra_data' ][ 'kind' ]
        let name = result[ 'extra_data' ][ 'name' ]
        let desc = kind .. ': ' .. name
        let highlight_group =
              \ youcompleteme#symbol#GetPropForSymbolKind( kind )
        let highlights = [
            \ { 'column': 1,
            \   'length': len( kind ) + 2,
            \   'group': 'YCM-symbol-Normal' },
            \ { 'column': len( kind ) + 3,
            \   'length': len( name ),
            \   'group': highlight_group },
            \ ]
      elseif result->has_key( 'description' )
        let desc = result[ 'description' ]
        let highlights = [
            \ {
            \   'column': 1,
            \   'length': len( desc ),
            \   'group': 'YCM-symbol-Normal',
            \ },
            \ ]
      else
        let desc = 'Invalid entry: ' . string( result )
        let highlights = []
      endif

      let line_num = result[ 'line_num' ]
      let path = fnamemodify( result[ 'filepath' ], ':.' )
               \ .. ':'
               \ .. line_num
      let path_includes_line = 1

      let spaces = available_width - strdisplaywidth( desc ) - strdisplaywidth( path )
      let spacing = 4
      if spaces < spacing
        let spaces = spacing
        let space_for_path = available_width - spacing - len( desc )
        let path_includes_line = space_for_path - 3 > len( line_num ) + 1
        if space_for_path > 3
          let path = '...' . strpart( path, len( path ) - space_for_path + 3 )
        elseif space_for_path <= 0
          let path = ''
        else
          let path_includes_line = 0
          let path = '...'
        endif
      endif

      let line = desc
             \ .. repeat( ' ', spaces )
             \ .. path
             \ .. filetype_sep
             \ .. result[ 'filetype' ]

      if len( path ) > 0
        if path_includes_line
          let highlights += [
                \ { 'column': len( desc ) + spaces + 1,
                \   'length': len( path ) - len( line_num ),
                \   'group': 'YCM-symbol-file' },
                \ {
                \   'column':
                \     len( desc ) + spaces + 1 + len( path ) - len( line_num ),
                \   'length': len( line_num ),
                \   'group': 'YCM-symbol-line-num',
                \ },
                \ ]
        else
          let highlights += [
                \ { 'column': len( desc ) + spaces + 1,
                \   'length': len( path ),
                \   'group': 'YCM-symbol-file' },
                \ ]
        endif
      endif

      if len_filetype > 0
        let highlights += [
            \ {
            \   'column': popup_width - len_filetype + len( filetype_sep ),
            \   'length': len_filetype,
            \   'group': 'YCM-symbol-filetype',
            \ },
            \ ]
      endif

      call add(
            \ buffer,
            \ { 'text': line, 'highlights': highlights } )
    endfor

    call youcompleteme#finder#ui#SetContents(
          \ s:find_symbol_status.id,
          \ buffer )
  endif

  call youcompleteme#finder#ui#SetSelected(
        \ s:find_symbol_status.id,
        \ s:find_symbol_status.selected )
endfunction

function! s:SetTitle() abort
  if s:find_symbol_status.spinner_timer > -1
    let status = s:icon_spinner[ s:find_symbol_status.spinner ]
  else
    let status = s:icon_done
  endif

  call youcompleteme#finder#ui#SetTitle(
        \ s:find_symbol_status.id,
        \ ' [' . status . '] Search for symbol: '
        \   . s:find_symbol_status.query . ' ' )
endfunction



" Re-query or re-filter by calling the filter function
function! s:RequeryFinderPopup( new_query ) abort
  " Update the title even if we delay the query, as this makes the UI feel
  " snappy
  call s:SetTitle()

  call win_execute( s:find_symbol_status.winid,
        \ 'call s:find_symbol_status.query_func('
        \ . 's:find_symbol_status.query,'
        \ . 'a:new_query )' )
endfunction

function! s:ParseGoToResponse( filetype, results ) abort
  if type( a:results ) == type( v:null ) || empty( a:results )
    let results = []
  elseif type( a:results ) != v:t_list
    if type( a:results ) == v:t_dict && has_key( a:results, 'error' )
      let results = []
    else
      let results = [ a:results ]
    endif
  else
    let results = a:results
  endif

  call map( results, { _, r -> extend( r, {
      \   'key': r->get( 'extra_data', {} )->get( 'name', r[ 'description' ] ),
      \   'filetype': a:filetype
      \ } ) } )
  return results
endfunction

" }}}

" Spinner {{{

function! s:StartRequest() abort
  call s:EndRequest()

  let s:find_symbol_status.spinner = 0
  let s:find_symbol_status.spinner_timer = timer_start( s:spinner_delay,
        \ function( 's:TickSpinner' ) )

  call s:SetTitle()
endfunction

function! s:EndRequest() abort
  call timer_stop( s:find_symbol_status.spinner_timer )

  let s:find_symbol_status.spinner_timer = -1

  call s:SetTitle()
endfunction

function! s:TickSpinner( timer_id ) abort
  let s:find_symbol_status.spinner = ( s:find_symbol_status.spinner + 1 ) %
        \ len( s:icon_spinner )

  let s:find_symbol_status.spinner_timer = timer_start( s:spinner_delay,
        \ function( 's:TickSpinner' ) )

  call s:SetTitle()
endfunction

" }}}

" Workspace search {{{

function! s:SearchWorkspace( query, new_query ) abort

  if a:new_query
    if s:find_symbol_status.raw_results is# v:null
      let raw_results = {}
    else
      let raw_results = copy( s:find_symbol_status.raw_results )
    endif

    let s:find_symbol_status.raw_results = {}
    " FIXME: We might still get results for any pending results. There is no
    " cancellation mechanism implemented for the async request!
    let s:find_symbol_status.pending = []

    if s:find_symbol_status.all_filetypes
      let ft_buffer_map = py3eval( 'vimsupport.AllOpenedFiletypes()' )
    else
      let current_filetypes = py3eval( 'vimsupport.CurrentFiletypes()' )
      let ft_buffer_map = {}
      for ft in current_filetypes
        let ft_buffer_map[ ft ] = [ bufnr() ]
      endfor
    endif

    for ft in keys( ft_buffer_map )
      if !youcompleteme#filetypes#AllowedForFiletype( ft )
        continue
      endif

      let s:find_symbol_status.raw_results[ ft ] = v:null
      if has_key( raw_results, ft ) && raw_results[ ft ] is# v:null
        call add( s:find_symbol_status.pending,
                \ [ ft, ft_buffer_map[ ft ][ 0 ] ] )
      else
        call youcompleteme#GetRawCommandResponseAsync(
              \ function( 's:HandleWorkspaceSymbols', [ ft ] ),
              \ 'GoToSymbol',
              \ '--bufnr=' . ft_buffer_map[ ft ][ 0 ],
              \ 'ft=' . ft,
              \ a:query )
      endif
    endfor

    if !empty( s:find_symbol_status.raw_results )
      " We sent some requests
      call s:StartRequest()
    endif
  else
    " Just requery those completer filetypes that we're not currently waiting
    " for
    for [ ft, bufnr ] in copy( s:find_symbol_status.pending )
      if s:find_symbol_status.raw_results[ ft ] isnot# v:null
        call filter(
              \ s:find_symbol_status.pending,
              \ { _, request -> request[ 0 ] !=# ft } )
        let s:find_symbol_status.raw_results[ ft ] = v:null
        call youcompleteme#GetRawCommandResponseAsync(
              \ function( 's:HandleWorkspaceSymbols', [ ft ] ),
              \ 'GoToSymbol',
              \ '--bufnr=' . bufnr,
              \ 'ft=' . ft,
              \ a:query )
      endif
    endfor
  endif
endfunction


function! s:HandleWorkspaceSymbols( filetype, results ) abort

  let s:find_symbol_status.raw_results[ a:filetype ] =
        \ s:ParseGoToResponse( a:filetype, a:results )

  " Collate the results from each filetype
  let results = []
  let waiting = 0
  for ft in keys( s:find_symbol_status.raw_results )
    if s:find_symbol_status.raw_results[ ft ] is v:null
      let waiting = 1
      continue
    endif

    call extend( results, s:find_symbol_status.raw_results[ ft ] )
  endfor

  let query = s:find_symbol_status.query

  if g:ycm_refilter_workspace_symbols && !empty( results )
    " This is kinda wonky, but seems to work well enough.
    "
    " We get the server to give us a result set, then use our own
    " filter_and_sort_candidates on the result set filtered by the server
    "
    " The reason for this is:
    "  - server filterins will differ by server and this leads to horrible wonky
    "    user experience
    "  - ycmd filter is consistent, even if not perfect
    "  - servers are supposed to return _all_ symbols if we request a query of
    "    "" but not all servers actually do
    "
    " So as a compromise we let the server filter the results, then we
    " _refilter_ and sort them using ycmd's method. This provides consistency
    " with the filtering and sorting on the completion popup menu, with the
    " disadvantage of additional latency.
    "
    " We're not currently sure this is going to be perfecct, so we have a hidden
    " option to disable this re-filter/sort.
    "
    let results = py3eval(
          \ 'ycm_state.FilterAndSortItems( vim.eval( "results" ),'
          \ .                              ' "key",'
          \ .                              ' vim.eval( "query" ) )' )
  endif

  if !waiting
    call s:EndRequest()
  endif
  eval s:HandleSymbolSearchResults( results )
endfunction

" }}}

" Document Search {{{

function! s:SearchDocument( query, new_query ) abort
  if !a:new_query
    return
  endif

  if type( s:find_symbol_status.raw_results ) == type( v:null )
    call youcompleteme#finder#ui#SetContents(
          \ s:find_symbol_status.id,
          \ 'No symbols found in document' )
    return
  endif

  " No spinner, because this is actually a synchronous call

  " Call filter_and_sort_candidates on the results (synchronously)
  let response = py3eval(
        \ 'ycm_state.FilterAndSortItems( '
        \ . ' vim.eval( "s:find_symbol_status.raw_results" ),'
        \ . ' "key",'
        \ . ' vim.eval( "a:query" ) )' )

  eval s:HandleSymbolSearchResults( response )
endfunction


function! s:RequestDocumentSymbols()
  call s:StartRequest()
  call youcompleteme#GetRawCommandResponseAsync(
        \ function( 's:HandleDocumentSymbols' ),
        \ 'GoToDocumentOutline' )
endfunction


function! s:HandleDocumentSymbols( results ) abort
  call s:EndRequest()
  let s:find_symbol_status.raw_results = s:ParseGoToResponse( '', a:results )
  call s:SearchDocument( '', v:true )
endfunction

" }}}

" Utility for testing {{{

function! youcompleteme#finder#GetState() abort
  return s:find_symbol_status
endfunction

" }}}

" This is basic vim plugin boilerplate
let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
