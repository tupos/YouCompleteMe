" Shared hierarchy integration-test setup and assertions.
" Editor-specific adapters provide:
"
"   YcmTest_HierarchyWindows()
"   YcmTest_HierarchyWindowLines( window_id )
"   YcmTest_HierarchyWindowSelectedLine( window_id )
"   YcmTest_HierarchyWindowFirstVisibleLine( window_id )
"   YcmTest_HierarchyWindowHeight( window_id )
"   YcmTest_SetHierarchyWindowHeight( window_id, height )
"   YcmTest_CloseHierarchyWindow( window_id )
"   YcmTest_HierarchyWindowHighlights( window_id )
"   YcmTest_HierarchyWindowSelectionHighlight(
"       window_id, line_number )
"   YcmTest_HierarchyUnknownKeyCloses()


function! SetUp()
  let g:ycm_auto_hover = 1
  let g:ycm_auto_trigger = 1
  let g:ycm_keep_logfiles = 1
  let g:ycm_log_level = 'DEBUG'

  call youcompleteme#test#setup#SetUp()
endfunction


function! TearDown()
  call youcompleteme#test#setup#CleanUp()
endfunction


function! s:HierarchyWindow() abort
  let windows = YcmTest_HierarchyWindows()
  if len( windows ) != 1
    return -1
  endif
  return windows[ 0 ]
endfunction


function! s:HierarchyLines() abort
  let window_id = s:HierarchyWindow()
  if window_id < 0
    return []
  endif
  return YcmTest_HierarchyWindowLines( window_id )
endfunction


function! s:WaitForHierarchyLineCount( line_count ) abort
  call WaitForAssert( { ->
        \ assert_equal(
        \   1,
        \   len( YcmTest_HierarchyWindows() ) ) } )
  call WaitForAssert( { ->
        \ assert_equal(
        \   a:line_count,
        \   len( s:HierarchyLines() ) ) } )
endfunction


function! s:AssertHierarchyLine( line_number, pattern ) abort
  call assert_match(
        \ a:pattern,
        \ s:HierarchyLines()[ a:line_number - 1 ] )
endfunction


function! s:WaitForHierarchyClosed() abort
  call WaitForAssert( { ->
        \ assert_equal(
        \   0,
        \   len( YcmTest_HierarchyWindows() ) ) } )
endfunction


