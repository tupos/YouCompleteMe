" This file provides the Vim-specific adapter for the shared signature-help
" integration tests. The actual tests are in
" test/shared/signature_help.vim.


function! YcmTest_SignatureHelpWindowVisible( window_id ) abort
  if a:window_id <= 0
    return v:false
  endif

  return get(
        \ popup_getpos( a:window_id ),
        \ 'visible',
        \ v:false )
endfunction


function! YcmTest_SignatureHelpSelectedLine( window_id ) abort
  return getcurpos( a:window_id )[ 1 ]
endfunction


function! YcmTest_SignatureHelpHighlights( window_id ) abort
  let highlights = []
  let buffer_number = winbufnr( a:window_id )

  for line_number in range(
        \ 1,
        \ len( getbufline( buffer_number, 1, '$' ) ) )
    for property in prop_list(
          \ line_number,
          \ { 'bufnr': buffer_number } )
      if property.type !=# 'YCM-signature-help-current-argument'
        continue
      endif

      call add( highlights, {
            \ 'line': line_number - 1,
            \ 'column': property.col - 1,
            \ 'length': property.length,
            \ 'group': prop_type_get( property.type ).highlight,
            \ } )
    endfor
  endfor

  return highlights
endfunction


function! YcmTest_SetCharAvailOverride( enabled ) abort
  if a:enabled
    call test_override( 'char_avail', 1 )
    return
  endif

  call test_override( 'ALL', 0 )
endfunction


function! YcmTest_SignatureHelpEmptyBufferHasKnownBug() abort
  " Vim may temporarily expose a popup buffer with an empty 'buftype', causing
  " YCM to parse it when ycm_nofiletype is explicitly enabled.
  return v:true
endfunction


function! YcmTest_SignatureHelpIsBelowAnchor( window_id ) abort
  let source_position = screenpos(
        \ win_getid(),
        \ line( '.' ),
        \ col( '.' ) )
  return popup_getpos( a:window_id ).line > source_position.row
endfunction


function! YcmTest_SignatureHelpScreenRectangle( window_id ) abort
  let position = popup_getpos( a:window_id )
  return [
        \ position.line - 1,
        \ position.col - 1,
        \ position.height,
        \ position.width,
        \ ]
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h' ) . '/completion_info.vim' )
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/signature_help.vim' )


function! s:_ClearSigHelp()
  call youcompleteme#signature_help#Clear()
  call assert_equal(
        \ 0,
        \ youcompleteme#signature_help#WindowID(),
        \ 'window ID after clearing empty signature help' )
endfunction


function! s:_CheckSigHelpAtPos( sh, cursor, pos )
  call setpos( '.', [ 0 ] + a:cursor )
  redraw
  call youcompleteme#signature_help#Update( a:sh )
  redraw
  let winid = youcompleteme#signature_help#WindowID()
  call youcompleteme#test#popup#CheckPopupPosition( winid, a:pos )
endfunction

function! SetUp()
  let g:ycm_use_clangd = 1
  let g:ycm_confirm_extra_conf = 0
  let g:ycm_auto_trigger = 1
  let g:ycm_keep_logfiles = 1
  let g:ycm_log_level = 'DEBUG'

  call youcompleteme#test#setup#SetUp()
endfunction

function! TearDown()
  call s:_ClearSigHelp()
  call youcompleteme#test#setup#CleanUp()
endfunction

" This is how we might do screen dump tests
" function! Test_Compl()
"   let setup =<< trim END
"     edit ../third_party/ycmd/ycmd/tests/clangd/testdata/general_fallback/make_drink.cc
"     call setpos( '.', [ 0, 7, 27 ] )
"   END
"   call writefile( setup, 'Xtest_Compl' )
"   let vim = RunVimInTerminal( '-Nu vimrc -S Xtest_Compl', {} )
"
"   function! Test() closure
"     " Wait for Vim to be ready
"     call term_sendkeys( vim, "cl:" )
"     call term_wait( vim )
"     call VerifyScreenDump( vim, "signature_help_Test_Compl_01", {} )
"   endfunction
"
"   call WaitForAssert( {-> Test()} )
"
"   " clean up
"   call StopVimInTerminal(vim)
"   call delete('XtestPopup')
" endfunction

