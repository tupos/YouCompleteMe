" This file provides the Vim adapter for the shared diagnostics integration
" tests. The actual tests and common setup are in test/shared/diagnostics.vim.

function! YcmTest_DetailedDiagnosticWindow() abort
  redraw
  let popups = popup_list()
  call assert_equal( 1, len( popups ) )
  return get( popups, 0, 0 )
endfunction


function! YcmTest_CheckDetailedDiagnosticWindow( window_id ) abort
  call assert_notequal(
        \ 0,
        \ a:window_id,
        \ "Couldn't find popup! " .. youcompleteme#test#popup#DumpPopups() )
  if a:window_id == 0
    return
  endif

  call assert_true( get( popup_getpos( a:window_id ), 'visible', 0 ) )

  let popup_options = popup_getoptions( a:window_id )
  let text_property_id = get( popup_options, 'textpropid', 0 )
  let text_property_type = get( popup_options, 'textprop', '' )
  call assert_notequal( 0, text_property_id )
  call assert_notequal( '', text_property_type )
  if text_property_id == 0 || empty( text_property_type )
    return
  endif

  let matching_properties = prop_list( line( '.' ), {
        \ 'bufnr': bufnr( '%' ),
        \ 'ids': [ text_property_id ],
        \ 'types': [ text_property_type ],
        \ } )
  call assert_equal(
        \ 1,
        \ len( matching_properties ),
        \ 'Popup text property does not cover the current line' )
endfunction


function! YcmTest_DetailedDiagnosticWindowExists( window_id ) abort
  return !empty( popup_getpos( a:window_id ) )
endfunction


function! YcmTest_CloseDetailedDiagnosticWindow( window_id ) abort
  call popup_close( a:window_id )
endfunction


function! YcmTest_SetCharAvailOverride( enabled ) abort
  if a:enabled
    call test_override( 'char_avail', 1 )
    return
  endif

  call test_override( 'ALL', 0 )
endfunction


function! YcmTest_VirtualDiagnosticProperties() abort
  return prop_list( 1, {
        \ 'end_lnum': -1,
        \ 'types': [
        \   'YcmVirtDiagWarning',
        \   'YcmVirtDiagError',
        \   'YcmVirtDiagPadding',
        \ ],
        \ } )
endfunction


function! YcmTest_DiagnosticHighlights( line_number ) abort
  let highlights = []
  for property in prop_list( a:line_number )
    call add( highlights, {
          \ 'column': property.col,
          \ 'length': property.length,
          \ 'type': property.type,
          \ } )
  endfor
  return highlights
endfunction


function! Test_ThirdPartyDeletesItsTextProperty()
  enew
  call prop_type_add( 'ThirdPartyProperty', { 'highlight': 'Error' } )
  call prop_add(
        \ 1,
        \ 1,
        \ {
        \   'type': 'ThirdPartyProperty',
        \   'bufnr': bufnr( '%' ),
        \   'id': 42,
        \ } )
  call prop_type_delete( 'ThirdPartyProperty' )

  py3 from ycm.vimsupport import GetTextProperties, GetIntValue
  call assert_equal(
        \ [],
        \ py3eval(
        \   'GetTextProperties( GetIntValue( """bufnr( "%" )""" ) )' ) )
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/diagnostics.vim' )
