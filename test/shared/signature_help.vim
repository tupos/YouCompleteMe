" Shared signature-help tests.
" Editor-specific adapters provide:
"
"   YcmTest_SignatureHelpWindowVisible( window_id )
"   YcmTest_SignatureHelpHighlights( window_id )
"   YcmTest_SignatureHelpSelectedLine( window_id )
"   YcmTest_SetCharAvailOverride( enabled )
"   YcmTest_SignatureHelpEmptyBufferHasKnownBug()
"   YcmTest_SignatureHelpIsBelowAnchor( window_id )
"   YcmTest_SignatureHelpScreenRectangle( window_id )


let s:timer_interval = 2000


function! YcmTest_CheckSignatureHelpAvailable( filetype ) abort
  return pyxeval(
        \ 'ycm_state.SignatureHelpAvailableRequestComplete('
        \ . ' vim.eval( "a:filetype" ), False )' )
endfunction


function! YcmTest_WaitForSignatureHelpAvailable( filetype ) abort
  let tries = 0
  call WaitFor(
        \ {-> YcmTest_CheckSignatureHelpAvailable( a:filetype ) } )
  while py3eval(
        \ 'ycm_state._signature_help_available_requests[ '
        \ . 'vim.eval( "a:filetype" ) ].Response() == "PENDING"' ) &&
        \ tries < 10
    " Force sending another request.
    py3 ycm_state._signature_help_available_requests[
          \ vim.eval( 'a:filetype' ) ].Start( vim.eval( 'a:filetype' ) )
    call WaitFor(
          \ {-> YcmTest_CheckSignatureHelpAvailable( a:filetype ) } )
    let tries += 1
  endwhile
endfunction


function! s:RectanglesOverlap( first, second ) abort
  return a:first[ 0 ] < a:second[ 0 ] + a:second[ 2 ]
        \ && a:second[ 0 ] < a:first[ 0 ] + a:first[ 2 ]
        \ && a:first[ 1 ] < a:second[ 1 ] + a:second[ 3 ]
        \ && a:second[ 1 ] < a:first[ 1 ] + a:first[ 3 ]
endfunction


function! s:WaitForSignatureHelpWindow() abort
  call WaitForAssert( {->
        \ assert_true(
        \   pyxeval( 'ycm_state.SignatureHelpRequestReady()' ),
        \   'signature-help request ready' ) } )
  call WaitForAssert( {->
        \ assert_true(
        \   youcompleteme#signature_help#WindowID() > 0,
        \   'signature-help window ID' ) } )

  return youcompleteme#signature_help#WindowID()
endfunction


function! Test_SignatureHelp_EnoughScreenSpace()
  call assert_true(
        \ &lines >= 25,
        \ &lines . ' is not enough rows; need 25.' )
  call assert_true(
        \ &columns >= 80,
        \ &columns . ' is not enough columns; need 80.' )
endfunction


