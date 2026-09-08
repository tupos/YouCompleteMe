" Shared signature-help tests.
" Editor-specific adapters provide:
"
"   YcmTest_SignatureHelpWindowVisible( window_id )
"   YcmTest_SignatureHelpHighlights( window_id )
"   YcmTest_SignatureHelpSelectedLine( window_id )


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
