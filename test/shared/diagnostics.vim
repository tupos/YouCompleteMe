" Shared diagnostics integration-test setup and assertions.
" Editor-specific adapters provide:
"
"   YcmTest_DetailedDiagnosticWindow()
"   YcmTest_CheckDetailedDiagnosticWindow( window_id )
"   YcmTest_DetailedDiagnosticWindowExists( window_id )
"   YcmTest_CloseDetailedDiagnosticWindow( window_id )
"   YcmTest_SetCharAvailOverride( enabled )
"   YcmTest_ProcessCursorMoved()
"   YcmTest_VirtualDiagnosticProperties()
"   YcmTest_DiagnosticHighlights( line_number )

function! SetUp()
  let g:ycm_use_clangd = 1
  let g:ycm_confirm_extra_conf = 0
  let g:ycm_auto_trigger = 1
  let g:ycm_keep_logfiles = 1
  " Keep diagnostics tests independent of signature-help requests, which can
  " cause a language server to publish diagnostics as a side effect.
  let g:ycm_disable_signature_help = 1
  let g:ycm_log_level = 'DEBUG'
  let g:ycm_always_populate_location_list = 1
  let g:ycm_enable_semantic_highlighting = 1
  let g:ycm_auto_hover = ''

  " diagnostics take ages
  let g:ycm_test_min_delay = 7
  call youcompleteme#test#setup#SetUp()
endfunction

function! TearDown()
  call youcompleteme#test#setup#CleanUp()
endfunction


function! YcmTest_RequestDiagnostics()
  doautocmd <nomodeline> TextChanged
  return ''
endfunction