function! Test_Hierarchy_Selection_Follows_Expanded_Item()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  setlocal cursorline
  call cursor( [ 13, 8 ] )

  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )

  let window_id = s:HierarchyWindow()
  redraw
  let selected_highlight =
        \ YcmTest_HierarchyWindowSelectionHighlight(
        \   window_id,
        \   1 )

  " B0 is inserted above B1. The popup cursor and its visible cursorline must
  " both follow B1 from the first row to the second row.
  call feedkeys( "\<S-Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 2 )

  " Expansion updates the existing window instead of closing it while waiting
  " for the language server response.
  call assert_equal( window_id, s:HierarchyWindow() )
  call assert_equal(
        \ 2,
        \ YcmTest_HierarchyWindowSelectedLine( window_id ) )
  call assert_notequal(
        \ selected_highlight,
        \ YcmTest_HierarchyWindowSelectionHighlight(
        \   window_id,
        \   1 ) )
  call assert_equal(
        \ selected_highlight,
        \ YcmTest_HierarchyWindowSelectionHighlight(
        \   window_id,
        \   2 ) )

  call feedkeys( "\<C-c>", 'xt' )
  call s:WaitForHierarchyClosed()

  %bwipe!
endfunction


function! Test_Call_Hierarchy()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  call cursor( [ 1, 5 ] )

  call youcompleteme#hierarchy#StartRequest( 'call' )
  call s:WaitForHierarchyLineCount( 1 )
  " Check that `+Function f` is at the start of the only line.
  call s:AssertHierarchyLine( 1, '^+Function: f' )

  call feedkeys( "\<Tab>", 'xt' )
  " Check that f's callers are present.
  call s:WaitForHierarchyLineCount( 4 )
  call s:AssertHierarchyLine( 1, '^+Function: f.*:1' )
  call s:AssertHierarchyLine( 2, '^  +Function: g.*:4' )
  call s:AssertHierarchyLine( 3, '^  +Function: g.*:4' )
  call s:AssertHierarchyLine( 4, '^  +Function: h.*:9' )

  call feedkeys( "\<Down>\<Tab>", 'xt' )
  " Check that g's callers are present.
  call s:WaitForHierarchyLineCount( 5 )
  call s:AssertHierarchyLine( 1, '^+Function: f.*:1' )
  call s:AssertHierarchyLine( 2, '^  -Function: g.*:4' )
  call s:AssertHierarchyLine( 3, '^  -Function: g.*:4' )
  call s:AssertHierarchyLine( 4, '^    +Function: h.*:8' )
  call s:AssertHierarchyLine( 5, '^  +Function: h.*:9' )

  " silent, because h has no incoming calls.
  silent call feedkeys( "\<Down>\<Down>\<Tab>", 'xt' )
  " Check that the first h's callers are present.
  call s:WaitForHierarchyLineCount( 5 )
  call s:AssertHierarchyLine( 1, '^+Function: f.*:1' )
  call s:AssertHierarchyLine( 2, '^  -Function: g.*:4' )
  call s:AssertHierarchyLine( 3, '^  -Function: g.*:4' )
  call s:AssertHierarchyLine( 4, '^    -Function: h.*:8' )
  call s:AssertHierarchyLine( 5, '^  +Function: h.*:9' )

  " silent, because h has no incoming calls.
  silent call feedkeys( "\<Down>\<Tab>", 'xt' )
  " Check that the second h's callers are present.
  call s:WaitForHierarchyLineCount( 5 )
  call s:AssertHierarchyLine( 1, '^+Function: f.*:1' )
  call s:AssertHierarchyLine( 2, '^  -Function: g.*:4' )
  call s:AssertHierarchyLine( 3, '^  -Function: g.*:4' )
  call s:AssertHierarchyLine( 4, '^    -Function: h.*:8' )
  call s:AssertHierarchyLine( 5, '^  -Function: h.*:9' )

  " silent, because clangd does not support outgoing calls.
  silent call feedkeys( "\<Up>\<Up>\<Up>\<Up>\<S-Tab>", 'xt' )
  " Try to access callees of f.
  call s:WaitForHierarchyLineCount( 5 )
  call s:AssertHierarchyLine( 1, '^-Function: f.*:1' )
  call s:AssertHierarchyLine( 2, '^  -Function: g.*:4' )
  call s:AssertHierarchyLine( 3, '^  -Function: g.*:4' )
  call s:AssertHierarchyLine( 4, '^    -Function: h.*:8' )
  call s:AssertHierarchyLine( 5, '^  -Function: h.*:9' )

  " Re-root at h and show outgoing calls from h.
  call feedkeys( "\<Down>\<Down>\<Down>\<Down>\<S-Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 3 )
  call s:AssertHierarchyLine( 1, '^  +Function: g' )
  call s:AssertHierarchyLine( 2, '^  +Function: f' )
  call s:AssertHierarchyLine( 3, '^+Function: h' )

  " silent, because h has no incoming calls.
  silent call feedkeys( "\<S-Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 3 )
  silent call feedkeys( "\<Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 3 )
  call s:AssertHierarchyLine( 1, '^  +Function: g' )
  call s:AssertHierarchyLine( 2, '^  +Function: f' )
  call s:AssertHierarchyLine( 3, '^-Function: h' )

  call feedkeys( "\<C-c>", 'xt' )
  call s:WaitForHierarchyClosed()

  %bwipe!
endfunction


function! Test_Type_Hierarchy()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  call cursor( [ 13, 8 ] )

  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )
  " Check that `+Struct: B1` is at the start of the only line.
  call s:AssertHierarchyLine( 1, '^+Struct: B1' )

  call feedkeys( "\<Tab>", 'xt' )
  " Check that B1's subtypes are present.
  call s:WaitForHierarchyLineCount( 2 )
  call s:AssertHierarchyLine( 1, '^+Struct: B1.*:13' )
  call s:AssertHierarchyLine( 2, '^  +Struct: D1.*:16' )

  " silent, because D1 has no subtypes.
  silent call feedkeys( "\<Down>\<Tab>", 'xt' )
  " Try to access D1's subtypes.
  call s:WaitForHierarchyLineCount( 2 )
  call s:AssertHierarchyLine( 1, '^+Struct: B1.*:13' )
  call s:AssertHierarchyLine( 2, '^  -Struct: D1.*:16' )

  call feedkeys( "\<Up>\<S-Tab>", 'xt' )
  " Check that B1's supertypes are present.
  call s:WaitForHierarchyLineCount( 3 )
  call s:AssertHierarchyLine( 1, '^  +Struct: B0.*:12' )
  call s:AssertHierarchyLine( 2, '^-Struct: B1.*:13' )
  call s:AssertHierarchyLine( 3, '^  -Struct: D1.*:16' )

  " silent, because there are no supertypes of B0.
  silent call feedkeys( "\<Up>\<S-Tab>", 'xt' )
  " Try to access B0's supertypes.
  call s:WaitForHierarchyLineCount( 3 )
  call s:AssertHierarchyLine( 1, '^  -Struct: B0.*:12' )
  call s:AssertHierarchyLine( 2, '^-Struct: B1.*:13' )
  call s:AssertHierarchyLine( 3, '^  -Struct: D1.*:16' )

  call feedkeys( "\<Tab>", 'xt' )
  " Re-root at B0: supertypes to subtypes.
  call s:WaitForHierarchyLineCount( 4 )
  call s:AssertHierarchyLine( 1, '^+Struct: B0.*:12' )
  call s:AssertHierarchyLine( 2, '^  +Struct: B1.*:13' )
  call s:AssertHierarchyLine( 3, '^  +Struct: D0.*:15' )
  call s:AssertHierarchyLine( 4, '^  +Struct: D1.*:16' )

  call feedkeys( "\<Down>\<Down>\<Down>\<S-Tab>", 'xt' )
  " Re-root at D1: subtypes to supertypes.
  call s:WaitForHierarchyLineCount( 3 )
  call s:AssertHierarchyLine( 1, '^  +Struct: B0.*:12' )
  call s:AssertHierarchyLine( 2, '^  +Struct: B1.*:13' )
  call s:AssertHierarchyLine( 3, '^+Struct: D1.*:16' )

  " silent, because there are no subtypes of D1.
  silent call feedkeys( "\<Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 3 )
  call feedkeys( "\<Up>\<S-Tab>", 'xt' )
  " Expansion after re-rooting works.
  call s:WaitForHierarchyLineCount( 4 )
  call s:AssertHierarchyLine( 1, '^  +Struct: B0.*:12' )
  call s:AssertHierarchyLine( 2, '^    +Struct: B0.*:12' )
  call s:AssertHierarchyLine( 3, '^  -Struct: B1.*:13' )
  call s:AssertHierarchyLine( 4, '^-Struct: D1.*:16' )

  call feedkeys( "\<C-c>", 'xt' )
  call s:WaitForHierarchyClosed()

  %bwipe!
endfunction


function! Test_Hierarchy_Enter_Jumps_To_Selected_Item()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  let source_buffer = bufnr()
  call cursor( [ 13, 8 ] )

  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )

  call feedkeys( "\<Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 2 )

  let window_id = s:HierarchyWindow()
  call feedkeys( "\<Down>", 'xt' )
  call assert_equal(
        \ 2,
        \ YcmTest_HierarchyWindowSelectedLine( window_id ) )

  call feedkeys( "\<CR>", 'xt' )
  call s:WaitForHierarchyClosed()
  call assert_equal( source_buffer, bufnr() )
  call WaitForAssert(
        \ { -> assert_equal( [ 0, 16, 8, 0 ], getpos( '.' ) ) } )

  %bwipe!
endfunction


function! Test_Hierarchy_Cancel_Keys()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  call cursor( [ 13, 8 ] )

  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )

  call feedkeys( "\<Esc>", 'xt' )
  call s:WaitForHierarchyClosed()
  call assert_equal( [ 0, 13, 8, 0 ], getpos( '.' ) )

  let source_window = win_getid()
  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )

  if YcmTest_HierarchyUnknownKeyCloses()
    " Vim's popup filter closes the hierarchy and passes an unrelated key to
    " the source window. In Normal mode, `l` moves the source cursor right.
    call feedkeys( 'l', 'xt' )
    call s:WaitForHierarchyClosed()
    call assert_equal( [ 0, 13, 9, 0 ], getpos( '.' ) )
  else
    " Neovim uses a focused modal window. Unmapped Normal-mode commands act
    " inside that window instead of closing it or reaching the source window.
    let hierarchy_window = s:HierarchyWindow()
    call feedkeys( 'l', 'xt' )
    call assert_equal( hierarchy_window, win_getid() )
    call assert_equal( 1, len( YcmTest_HierarchyWindows() ) )

    " `q` is the conventional Neovim mapping for closing a modal window.
    call feedkeys( 'q', 'xt' )
    call s:WaitForHierarchyClosed()
    call assert_equal( source_window, win_getid() )
    call assert_equal( [ 0, 13, 8, 0 ], getpos( '.' ) )
  endif

  %bwipe!
endfunction


function! Test_Hierarchy_Movement_Keys_And_Clamping()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  call cursor( [ 13, 8 ] )

  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )
  call feedkeys( "\<Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 2 )

  let window_id = s:HierarchyWindow()
  call assert_equal(
        \ 1,
        \ YcmTest_HierarchyWindowSelectedLine( window_id ) )

  " Every upward movement key clamps at the first item.
  for key in [ "\<Up>", "\<C-p>", "\<C-k>", 'k' ]
    call feedkeys( key, 'xt' )
    call assert_equal(
          \ 1,
          \ YcmTest_HierarchyWindowSelectedLine( window_id ) )
  endfor

  " Every downward movement key selects the second item, and every
  " corresponding upward key returns to the first item.
  for [ down_key, up_key ] in [
        \ [ "\<Down>", "\<Up>" ],
        \ [ "\<C-n>", "\<C-p>" ],
        \ [ "\<C-j>", "\<C-k>" ],
        \ [ 'j', 'k' ],
        \ ]
    call feedkeys( down_key, 'xt' )
    call assert_equal(
          \ 2,
          \ YcmTest_HierarchyWindowSelectedLine( window_id ) )
    call feedkeys( up_key, 'xt' )
    call assert_equal(
          \ 1,
          \ YcmTest_HierarchyWindowSelectedLine( window_id ) )
  endfor

  call feedkeys( "\<Down>", 'xt' )
  " Every downward movement key clamps at the last item.
  for key in [ "\<Down>", "\<C-n>", "\<C-j>", 'j' ]
    call feedkeys( key, 'xt' )
    call assert_equal(
          \ 2,
          \ YcmTest_HierarchyWindowSelectedLine( window_id ) )
  endfor

  call feedkeys( "\<C-c>", 'xt' )
  call s:WaitForHierarchyClosed()

  %bwipe!
endfunction


function! Test_Hierarchy_Scrolls_To_Selected_Item()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  call cursor( [ 1, 5 ] )

  call youcompleteme#hierarchy#StartRequest( 'call' )
  call s:WaitForHierarchyLineCount( 1 )
  call feedkeys( "\<Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 4 )
  call feedkeys( "\<Down>\<Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 5 )

  let window_id = s:HierarchyWindow()
  call YcmTest_SetHierarchyWindowHeight( window_id, 2 )
  call WaitForAssert( { ->
        \ assert_equal(
        \   2,
        \   YcmTest_HierarchyWindowHeight( window_id ) ) } )
  " The second item is initially selected and remains visible after the
  " viewport is resized. Vim and Neovim may choose a different initial top
  " line while preserving that invariant.
  let first_visible_line =
        \ YcmTest_HierarchyWindowFirstVisibleLine( window_id )
  let selected_line =
        \ YcmTest_HierarchyWindowSelectedLine( window_id )
  call assert_true( first_visible_line <= selected_line )
  call assert_true(
        \ selected_line <
        \ first_visible_line + YcmTest_HierarchyWindowHeight( window_id ) )

  " Moving to the fifth item scrolls it to the bottom of the two-line
  " viewport.
  call feedkeys( repeat( "\<Down>", 3 ), 'xt' )
  call assert_equal(
        \ 5,
        \ YcmTest_HierarchyWindowSelectedLine( window_id ) )
  call assert_equal(
        \ 4,
        \ YcmTest_HierarchyWindowFirstVisibleLine( window_id ) )

  " Moving back to the first item scrolls it to the top of the viewport.
  call feedkeys( repeat( "\<Up>", 4 ), 'xt' )
  call assert_equal(
        \ 1,
        \ YcmTest_HierarchyWindowSelectedLine( window_id ) )
  call assert_equal(
        \ 1,
        \ YcmTest_HierarchyWindowFirstVisibleLine( window_id ) )

  call feedkeys( "\<C-c>", 'xt' )
  call s:WaitForHierarchyClosed()

  %bwipe!
endfunction


function! Test_Hierarchy_Highlights()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  call cursor( [ 13, 8 ] )

  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )
  call feedkeys( "\<Tab>", 'xt' )
  call s:WaitForHierarchyLineCount( 2 )

  let window_id = s:HierarchyWindow()
  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 10,
        \     'length': 2,
        \     'group': 'YCM-symbol-Struct',
        \   },
        \   {
        \     'line': 1,
        \     'column': 13,
        \     'length': 14,
        \     'group': 'YCM-symbol-file',
        \   },
        \   {
        \     'line': 1,
        \     'column': 28,
        \     'length': 2,
        \     'group': 'YCM-symbol-line-num',
        \   },
        \   {
        \     'line': 2,
        \     'column': 12,
        \     'length': 2,
        \     'group': 'YCM-symbol-Struct',
        \   },
        \   {
        \     'line': 2,
        \     'column': 15,
        \     'length': 14,
        \     'group': 'YCM-symbol-file',
        \   },
        \   {
        \     'line': 2,
        \     'column': 30,
        \     'length': 2,
        \     'group': 'YCM-symbol-line-num',
        \   },
        \ ],
        \ YcmTest_HierarchyWindowHighlights( window_id ) )

  call feedkeys( "\<C-c>", 'xt' )
  call s:WaitForHierarchyClosed()

  %bwipe!