function! Test_SignatureHelp_AfterTrigger()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/vim/mixed_filetype.vim',
        \ { 'native_ft': 0, 'force_delay': v:true } )

  call WaitFor(
        \ {-> YcmTest_CheckSignatureHelpAvailable( 'vim' ) } )
  call YcmTest_WaitForSignatureHelpAvailable( 'python' )

  call setpos( '.', [ 0, 3, 17 ] )
  call YcmTest_SetCharAvailOverride( v:true )

  " The checks run in a timer callback so that the editor remains in insert
  " mode while the signature-help request completes.
  function! Check( id ) closure
    call WaitForAssert( {->
          \   assert_true(
          \     pyxeval(
          \       'ycm_state.SignatureHelpRequestReady()'
          \     ),
          \     'signature-help request ready'
          \   )
          \ } )
    call WaitForAssert( {->
          \   assert_true(
          \     pyxeval(
          \       "bool( ycm_state.GetSignatureHelpResponse()[ 'signatures' ] )"
          \     ),
          \     'signature-help request has signatures'
          \   )
          \ } )
    call WaitForAssert( {->
          \   assert_true(
          \     YcmTest_SignatureHelpWindowVisible(
          \       youcompleteme#signature_help#WindowID() ),
          \     'signature-help window visible'
          \   )
          \ } )

    call YcmTest_SetCharAvailOverride( v:false )
    call feedkeys( "\<ESC>" )
  endfunction

  call assert_false(
        \ pyxeval( 'ycm_state.SignatureHelpRequestReady()' ) )
  call timer_start( s:timer_interval, funcref( 'Check' ) )
  call feedkeys( 'cl(', 'ntx!' )
  call assert_false( pumvisible(), 'pumvisible()' )

  call WaitForAssert( {->
        \ assert_equal(
        \   0,
        \   youcompleteme#signature_help#WindowID(),
        \   'signature-help window ID after leaving insert mode' ) } )

  call YcmTest_SetCharAvailOverride( v:false )
  delfunc! Check
endfunction


function! SetUp_Test_SignatureHelp_ManualHideShow()
  imap <silent> kjkj <Plug>(YCMToggleSignatureHelp)
endfunction


function! Test_SignatureHelp_ManualHideShow()
  call youcompleteme#test#setup#OpenFile(
        \ 'test/testdata/cpp/complete_with_sig_help.cc', {} )
  call YcmTest_WaitForSignatureHelpAvailable( 'cpp' )

  call setpos( '.', [ 0, 10, 1 ] )
  call YcmTest_SetCharAvailOverride( v:true )
  let window_id = 0

  function! Check( ... ) closure
    let window_id = s:WaitForSignatureHelpWindow()
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    call FeedAndCheckAgain( 'kjkj', funcref( 'Check2' ) )
  endfunction

  function! Check2( ... ) closure
    call assert_equal(
          \ window_id,
          \ youcompleteme#signature_help#WindowID() )
    call assert_false(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    call FeedAndCheckAgain( 'kjkj', funcref( 'Check3' ) )
  endfunction

  function! Check3( ... ) closure
    call assert_equal(
          \ window_id,
          \ youcompleteme#signature_help#WindowID() )
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    call feedkeys( "\<Esc>" )
  endfunction

  call FeedAndCheckMain( 'iprintf(', funcref( 'Check' ) )

  call YcmTest_SetCharAvailOverride( v:false )
  delfunc! Check
  delfunc! Check2
  delfunc! Check3
endfunction


function! TearDown_Test_SignatureHelp_ManualHideShow()
  silent! iunmap kjkj
endfunction


function! SetUp_Test_SignatureHelp_ManualNoSignatures()
  imap <silent> kjkj <Plug>(YCMToggleSignatureHelp)
endfunction


function! Test_SignatureHelp_ManualNoSignatures()
  call youcompleteme#test#setup#OpenFile(
        \ 'test/testdata/cpp/complete_with_sig_help.cc', {} )
  call YcmTest_WaitForSignatureHelpAvailable( 'cpp' )

  call setpos( '.', [ 0, 10, 1 ] )
  call YcmTest_SetCharAvailOverride( v:true )
  let window_id = 0

  function! CheckSignatures( ... ) closure
    let window_id = s:WaitForSignatureHelpWindow()
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    call FeedAndCheckAgain( ')', funcref( 'CheckSignaturesClosed' ) )
  endfunction

  function! CheckSignaturesClosed( ... ) closure
    call WaitForAssert( {->
          \ assert_equal(
          \   0,
          \   youcompleteme#signature_help#WindowID() ) } )
    call assert_false(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    call FeedAndCheckAgain( 'kjkj', funcref( 'CheckStillClosed' ) )
  endfunction

  function! CheckStillClosed( ... ) closure
    call assert_equal(
          \ 0,
          \ youcompleteme#signature_help#WindowID() )
    call assert_false(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    call feedkeys( "\<Esc>" )
  endfunction

  call FeedAndCheckMain(
        \ 'iprintf(',
        \ funcref( 'CheckSignatures' ) )

  call YcmTest_SetCharAvailOverride( v:false )
  delfunc! CheckSignatures
  delfunc! CheckSignaturesClosed
  delfunc! CheckStillClosed
endfunction


function! TearDown_Test_SignatureHelp_ManualNoSignatures()
  silent! iunmap kjkj
endfunction


function! Test_SignatureHelp_ClosesWhenCompletionMenuTakesOnlySpace()
  call youcompleteme#test#setup#OpenFile(
        \ 'test/testdata/python/test.py', {} )
  call YcmTest_WaitForSignatureHelpAvailable( 'python' )
  call setpos( '.', [ 0, 1, 24 ] )
  call YcmTest_SetCharAvailOverride( v:true )
  let window_id = 0

  function! CheckSignatureHelpAndTriggerCompletion( id ) closure
    let window_id = s:WaitForSignatureHelpWindow()
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    " The signature window is below the cursor because there is no room above.
    " Trigger a completion menu in that only available space.
    call timer_start(
          \ s:timer_interval,
          \ funcref( 'CheckCompletionVisibleAndSignatureHelpClosed' ) )
    call feedkeys( ' os.', 't' )
  endfunction

  function! CheckCompletionVisibleAndSignatureHelpClosed( id ) closure
    redraw
    call WaitForAssert( {->
          \ assert_true( pumvisible(), 'completion menu visible' ) } )
    call WaitForAssert( {->
          \ assert_equal(
          \   0,
          \   youcompleteme#signature_help#WindowID(),
          \   'signature-help window ID' ) } )
    call assert_false(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    call YcmTest_SetCharAvailOverride( v:false )
    call feedkeys( "\<ESC>", 't' )
  endfunction

  call timer_start(
        \ s:timer_interval,
        \ funcref( 'CheckSignatureHelpAndTriggerCompletion' ) )
  call feedkeys( 'C(', 'ntx!' )

  call YcmTest_SetCharAvailOverride( v:false )
  delfunc! CheckSignatureHelpAndTriggerCompletion
  delfunc! CheckCompletionVisibleAndSignatureHelpClosed
endfunction


function! Test_SignatureHelp_AppearsBelowTopLine()
  call youcompleteme#test#setup#OpenFile(
        \ 'test/testdata/python/test.py', {} )
  call YcmTest_WaitForSignatureHelpAvailable( 'python' )
  call setpos( '.', [ 0, 1, 24 ] )
  call YcmTest_SetCharAvailOverride( v:true )

  function! Check( id ) closure
    let window_id = s:WaitForSignatureHelpWindow()
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )
    call assert_true(
          \ YcmTest_SignatureHelpIsBelowAnchor( window_id ) )

    call YcmTest_SetCharAvailOverride( v:false )
    call feedkeys( "\<ESC>" )
  endfunction

  call timer_start( s:timer_interval, funcref( 'Check' ) )
  call feedkeys( 'cl(', 'ntx!' )

  call YcmTest_SetCharAvailOverride( v:false )
  delfunc! Check
endfunction


function! s:TestSignatureHelpWithCompletionMenu( sign_column ) abort
  call youcompleteme#test#setup#OpenFile(
        \ '/third_party/ycmd/ycmd/tests/clangd/testdata/general_fallback'
        \ . '/make_drink.cc', {} )
  call YcmTest_WaitForSignatureHelpAvailable( 'cpp' )
  execute 'setlocal signcolumn=' . a:sign_column
  call setpos( '.', [ 0, 7, 13 ] )
  call YcmTest_SetCharAvailOverride( v:true )
  let window_id = 0

  function! CheckSignatureHelp( id ) closure
    let window_id = s:WaitForSignatureHelpWindow()
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    call timer_start(
          \ s:timer_interval,
          \ funcref( 'CheckCompletionMenu' ) )
    call feedkeys( ' TypeOfD', 't' )
  endfunction

  function! CheckCompletionMenu( id ) closure
    call WaitForAssert( {->
          \ assert_true( pumvisible(), 'completion menu visible' ) } )
    call WaitForAssert( {->
          \ assert_notequal(
          \   [],
          \   complete_info().items,
          \   'completion menu items' ) } )
    redraw

    call assert_equal(
          \ [ 6, 13 ],
          \ youcompleteme#signature_help#Anchor() )
    call assert_equal(
          \ window_id,
          \ youcompleteme#signature_help#WindowID() )
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible( window_id ) )

    let popup_menu = pum_getpos()
    let popup_menu_rectangle = [
          \ popup_menu.row,
          \ popup_menu.col,
          \ popup_menu.height,
          \ popup_menu.width,
          \ ]
    call assert_false(
          \ s:RectanglesOverlap(
          \   YcmTest_SignatureHelpScreenRectangle( window_id ),
          \   popup_menu_rectangle ),
          \ 'signature help overlaps the completion menu' )

    call YcmTest_SetCharAvailOverride( v:false )
    call feedkeys( "\<ESC>", 't' )
  endfunction

  call timer_start(
        \ s:timer_interval,
        \ funcref( 'CheckSignatureHelp' ) )
  call feedkeys( 'C(', 'ntx!' )

  call WaitForAssert( {->
        \ assert_equal(
        \   0,
        \   youcompleteme#signature_help#WindowID() ) } )
  call YcmTest_SetCharAvailOverride( v:false )
  delfunc! CheckSignatureHelp
  delfunc! CheckCompletionMenu
endfunction


function! Test_SignatureHelp_WithCompletionMenuNoSigns()
  call s:TestSignatureHelpWithCompletionMenu( 'no' )
endfunction


function! Test_SignatureHelp_WithCompletionMenuAndSigns()
  call s:TestSignatureHelpWithCompletionMenu( 'auto' )
endfunction


function! s:SetUpSemanticCompletionPopupWithSignatureHelp() abort
  set signcolumn=no
  set completeopt-=preview
  set completeopt+=popup
  call youcompleteme#test#setup#PushGlobal(
        \ 'ycm_add_preview_to_completeopt',
        \ 'popup' )
endfunction


function! SetUp_Test_Semantic_Completion_Popup_With_Sig_Help()
  call s:SetUpSemanticCompletionPopupWithSignatureHelp()
endfunction


function! s:TestSemanticCompletionPopupWithSignatureHelp() abort
  call SkipIf(
        \ !YcmTest_CompletionInfoSupported(),
        \ 'no completion info window' )
  call youcompleteme#test#setup#OpenFile(
        \ 'test/testdata/cpp/complete_with_sig_help.cc', {} )
  call YcmTest_WaitForSignatureHelpAvailable( 'cpp' )

  call setpos( '.', [ 0, 10, 1 ] )
  call YcmTest_SetCharAvailOverride( v:true )

  function! Check( ... )
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible(
          \   s:WaitForSignatureHelpWindow() ) )

    call FeedAndCheckAgain( '"", t.', funcref( 'Check2' ) )
  endfunction

  function! Check2( ... )
    call WaitForCompletion()
    call CheckCompletionItemsContainsExactly(
          \ [ 'that_is_a_thing', 'this_is_a_thing' ] )
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible(
          \   s:WaitForSignatureHelpWindow() ) )

    call CheckCurrentLine( 'printf("", t.' )
    call FeedAndCheckAgain( "\<Tab>", funcref( 'Check3' ) )
  endfunction

  function! Check3( ... )
    call WaitForCompletion()
    call CheckCompletionItemsContainsExactly(
          \ [ 'that_is_a_thing', 'this_is_a_thing' ] )
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible(
          \   s:WaitForSignatureHelpWindow() ) )

    let completion = complete_info()
    let selected = completion.items[ completion.selected ]
    call assert_equal( 'that_is_a_thing', selected.word )

    call YcmTest_WaitForCompletionInfoVisible()

    call CheckCurrentLine( 'printf("", t.that_is_a_thing' )
    call FeedAndCheckAgain( "\<Tab>", funcref( 'Check4' ) )
  endfunction

  function! Check4( ... )
    call WaitForCompletion()
    call CheckCompletionItemsContainsExactly(
          \ [ 'that_is_a_thing', 'this_is_a_thing' ] )
    call assert_true(
          \ YcmTest_SignatureHelpWindowVisible(
          \   s:WaitForSignatureHelpWindow() ) )

    let completion = complete_info()
    let selected = completion.items[ completion.selected ]
    call assert_equal( 'this_is_a_thing', selected.word )
    call assert_true(
          \ YcmTest_CompletionInfoWindowVisible() )

    call CheckCurrentLine( 'printf("", t.this_is_a_thing' )
    call feedkeys( "\<Esc>" )
  endfunction

  call FeedAndCheckMain( 'iprintf(', funcref( 'Check' ) )

  call YcmTest_SetCharAvailOverride( v:false )

  delfunc! Check
  delfunc! Check2
  delfunc! Check3
  delfunc! Check4
endfunction


function! Test_Semantic_Completion_Popup_With_Sig_Help()
  call s:TestSemanticCompletionPopupWithSignatureHelp()
endfunction


function! s:TearDownSemanticCompletionPopupWithSignatureHelp() abort
  set signcolumn&
  call youcompleteme#test#setup#PopGlobal(
        \ 'ycm_add_preview_to_completeopt' )
endfunction


function! TearDown_Test_Semantic_Completion_Popup_With_Sig_Help()
  call s:TearDownSemanticCompletionPopupWithSignatureHelp()
endfunction


function! SetUp_Test_Semantic_Completion_Popup_With_Sig_Help_EmptyBuf()
  call s:SetUpSemanticCompletionPopupWithSignatureHelp()
  call youcompleteme#test#setup#PushGlobal(
        \ 'ycm_filetype_whitelist',
        \ {
        \   '*': 1,
        \   'ycm_nofiletype': 1,
        \ } )
  call youcompleteme#test#setup#PushGlobal(
        \ 'ycm_filetype_blacklist',
        \ {} )
endfunction


function! Test_Semantic_Completion_Popup_With_Sig_Help_EmptyBuf()
  call s:TestSemanticCompletionPopupWithSignatureHelp()

  if YcmTest_SignatureHelpEmptyBufferHasKnownBug()
    throw 'SKIPPED: XFAIL: This test is expected to fail due to '
          \ .. 'https://github.com/ycm-core/YouCompleteMe/issues/3781'
  endif
endfunction


function! TearDown_Test_Semantic_Completion_Popup_With_Sig_Help_EmptyBuf()
  call youcompleteme#test#setup#PopGlobal( 'ycm_filetype_whitelist' )
  call youcompleteme#test#setup#PopGlobal( 'ycm_filetype_blacklist' )
  call s:TearDownSemanticCompletionPopupWithSignatureHelp()
endfunction


function! Test_SignatureHelp_UI_RendersPresentation()
  new
  call setline(
        \ 1,
        \ repeat( [ repeat( 'x', 40 ) ], 20 ) )
  setlocal syntax=cpp
  call cursor( 10, 10 )
  redraw

  call assert_true(
        \ youcompleteme#signature_help#Supported() )
  call youcompleteme#signature_help#Update( {
        \ 'activeSignature': 1,
        \ 'activeParameter': 1,
        \ 'signatures': [
        \   {
        \     'label': 'first(int one)',
        \     'parameters': [
        \       { 'label': [ 6, 13 ] },
        \     ],
        \   },
        \   {
        \     'label': 'second(int one, int two)',
        \     'parameters': [
        \       { 'label': [ 7, 14 ] },
        \       { 'label': [ 16, 23 ] },
        \     ],
        \   },
        \ ],
        \ } )

  let window_id = youcompleteme#signature_help#WindowID()
  call assert_true(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )
  call assert_equal(
        \ [
        \   'first(int one)',
        \   'second(int one, int two)',
        \ ],
        \ getbufline( winbufnr( window_id ), 1, '$' ) )
  call assert_equal(
        \ 'cpp',
        \ getbufvar( winbufnr( window_id ), '&syntax' ) )
  call assert_equal(
        \ 2,
        \ YcmTest_SignatureHelpSelectedLine( window_id ) )
  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 16,
        \     'length': 7,
        \     'group': 'YCMInverse',
        \   },
        \ ],
        \ YcmTest_SignatureHelpHighlights( window_id ) )
