" Shared hierarchy integration-test setup and assertions.
" Editor-specific adapters provide:
"
"   YcmTest_HierarchyWindows()
"   YcmTest_HierarchyWindowLines( window_id )
"   YcmTest_HierarchyWindowSelectedLine( window_id )
"   YcmTest_HierarchyWindowFirstVisibleLine( window_id )
"   YcmTest_HierarchyWindowHeight( window_id )
"   YcmTest_HierarchyWindowHighlights( window_id )


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
  silent call feedkeys( "\<S-Tab>\<Tab>", 'xt' )
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
  silent call feedkeys( "\<Tab>\<Up>\<S-Tab>", 'xt' )
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