function! Test_Placement_Simple()
  call assert_true( &lines >= 25, "Enough rows" )
  call assert_true( &columns >= 25, "Enough columns" )

  let X = join( map( range( 0, &columns - 1 ), {->'X'} ), '' )

  for i in range( 0, &lines )
    call append( line('$'), X )
  endfor

  " Delete the blank line that is always added to a buffer
  0delete

  call s:_ClearSigHelp()

  let v_sh = {
        \   'activeSignature': 0,
        \   'activeParameter': 0,
        \   'signatures': [
        \     { 'label': 'test function', 'parameters': [] }
        \   ]
        \ }

  " When displayed in the middle with plenty of space
  call s:_CheckSigHelpAtPos( v_sh, [ 10, 3 ], {
        \ 'line': 9,
        \ 'col': 1
        \ } )
  " Confirm that anchoring works (i.e. it doesn't move!)
  call s:_CheckSigHelpAtPos( v_sh, [ 20, 10 ], {
        \ 'line': 9,
        \ 'col': 1
        \ } )
  call s:_ClearSigHelp()

  " Window slides from left of screen
  call s:_CheckSigHelpAtPos( v_sh, [ 10, 2 ], {
        \ 'line': 9,
        \ 'col': 1,
        \ } )
  call s:_ClearSigHelp()

  " Window slides from left of screen
  call s:_CheckSigHelpAtPos( v_sh, [ 10, 1 ], {
        \ 'line': 9,
        \ 'col': 1,
        \ } )
  call s:_ClearSigHelp()

  " Cursor at top-left of window
  call s:_CheckSigHelpAtPos( v_sh, [ 1, 1 ], {
        \ 'line': 2,
        \ 'col': 1,
        \ } )
  call s:_ClearSigHelp()

  " Cursor at top-right of window
  call s:_CheckSigHelpAtPos( v_sh, [ 1, &columns ], {
        \ 'line': 2,
        \ 'col': &columns - len( "test function" ) - 1,
        \ } )
  call s:_ClearSigHelp()

  " Bottom-left of window
  call s:_CheckSigHelpAtPos( v_sh, [ &lines + 1, 1 ], {
        \ 'line': &lines - 2,
        \ 'col': 1,
        \ } )
  call s:_ClearSigHelp()

  " Bottom-right of window
  call s:_CheckSigHelpAtPos( v_sh, [ &lines + 1, &columns ], {
        \ 'line': &lines - 2,
        \ 'col': &columns - len( "test function" ) - 1,
        \ } )
  call s:_ClearSigHelp()

  call popup_clear()
endfunction

function! Test_Placement_MultiLine()
  call assert_true( &lines >= 25, "Enough rows" )
  call assert_true( &columns >= 25, "Enough columns" )

  let X = join( map( range( 0, &columns - 1 ), {->'X'} ), '' )

  for i in range( 0, &lines )
    call append( line('$'), X )
  endfor

  " Delete the blank line that is always added to a buffer
  0delete

  call s:_ClearSigHelp()

  let v_sh = {
        \   'activeSignature': 0,
        \   'activeParameter': 0,
        \   'signatures': [
        \     { 'label': 'test function', 'parameters': [] },
        \     { 'label': 'toast function', 'parameters': [
        \         { 'label': [ 0, 5 ] }
        \     ] },
        \   ]
        \ }

  " When displayed in the middle with plenty of space
  call s:_CheckSigHelpAtPos( v_sh, [ 10, 3 ], {
        \ 'line': 8,
        \ 'col': 1
        \ } )
  " Confirm that anchoring works (i.e. it doesn't move!)
  call s:_CheckSigHelpAtPos( v_sh, [ 20, 10 ], {
        \ 'line': 8,
        \ 'col': 1
        \ } )
  call s:_ClearSigHelp()

  " Window slides from left of screen
  call s:_CheckSigHelpAtPos( v_sh, [ 10, 2 ], {
        \ 'line': 8,
        \ 'col': 1,
        \ } )
  call s:_ClearSigHelp()

  " Window slides from left of screen
  call s:_CheckSigHelpAtPos( v_sh, [ 10, 1 ], {
        \ 'line': 8,
        \ 'col': 1,
        \ } )
  call s:_ClearSigHelp()

  " Cursor at top-left of window
  call s:_CheckSigHelpAtPos( v_sh, [ 1, 1 ], {
        \ 'line': 2,
        \ 'col': 1,
        \ } )
  call s:_ClearSigHelp()

  " Cursor at top-right of window
  call s:_CheckSigHelpAtPos( v_sh, [ 1, &columns ], {
        \ 'line': 2,
        \ 'col': &columns - len( "toast function" ) - 1,
        \ } )
  call s:_ClearSigHelp()

  " Bottom-left of window
  call s:_CheckSigHelpAtPos( v_sh, [ &lines + 1, 1 ], {
        \ 'line': &lines - 3,
        \ 'col': 1,
        \ } )
  call s:_ClearSigHelp()

  " Bottom-right of window
  call s:_CheckSigHelpAtPos( v_sh, [ &lines + 1, &columns ], {
        \ 'line': &lines - 3,
        \ 'col': &columns - len( "toast function" ) - 1,
        \ } )
  call s:_ClearSigHelp()

  call popup_clear()
endfunction