endfunction


function! Test_SignatureHelp_UI_HideShowAndClose()
  new
  call setline(
        \ 1,
        \ repeat( [ repeat( 'x', 40 ) ], 20 ) )
  call cursor( 10, 10 )
  redraw

  call youcompleteme#signature_help#Update( {
        \ 'activeSignature': 0,
        \ 'activeParameter': 0,
        \ 'signatures': [
        \   {
        \     'label': 'function(int value)',
        \     'parameters': [
        \       { 'label': [ 9, 18 ] },
        \     ],
        \   },
        \ ],
        \ } )

  let window_id = youcompleteme#signature_help#WindowID()
  call assert_true(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )
  call assert_equal(
        \ 'ACTIVE',
        \ youcompleteme#signature_help#State() )

  call youcompleteme#signature_help#ToggleVisibility()

  call assert_equal(
        \ window_id,
        \ youcompleteme#signature_help#WindowID() )
  call assert_false(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )
  call assert_equal(
        \ 'ACTIVE_SUPPRESSED',
        \ youcompleteme#signature_help#State() )
  call assert_equal(
        \ 'ACTIVE',
        \ youcompleteme#signature_help#StateForRequest() )

  call youcompleteme#signature_help#ToggleVisibility()

  call assert_equal(
        \ window_id,
        \ youcompleteme#signature_help#WindowID() )
  call assert_true(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )

  call youcompleteme#signature_help#Clear()

  call assert_equal(
        \ 0,
        \ youcompleteme#signature_help#WindowID() )
  call assert_false(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )
  call assert_equal(
        \ 'INACTIVE',
        \ youcompleteme#signature_help#State() )
endfunction


function! Test_SignatureHelp_UI_ReplacesPresentation()
  new
  call setline(
        \ 1,
        \ repeat( [ repeat( 'x', 40 ) ], 20 ) )
  call cursor( 10, 10 )
  redraw

  call youcompleteme#signature_help#Update( {
        \ 'activeSignature': 0,
        \ 'activeParameter': 0,
        \ 'signatures': [
        \   {
        \     'label': 'old(int value)',
        \     'parameters': [
        \       { 'label': [ 4, 13 ] },
        \     ],
        \   },
        \ ],
        \ } )

  let window_id = youcompleteme#signature_help#WindowID()
  call assert_true(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )

  call youcompleteme#signature_help#Update( {
        \ 'activeSignature': 1,
        \ 'activeParameter': 0,
        \ 'signatures': [
        \   {
        \     'label': 'replacement()',
        \     'parameters': [],
        \   },
        \   {
        \     'label': 'selected(long value)',
        \     'parameters': [
        \       { 'label': [ 9, 19 ] },
        \     ],
        \   },
        \ ],
        \ } )

  call assert_equal(
        \ window_id,
        \ youcompleteme#signature_help#WindowID() )
  call assert_equal(
        \ [
        \   'replacement()',
        \   'selected(long value)',
        \ ],
        \ getbufline( winbufnr( window_id ), 1, '$' ) )
  call assert_equal(
        \ 2,
        \ YcmTest_SignatureHelpSelectedLine( window_id ) )
  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 9,
        \     'length': 10,
        \     'group': 'YCMInverse',
        \   },
        \ ],
        \ YcmTest_SignatureHelpHighlights( window_id ) )
endfunction


function! Test_SignatureHelp_UI_EmptyResponseCloses()
  new
  call setline(
        \ 1,
        \ repeat( [ repeat( 'x', 40 ) ], 20 ) )
  call cursor( 10, 10 )
  redraw

  call youcompleteme#signature_help#Update( {
        \ 'activeSignature': 0,
        \ 'activeParameter': 0,
        \ 'signatures': [
        \   {
        \     'label': 'function(int value)',
        \     'parameters': [
        \       { 'label': [ 9, 18 ] },
        \     ],
        \   },
        \ ],
        \ } )

  let window_id = youcompleteme#signature_help#WindowID()
  call assert_true(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )

  call youcompleteme#signature_help#Update( {
        \ 'signatures': [],
        \ } )

  call assert_equal(
        \ 0,
        \ youcompleteme#signature_help#WindowID() )
  call assert_false(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )
  call assert_equal(
        \ 'INACTIVE',
        \ youcompleteme#signature_help#State() )
  call assert_equal(
        \ [],
        \ youcompleteme#signature_help#Anchor() )
endfunction


function! Test_SignatureHelp_UI_PreservesAnchorAcrossUpdates()
  new
  call setline(
        \ 1,
        \ repeat( [ repeat( 'x', 40 ) ], 20 ) )
  call cursor( 10, 10 )
  redraw

  let signature_info = {
        \ 'activeSignature': 0,
        \ 'activeParameter': 0,
        \ 'signatures': [
        \   {
        \     'label': 'function(int value)',
        \     'parameters': [
        \       { 'label': [ 9, 18 ] },
        \     ],
        \   },
        \ ],
        \ }
  call youcompleteme#signature_help#Update( signature_info )

  let window_id = youcompleteme#signature_help#WindowID()
  call assert_equal(
        \ [ 9, 9 ],
        \ youcompleteme#signature_help#Anchor() )

  call cursor( 12, 20 )
  redraw
  call youcompleteme#signature_help#Update( signature_info )

  call assert_equal(
        \ window_id,
        \ youcompleteme#signature_help#WindowID() )
  call assert_true(
        \ YcmTest_SignatureHelpWindowVisible( window_id ) )
  call assert_equal(
        \ [ 9, 9 ],
        \ youcompleteme#signature_help#Anchor() )
endfunction