function! Test_Diagnostics_Update_In_Insert_Mode()
  call youcompleteme#test#setup#OpenFile(
    \ '/test/testdata/cpp/new_file.cpp', {} )

  " Must do the checks in a timer callback because we need to stay in insert
  " mode until done.
  function! Check( id ) closure
    call WaitForAssert( {-> assert_true( len( sign_getplaced(
                           \ '%',
                           \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )
    call feedkeys( "\<ESC>" )
  endfunction

  call FeedAndCheckMain(
    \ "imain(\<C-R>=YcmTest_RequestDiagnostics()\<CR>",
    \ funcref( 'Check' ) )
endfunction

function! SetUp_Test_Disable_Diagnostics_Update_In_insert_Mode()
  call youcompleteme#test#setup#PushGlobal(
    \ 'ycm_update_diagnostics_in_insert_mode', 0 )
endfunction

function! Test_Disable_Diagnostics_Update_In_insert_Mode()
  call youcompleteme#test#setup#OpenFile(
    \ '/test/testdata/cpp/new_file.cpp', {} )

  " Must do the checks in a timer callback because we need to stay in insert
  " mode until done.
  function! CheckNoDiagUIAfterOpenParenthesis( id ) closure
    call WaitForAssert( {->
      \ assert_true(
        \ py3eval(
           \ 'len( ycm_state.CurrentBuffer()._diag_interface._diagnostics )'
      \ ) ) } )
    call WaitForAssert( {-> assert_false( len( sign_getplaced(
                           \ '%',
                           \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )

    call FeedAndCheckAgain(
      \ "   \<BS>\<BS>\<BS>)" .
      \ "\<C-R>=YcmTest_RequestDiagnostics()\<CR>",
      \ funcref( 'CheckNoDiagUIAfterClosingPatenthesis' ) )
  endfunction

  function! CheckNoDiagUIAfterClosingPatenthesis( id ) closure
    call WaitForAssert( {->
      \ assert_true(
        \ py3eval(
           \ 'len( ycm_state.CurrentBuffer()._diag_interface._diagnostics )'
      \ ) ) } )
    call WaitForAssert( {-> assert_false( len( sign_getplaced(
                           \ '%',
                           \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )

    call feedkeys( "\<ESC>" )
    call FeedAndCheckAgain( "\<ESC>",
      \ funcref( 'CheckDiagUIRefreshedAfterLeavingInsertMode' ) )
  endfunction

  function! CheckDiagUIRefreshedAfterLeavingInsertMode( id ) closure
    call WaitForAssert( {->
      \ assert_true(
        \ py3eval(
           \ 'len( ycm_state.CurrentBuffer()._diag_interface._diagnostics )'
      \ ) ) } )
    call WaitForAssert( {-> assert_true( len( sign_getplaced(
                           \ '%',
                           \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )
    call FeedAndCheckAgain( "A\<CR>", funcref( 'CheckNoPropsAfterNewLine' ) )
  endfunction

  function! CheckNoPropsAfterNewLine( id ) closure
    call WaitForAssert( {->
      \ assert_true(
        \ py3eval(
           \ 'len( ycm_state.CurrentBuffer()._diag_interface._diagnostics )'
      \ ) ) } )
    call WaitForAssert( {->
      \ assert_true( empty( YcmTest_VirtualDiagnosticProperties() ) )
      \ } )
  endfunction

  call FeedAndCheckMain(
      \ "imain(\<C-R>=YcmTest_RequestDiagnostics()\<CR>",
      \ funcref( 'CheckNoDiagUIAfterOpenParenthesis' ) )
endfunction

function! TearDown_Test_Disable_Diagnostics_Update_In_insert_Mode()
  call youcompleteme#test#setup#PopGlobal(
    \ 'ycm_update_diagnostics_in_insert_mode' )
endfunction

function! Test_Changing_Filetype_Refreshes_Diagnostics()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/diagnostics/foo.xml',
        \ { 'native_ft': 0 } )

  call assert_equal( 'xml', &filetype )
  call assert_false(
    \ pyxeval( 'ycm_state._buffers[' . bufnr( '%' ) . ']._async_diags' ) )
  call assert_true( empty( sign_getplaced(
                        \ '%',
                        \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) )
  setf typescript
  call assert_equal( 'typescript', &filetype )
  call assert_false(
    \ pyxeval( 'ycm_state._buffers[' . bufnr( '%' ) . ']._async_diags' ) )
  " Diagnostics are async, so wait for the assert to return 0 for a while.
  call WaitForAssert( {-> assert_equal( 1, len( sign_getplaced(
                        \ '%',
                        \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )
  call assert_equal( 1, len( sign_getplaced(
                        \ '%',
                        \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) )
  call assert_equal(
    \ 'YcmError',
    \ sign_getplaced(
      \ '%',
      \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ][ 0 ][ 'name' ] )
  call assert_false( empty( getloclist( 0 ) ) )
endfunction

function! Test_MessagePoll_After_LocationList()
  call youcompleteme#test#setup#OpenFile(
    \ '/test/testdata/diagnostics/foo.cpp', {} )

  setf cpp
  call assert_equal( 'cpp', &filetype )
  call WaitForAssert( {-> assert_equal( 2, len( sign_getplaced(
                        \ '%',
                        \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )
  call setline( 1, '' )
  " Wait for the parse request to be complete otherwise we won't send another
  " one when the TextChanged event fires
  call WaitFor( {-> pyxeval( 'ycm_state.FileParseRequestReady()' ) } )
  doautocmd TextChanged
  call WaitForAssert( {-> assert_true( empty( sign_getplaced(
                        \ '%',
                        \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )
  call assert_true( empty( getloclist( 0 ) ) )
endfunction

function! Test_MessagePoll_Multiple_Filetypes()
  call youcompleteme#test#setup#OpenFile(
        \ '/third_party/ycmd/ycmd/tests/java/testdata/simple_eclipse_project' .
        \ '/src/com/test/TestLauncher.java', {} )
  call WaitForAssert( {->
      \ assert_true( len( sign_getplaced(
                            \ '%',
                            \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )
  let java_signs = sign_getplaced(
                     \ '%',
                     \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ]
  silent vsplit testdata/diagnostics/foo.cpp
  " Make sure we've left the java buffer
  call assert_equal( java_signs,
      \ sign_getplaced( '#', { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] )
  " Clangd emits two diagnostics for foo.cpp.
  call WaitForAssert( {->
      \ assert_equal(
          \ 2,
          \ len( sign_getplaced(
              \ '%',
              \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )
  let cpp_signs = sign_getplaced( '%',
      \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ]
  call assert_false( java_signs == cpp_signs )
endfunction

function! Test_BufferWithoutAssociatedFile_HighlightingWorks()
  enew
  call setbufline( '%', 1, 'iiii' )
  setf c
  call WaitForAssert( {->
    \ assert_true( len( sign_getplaced(
                        \ '%',
                        \ { 'group': 'ycm_signs' } )[ 0 ][ 'signs' ] ) ) } )
  let expected_properties = [
    \ { 'column': 1,
    \   'type': 'YcmErrorProperty',
    \   'length': 0 },
    \ { 'column': 1,
    \   'type': 'YcmErrorProperty',
    \   'length': 0 },
    \ { 'column': 1,
    \   'type': 'YcmErrorProperty',
    \   'length': 4 },
    \ { 'column': 1,
    \   'type': 'YcmErrorProperty',
    \   'length': 4 },
    \ ]

  call assert_equal(
        \ expected_properties,
        \ YcmTest_DiagnosticHighlights( 1 ) )
endfunction

function! Test_ShowDetailedDiagnostic_CmdLine()
  call youcompleteme#test#setup#OpenFile(
    \ '/test/testdata/cpp/fixit.cpp', {} )

  call cursor( [ 3, 1 ] )
  redir => output
  YcmShowDetailedDiagnostic
  redir END

  call assert_equal(
        \ "Format specifies type 'char *' but the argument has type 'int' "
        \ . '(fix available) [-Wformat]',
        \ trim( output ) )

  %bwipe!
endfunction

function! Test_ShowDetailedDiagnostic_PopupAtCursor()
  call youcompleteme#test#setup#OpenFile(
    \ '/test/testdata/cpp/fixit.cpp', {} )

  call cursor( [ 3, 1 ] )
  YcmShowDetailedDiagnostic popup

  let id = YcmTest_DetailedDiagnosticWindow()
  call YcmTest_CheckDetailedDiagnosticWindow( id )
  call assert_equal(
        \ [
        \   "Format specifies type 'char *' but the argument has type 'int' "
        \   . '(fix available) [-Wformat]',
        \ ],
        \ getbufline( winbufnr(id), 1, '$' ) )

  " From vim's test_popupwin.vim
  " trigger the check for last_cursormoved by going into insert mode
  call YcmTest_SetCharAvailOverride( 1 )
  call feedkeys( "ji\<Esc>", 'xt' )
  call YcmTest_ProcessCursorMoved()
  call assert_false( YcmTest_DetailedDiagnosticWindowExists( id ) )
  call YcmTest_SetCharAvailOverride( 0 )

  %bwipe!
endfunction

function! Test_ShowDetailedDiagnostic_Popup_WithCharacters()
  let f = tempname() . '.cc'
  execut 'edit' f
  call setline( 1, [
        \   'struct Foo {};',
        \   'template<char...> Foo operator""_foo() { return {}; }',
        \   'int main() {',
        \       '""_foo',
        \   '}',
        \ ] )
  call youcompleteme#test#setup#WaitForInitialParse( {} )

  call WaitForAssert( {->
    \ assert_true(
      \ py3eval(
         \ 'len( ycm_state.CurrentBuffer()._diag_interface._diagnostics )'
    \ ) ) } )

  call cursor( [ 4, 1 ] )
  YcmShowDetailedDiagnostic popup

  let id = YcmTest_DetailedDiagnosticWindow()
  call YcmTest_CheckDetailedDiagnosticWindow( id )
  call assert_match(
        \ "^No matching literal operator for call to 'operator\"\"_foo'.*",
        \ getbufline( winbufnr(id), 1, '$' )[ 0 ] )

  " From vim's test_popupwin.vim
  " trigger the check for last_cursormoved by going into insert mode
  call YcmTest_SetCharAvailOverride( 1 )
  call feedkeys( "ji\<Esc>", 'xt' )
  call YcmTest_ProcessCursorMoved()
  call assert_false( YcmTest_DetailedDiagnosticWindowExists( id ) )
  call YcmTest_SetCharAvailOverride( 0 )

  %bwipe!
endfunction

function! Test_ShowDetailedDiagnostic_Popup_MultilineDiagNotFromStartOfLine()
  let f = tempname() . '.cc'
  execut 'edit' f
  call setline( 1, [
        \   'int main () {',
        \   '  int a \',
        \   '=\',
        \   '=',
        \   '3;',
        \   '}',
        \ ] )
  call youcompleteme#test#setup#WaitForInitialParse( {} )

  call WaitForAssert( {->
    \ assert_true(
      \ py3eval(
         \ 'len( ycm_state.CurrentBuffer()._diag_interface._diagnostics )'
    \ ) ) } )

  call YcmTest_SetCharAvailOverride( 1 )

  for cursor_pos in [ [ 2, 9 ], [ 3, 1], [ 4, 1 ] ]
    call cursor( cursor_pos )
    YcmShowDetailedDiagnostic popup

    let id = YcmTest_DetailedDiagnosticWindow()
    call YcmTest_CheckDetailedDiagnosticWindow( id )
    call assert_match(
          \ "^Invalid '==' at end of declaration; did you mean '='?.*",
          \ getbufline( winbufnr(id), 1, '$' )[ 0 ] )
    " From vim's test_popupwin.vim
    " trigger the check for last_cursormoved by going into insert mode
    call feedkeys( "ji\<Esc>", 'xt' )
    call YcmTest_ProcessCursorMoved()
    call assert_false( YcmTest_DetailedDiagnosticWindowExists( id ) )
  endfor

  call YcmTest_SetCharAvailOverride( 0 )

  %bwipe!
endfunction

function! Test_ShowDetailedDiagnostic_Popup_MultilineDiagFromStartOfLine()
  let f = tempname() . '.cc'
  execut 'edit' f
  call setline( 1, [
        \   'int main () {',
        \   'const int &&',
        \   '        /* */',
        \   '    rd = 1;',
        \   'rd = 4;',
        \   '}',
        \ ] )
  call youcompleteme#test#setup#WaitForInitialParse( {} )

  call WaitForAssert( {->
    \ assert_true(
      \ py3eval(
         \ 'len( ycm_state.CurrentBuffer()._diag_interface._diagnostics )'
    \ ) ) } )

  call YcmTest_SetCharAvailOverride( 1 )

  for cursor_pos in [ [ 2, 1 ], [ 3, 9 ], [ 4, 5 ] ]
    call cursor( cursor_pos )
    YcmShowDetailedDiagnostic popup

    let id = YcmTest_DetailedDiagnosticWindow()
    call YcmTest_CheckDetailedDiagnosticWindow( id )
    call assert_match(
          \ "^Variable 'rd' declared const here.*",
          \ getbufline( winbufnr(id), 1, '$' )[ 0 ] )
    " From vim's test_popupwin.vim
    " trigger the check for last_cursormoved by going into insert mode
    call feedkeys( "ji\<Esc>ki\<Esc>", 'xt' )
    call YcmTest_ProcessCursorMoved()
    call assert_false( YcmTest_DetailedDiagnosticWindowExists( id ) )
  endfor

  call YcmTest_SetCharAvailOverride( 0 )

  %bwipe!
endfunction

function! Test_ShowDetailedDiagnostic_Popup_MultipleDiagsPerLine_SameMessage()
  let f = tempname() . '.cc'
  execut 'edit' f
  call setline( 1, [ 'void f(){a;a;}', ] )
  call youcompleteme#test#setup#WaitForInitialParse( {} )

  call WaitForAssert( {->
    \ assert_true(
      \ py3eval(
        \ 'len( ycm_state.CurrentBuffer()._diag_interface._diagnostics )'
    \ ) ) } )

  YcmShowDetailedDiagnostic popup
  let window_id = YcmTest_DetailedDiagnosticWindow()
  call YcmTest_CloseDetailedDiagnosticWindow( window_id )
endfunction