endfunction


function! Test_Hierarchy_No_Results_Opens_No_Window()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  call cursor( [ 2, 1 ] )

  for kind in [ 'call', 'type' ]
    call youcompleteme#hierarchy#StartRequest( kind )
    call assert_equal( [], YcmTest_HierarchyWindows() )
  endfor

  let messages = execute( 'messages' )
  call assert_match( 'No call hierarchy found', messages )
  call assert_match( 'No type hierarchy found', messages )
  messages clear

  %bwipe!
endfunction


function! Test_Hierarchy_External_Close_Allows_Reopen()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/hierarchies.cc',
        \ {} )
  call cursor( [ 13, 8 ] )

  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )
  let first_window = s:HierarchyWindow()

  call YcmTest_CloseHierarchyWindow( first_window )
  call s:WaitForHierarchyClosed()
  call assert_equal( [ 0, 13, 8, 0 ], getpos( '.' ) )

  " The hierarchy remains usable after its window is closed externally.
  call youcompleteme#hierarchy#StartRequest( 'type' )
  call s:WaitForHierarchyLineCount( 1 )
  call assert_notequal( first_window, s:HierarchyWindow() )

  call feedkeys( "\<C-c>", 'xt' )
  call s:WaitForHierarchyClosed()

  %bwipe!
endfunction
