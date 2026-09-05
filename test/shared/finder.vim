function! SetUp()
  let g:ycm_use_clangd = 1
  let g:ycm_enable_semantic_highlighting = 1
  call youcompleteme#test#setup#SetUp()
  nmap <leader><leader>w <Plug>(YCMFindSymbolInWorkspace)
  nmap <leader><leader>d <Plug>(YCMFindSymbolInDocument)
endfunction

function! TearDown()
endfunction

function! s:WaitForPopupContents( id, pattern )
  call WaitForAssert( { ->
        \ assert_equal(
        \   1,
        \   YcmTest_FinderWindowIsVisible( a:id ) ) } )

  call WaitForAssert( { ->
        \ assert_match(
        \   a:pattern,
        \   get( YcmTest_FinderWindowLines( a:id ), 0, '' ) ) },
        \ 10000 )
endfunction

function! Test_WorkspaceSymbol_Basic()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  let popup_id = -1
  let selected_position = []

  function! PutQuery( ... )
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    call FeedAndCheckAgain( 'xthisisathing', funcref( 'SelectItem' ) )
  endfunction

  function SelectItem( ... ) closure
    let id = youcompleteme#finder#GetState().id

    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xthisisathing ',
          \ YcmTest_FinderWindowTitle( id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( id ) ) } )

    call s:WaitForPopupContents(
          \ id,
          \ '^Field: x_this_is_a_thing\s\+.*finder_test\.cc:5 cpp$' )

    let selected = youcompleteme#finder#GetState().results[
          \ youcompleteme#finder#GetState().selected ]
    let selected_position = [
          \ 0,
          \ str2nr( selected.line_num ),
          \ str2nr( selected.column_num ),
          \ 0
          \ ]
    call feedkeys( "\<CR>" )
  endfunction

  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInWorkspace)
  call FeedAndCheckMain( '\\w', funcref( 'PutQuery' ) )

  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( b, bufnr() )
  call assert_equal( [ 0, 5, 7, 0 ], selected_position )
  call WaitForAssert(
        \ { -> assert_equal( selected_position, getpos( '.' ) ) } )

  delfunct PutQuery
  delfunct SelectItem
  silent %bwipe!
endfunction

function! Test_DocumentSymbols_Basic()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  let popup_id = -1

  function! PutQuery( ... )
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    call FeedAndCheckAgain( 'xthisisathing', funcref( 'SelectItem' ) )
  endfunction

  function SelectItem( ... )
    let id = youcompleteme#finder#GetState().id

    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xthisisathing ',
          \ YcmTest_FinderWindowTitle( id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( id ) ) } )

    call s:WaitForPopupContents(
          \ id,
          \ '^Field: x_this_is_a_thing\s\+.*finder_test\.cc:5$' )

    call feedkeys( "\<CR>" )
  endfunction

  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInDocument)
  call FeedAndCheckMain( '\\d', funcref( 'PutQuery' ) )

  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( b, bufnr() )
  " NOTE: cland returns the position of the decl here not the identifier. This
  " is why it's position 3 not 7 as in the Test_WorkspaceSymbol_Basic
  call WaitForAssert(
        \ { -> assert_equal( [ 0, 5, 3, 0 ], getpos( '.' ) ) } )

  delfunct PutQuery
  delfunct SelectItem
  silent %bwipe!
endfunction

function! Test_Cancel_DocumentSymbol()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  " Jump to a different position so that we can ensure we return to the same
  " place
  normal! G
  let p = getpos( '.' )

  let popup_id = -1

  function! PutQuery( ... )
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    call FeedAndCheckAgain( 'xthisisathing', funcref( 'SelectItem' ) )
  endfunction

  function SelectItem( ... )
    let id = youcompleteme#finder#GetState().id

    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xthisisathing ',
          \ YcmTest_FinderWindowTitle( id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( id ) ) } )

    " Cancel - this should stopinsert
    call feedkeys( "\<C-c>" )
  endfunction

  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInDocument)
  call FeedAndCheckMain( '\\d', funcref( 'PutQuery' ) )

  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( b, bufnr() )

  " Retuned to just where we started
  call assert_equal( p, getpos( '.' ) )

  delfunct PutQuery
  delfunct SelectItem
  silent %bwipe!
endfunction

function! Test_EmptySearch()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  let popup_id = -1

  function! PutQuery( ... )
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    call FeedAndCheckAgain( 'xnothingshouldmatchthisx',
                          \ funcref( 'SelectNothing' ) )
  endfunction

  function SelectNothing( ... )
    let id = youcompleteme#finder#GetState().id

    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xnothingshouldmatchthisx ',
          \ YcmTest_FinderWindowTitle( id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( id ) ) } )

    call s:WaitForPopupContents( id, '^No results$' )
    call FeedAndCheckAgain( "\<CR>xnotarealthingx",
                          \ funcref( 'ChangeSearch' ) )
  endfunction

  function ChangeSearch( ... )
    let id = youcompleteme#finder#GetState().id

    " Hitting enter with nothing to select clears the prompt, because prompt
    " buffer
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xnotarealthingx ',
          \ YcmTest_FinderWindowTitle( id )  ) },
          \ 10000 )
    call s:WaitForPopupContents( id, '^No results$' )

    call assert_equal( -1, youcompleteme#finder#GetState().selected )

    call FeedAndCheckAgain( "\<C-u>xtiat", funcref( 'TestUpDownSelect' ) )
  endfunction

  let popup_id = -1
  function TestUpDownSelect( ... ) closure
    let popup_id = youcompleteme#finder#GetState().id

    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xtiat ',
          \ YcmTest_FinderWindowTitle( popup_id )  ) },
          \ 10000 )
    call WaitForAssert( { ->
          \ assert_equal( 3, YcmTest_FinderWindowLineCount( popup_id ) ) } )

    " Check down movement
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<C-j>", 'xt' )
    call assert_equal( 1, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_that_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<Down>", 'xt' )
    call assert_equal( 2, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_topic_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<Tab>", 'xt' )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<C-n>", 'xt' )
    call assert_equal( 1, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_that_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    " Check up movement and wrapping
    call feedkeys( "\<C-k>", 'xt' )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<Up>", 'xt' )
    call assert_equal( 2, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_topic_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<S-Tab>", 'xt' )
    call assert_equal( 1, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_that_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<C-p>", 'xt' )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<Tab>", 'xt' )
    call assert_equal( 1, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_that_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<Home>", 'xt' )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<End>", 'xt' )
    call assert_equal( 2, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_topic_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<End>", 'xt' )
    call assert_equal( 2, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_topic_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<PageUp>", 'xt' )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<PageDown>", 'xt' )
    call assert_equal( 2, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_topic_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<CR>" )
  endfunction

  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInWorkspace)
  call FeedAndCheckMain( '\\w', funcref( 'PutQuery' ) )

  call WaitForAssert( { ->
        \ assert_false( YcmTest_FinderWindowIsVisible( popup_id ) ) } )
  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( b, bufnr() )
  call WaitForAssert(
        \ { -> assert_equal( [ 0, 5, 53, 0 ], getpos( '.' ) ) } )

  " We pop up a notification with some text in it
  call WaitForAssert( { ->
        \ assert_equal( 1, len( YcmTest_FinderNotifications() ) ) } )
  let notification_id = YcmTest_FinderNotifications()[ 0 ]
  call assert_equal( [ 'Added 3 entries to quickfix list.' ],
                   \ YcmTest_FinderWindowLines( notification_id ) )
  " Wait for the notification to clear
  call WaitForAssert(
        \ { -> assert_false(
        \   YcmTest_FinderWindowIsVisible( notification_id ) ) },
        \ 10000 )

  delfunct PutQuery
  delfunct SelectNothing
  delfunct ChangeSearch
  delfunct TestUpDownSelect
  silent %bwipe!
endfunction

function! s:LeaveFinderPrompt()
  call feedkeys( "\<C-\>\<C-N>\<C-w>w" )
endfunction


function! s:TestLeaveFinderPrompt( InputAction )
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  " Jump to a different position so that we can ensure we return to the same
  " place
  normal! G
  let p = getpos( '.' )

  let popup_id = -1

  function! PutQuery( ... ) closure
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    call call( a:InputAction, [] )
  endfunction

  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInWorkspace)
  call FeedAndCheckMain( '\\w', funcref( 'PutQuery' ) )

  call WaitForAssert( { ->
        \ assert_equal( -1, youcompleteme#finder#GetState().id ) } )
  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( b, bufnr() )

  " Retuned to just where we started
  call assert_equal( p, getpos( '.' ) )

  " No notifiaction
  call assert_equal( [], YcmTest_FinderNotifications() )

  delfunct PutQuery
  silent %bwipe!
endfunction


function! Test_LeaveWindow_CancelSearch()
  call s:TestLeaveFinderPrompt( function( 's:LeaveFinderPrompt' ) )
endfunction


function! YcmTest_ClosePromptWindow_CancelSearch( InputAction )
  call s:TestLeaveFinderPrompt( a:InputAction )
endfunction


function! SetUp_Test_NoFileType_NoCompletionIn_PromptBuffer()
  call youcompleteme#test#setup#PushGlobal( 'ycm_filetype_whitelist', {
        \ '*': 1,
        \ 'ycm_nofiletype': 1
        \ } )
endfunction

function! TearDown_Test_NoFileType_NoCompletionIn_PromptBuffer()
  call youcompleteme#test#setup#PopGlobal( 'ycm_filetype_whitelist' )
endfunction

function! Test_NoFileType_NoCompletionIn_PromptBuffer()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )

  call YcmTest_SetCharAvailOverride( v:true )

  new
  call feedkeys(
        \ 'iThis is some text and so is xthisisathing x_this_is_a_thing',
        \ 'xt' )
  wincmd w

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  let popup_id = -1

  function! PutQuery( ... )
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    call FeedAndCheckAgain( 'xthisisathing', funcref( 'CheckNoPopup' ) )
  endfunction

  function! CheckNoPopup( ... )
    let id = youcompleteme#finder#GetState().id

    call WaitForAssert( { ->
            \ assert_equal( ' [X] Search for symbol: xthisisathing ',
            \ YcmTest_FinderWindowTitle( id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( id ) ) } )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call s:WaitForPopupContents(
          \ id,
          \ '^Field: x_this_is_a_thing\s\+.*finder_test\.cc:5 cpp$' )

    " Check there is no PUM - we disable completion in the prompt buffer
    call assert_false( pumvisible() )

    call feedkeys( "\<CR>" )
  endfunction

  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInWorkspace)
  call FeedAndCheckMain( '\\w', funcref( 'PutQuery' ) )

  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( b, bufnr() )
  call WaitForAssert(
        \ { -> assert_equal( [ 0, 5, 7, 0 ], getpos( '.' ) ) } )

  call YcmTest_SetCharAvailOverride( v:false )
  silent %bwipe!
  delfunct! PutQuery
  delfunct! CheckNoPopup
endfunction

function! Test_MultipleFileTypes()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )
  split
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )
  wincmd w

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  function! PutQuery( ... )
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    let popup_id = youcompleteme#finder#GetState().id
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: thiswillnotmatchanything ',
          \ YcmTest_FinderWindowTitle( popup_id )  ) },
          \ 10000 )


    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    let id = youcompleteme#finder#GetState().id
    call assert_equal(
          \ 'No results',
          \ YcmTest_FinderWindowLines( id )[ -1 ] )
    call FeedAndCheckAgain( "\<C-u>xthisisathing", funcref( 'CheckCpp' ) )
  endfunction

  function! CheckCpp( ... )
    let popup_id = youcompleteme#finder#GetState().id

    " Python can be _really_ slow
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xthisisathing ',
          \ YcmTest_FinderWindowTitle( popup_id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( popup_id ) ) } )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call FeedAndCheckAgain(
          \ "\<C-u>Really_Long_Method",
          \ funcref( 'CheckPython' ) )
  endfunction

  function! CheckPython( ... )
    let popup_id = youcompleteme#finder#GetState().id

    " Python can be _really_ slow
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: Really_Long_Method ',
          \ YcmTest_FinderWindowTitle( popup_id ) ) },
          \ 20000 )

    call WaitForAssert( { ->
          \ assert_equal( 2, YcmTest_FinderWindowLineCount( popup_id ) ) },
                      \ 20000 )
    call WaitForAssert( { ->
          \   assert_equal( 0, youcompleteme#finder#GetState().selected )
          \ },
          \ 20000 )
    call assert_equal( 'def Really_Long_Method',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].description )

    " Toggle single-filetype mode
    call FeedAndCheckAgain( "\<C-f>", funcref( 'CheckCppAgain' ) )
  endfunction

  function! CheckCppAgain( ... )
    let popup_id = youcompleteme#finder#GetState().id

    " Python can be _really_ slow
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: Really_Long_Method ',
          \ YcmTest_FinderWindowTitle( popup_id ) ) },
          \ 20000 )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    let id = youcompleteme#finder#GetState().id
    call assert_equal(
          \ 'No results',
          \ YcmTest_FinderWindowLines( id )[ -1 ] )

    " And back to multiple filetypes
    call FeedAndCheckAgain( "\<C-f>", funcref( 'CheckPythonAgain' ) )
  endfunction

  function! CheckPythonAgain( ... )
    let popup_id = youcompleteme#finder#GetState().id

    " Python can be _really_ slow
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: Really_Long_Method ',
          \ YcmTest_FinderWindowTitle( popup_id ) ) },
          \ 20000 )

    call WaitForAssert( { ->
          \ assert_equal( 2, YcmTest_FinderWindowLineCount( popup_id ) ) },
                      \ 20000 )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'def Really_Long_Method',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].description )

    call feedkeys( "\<C-c>" )
  endfunction


  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInWorkspace)
  call FeedAndCheckMain( '\\wthiswillnotmatchanything', funcref( 'PutQuery' ) )

  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( b, bufnr() )
endfunction

function! Test_MultipleFileTypes_CurrentNotSemantic()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )
  split
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )
  split
  " Current buffer is a ycm_nofiletype, which ycm is blacklisted in
  " but otherwise we behave the same as before with the exception that we open
  " the python file in the current window

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  function! PutQuery( ... )
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    let popup_id = youcompleteme#finder#GetState().id
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: thiswillnotmatchanything ',
          \ YcmTest_FinderWindowTitle( popup_id )  ) },
          \ 10000 )


    let id = youcompleteme#finder#GetState().id
    call assert_equal(
          \ 'No results',
          \ YcmTest_FinderWindowLines( id )[ -1 ] )
    call FeedAndCheckAgain( "\<C-u>xthisisathing", funcref( 'CheckCpp' ) )
  endfunction

  function! CheckCpp( ... )
    let popup_id = youcompleteme#finder#GetState().id

    " Python can be _really_ slow
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xthisisathing ',
          \ YcmTest_FinderWindowTitle( popup_id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( popup_id ) ) } )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call FeedAndCheckAgain(
          \ "\<C-u>Really_Long_Method",
          \ funcref( 'CheckPython' ) )
  endfunction

  function! CheckPython( ... )
    let popup_id = youcompleteme#finder#GetState().id

    " Python can be _really_ slow
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: Really_Long_Method ',
          \ YcmTest_FinderWindowTitle( popup_id ) ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 2, YcmTest_FinderWindowLineCount( popup_id ) ) },
                      \ 10000 )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'def Really_Long_Method',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].description )

    call feedkeys( "\<CR>")
  endfunction


  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInWorkspace)
  call FeedAndCheckMain( '\\wthiswillnotmatchanything', funcref( 'PutQuery' ) )

  " We pop up a notification with some text in it
  call WaitForAssert( { ->
        \ assert_equal( 1, len( YcmTest_FinderNotifications() ) ) } )
  let notification_id = YcmTest_FinderNotifications()[ 0 ]
  call assert_equal( [ 'Added 2 entries to quickfix list.' ],
                   \ YcmTest_FinderWindowLines( notification_id ) )
  " Wait for the notification to clear
  call WaitForAssert(
        \ { -> assert_false(
        \   YcmTest_FinderWindowIsVisible( notification_id ) ) },
        \ 10000 )

  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( bufnr( 'doc.py' ), bufnr() )
  call assert_equal( [ 0, 16, 5, 0 ], getpos( '.' ) )
endfunction

function! Test_WorkspaceSymbol_NormalModeChange()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/finder_test.cc', {} )

  let original_win = winnr()
  let b = bufnr()
  let l = winlayout()

  let popup_id = -1

  function! PutQuery( ... )
    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call WaitForAssert( { -> assert_true(
          \ youcompleteme#finder#GetState().id != -1 ) } )

    let popup_id = youcompleteme#finder#GetState().id
    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: thiswillnotmatchanything ',
          \ YcmTest_FinderWindowTitle( popup_id )  ) },
          \ 10000 )

    let id = youcompleteme#finder#GetState().id
    call assert_equal(
          \ 'No results',
          \ YcmTest_FinderWindowLines( id )[ -1 ] )
    call FeedAndCheckAgain( "\<C-u>xthisisathing", funcref( 'ChangeQuery' ) )
  endfunction

  function ChangeQuery( ... )
    let id = youcompleteme#finder#GetState().id

    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: xthisisathing ',
          \ YcmTest_FinderWindowTitle( id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( id ) ) } )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_this_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    " Wait for the current buffer to be a prompt buffer
    call WaitForAssert( { -> assert_equal( 'prompt', &buftype ) } )
    call WaitForAssert( { -> assert_equal( 'i', mode() ) } )

    call FeedAndCheckAgain( "\<Esc>bcwthatisathing",
                          \ funcref( 'SelectNewItem' ) )
  endfunction

  function SelectNewItem( ... )
    let id = youcompleteme#finder#GetState().id

    call WaitForAssert( { ->
          \ assert_equal( ' [X] Search for symbol: thatisathing ',
          \ YcmTest_FinderWindowTitle( id )  ) },
          \ 10000 )

    call WaitForAssert( { ->
          \ assert_equal( 1, YcmTest_FinderWindowLineCount( id ) ) } )
    call assert_equal( 0, youcompleteme#finder#GetState().selected )
    call assert_equal( 'x_that_is_a_thing',
          \ youcompleteme#finder#GetState().results[
          \   youcompleteme#finder#GetState().selected ].extra_data.name )

    call feedkeys( "\<CR>" )
  endfunction

  " <Leader> is \ - this calls <Plug>(YCMFindSymbolInWorkspace)
  call FeedAndCheckMain( '\\wthiswillnotmatchanything', funcref( 'PutQuery' ) )

  call WaitForAssert( { -> assert_equal( l, winlayout() ) } )
  call WaitForAssert( { -> assert_equal( original_win, winnr() ) } )
  call assert_equal( b, bufnr() )
  call WaitForAssert(
        \ { -> assert_equal( [ 0, 5, 30, 0 ], getpos( '.' ) ) } )

  delfunct PutQuery
  delfunct SelectNewItem
  delfunct ChangeQuery
  silent %bwipe!
endfunction


function! s:IgnoreFinderClose( window_id, selected ) abort
endfunction


function! Test_FinderUI_ContentsAndHighlights()
  let window_id = youcompleteme#finder#ui#Create(
        \ 'No results',
        \ function( 's:IgnoreFinderClose' ) )

  try
    call youcompleteme#finder#ui#SetContents(
          \ window_id,
          \ [
          \   {
          \     'text': 'one two',
          \     'highlights': [
          \       {
          \         'column': 1,
          \         'length': 3,
          \         'group': 'YCM-symbol-Field',
          \       },
          \       {
          \         'column': 5,
          \         'length': 3,
          \         'group': 'YCM-symbol-file',
          \       },
          \     ],
          \   },
          \   {
          \     'text': 'three',
          \     'highlights': [
          \       {
          \         'column': 1,
          \         'length': 5,
          \         'group': 'YCM-symbol-Normal',
          \       },
          \     ],
          \   },
          \ ] )

    call assert_equal(
          \ [ 'one two', 'three' ],
          \ YcmTest_FinderWindowLines( window_id ) )
    call assert_equal(
          \ [
          \   {
          \     'line': 1,
          \     'column': 1,
          \     'length': 3,
          \     'group': 'YCM-symbol-Field',
          \   },
          \   {
          \     'line': 1,
          \     'column': 5,
          \     'length': 3,
          \     'group': 'YCM-symbol-file',
          \   },
          \   {
          \     'line': 2,
          \     'column': 1,
          \     'length': 5,
          \     'group': 'YCM-symbol-Normal',
          \   },
          \ ],
          \ YcmTest_FinderWindowHighlights( window_id ) )

    call youcompleteme#finder#ui#SetContents(
          \ window_id,
          \ 'No results' )
    call assert_equal(
          \ [],
          \ YcmTest_FinderWindowHighlights( window_id ) )
  finally
    call youcompleteme#finder#ui#Close( window_id, -1 )
    call WaitForAssert( { ->
          \ assert_false(
          \   YcmTest_FinderWindowIsVisible( window_id ) ) } )
  endtry
endfunction


function! Test_FinderUI_SelectionAndScrolling()
  let window_id = youcompleteme#finder#ui#Create(
        \ 'No results',
        \ function( 's:IgnoreFinderClose' ) )

  try
    let line_count =
          \ youcompleteme#finder#ui#GetHeight( window_id ) + 5
    let contents = []
    for line_number in range( 1, line_count )
      call add(
            \ contents,
            \ {
            \   'text': 'Result ' . line_number,
            \   'highlights': [],
            \ } )
    endfor
    call youcompleteme#finder#ui#SetContents(
          \ window_id,
          \ contents )

    call youcompleteme#finder#ui#SetSelected( window_id, 0 )
    call assert_equal(
          \ 1,
          \ YcmTest_FinderWindowSelectedLine( window_id ) )
    call assert_true( getwinvar( window_id, '&cursorline' ) )

    call youcompleteme#finder#ui#SetSelected(
          \ window_id,
          \ line_count - 1 )
    call assert_equal(
          \ line_count,
          \ YcmTest_FinderWindowSelectedLine( window_id ) )
    call assert_true(
          \ YcmTest_FinderWindowFirstVisibleLine( window_id ) > 1 )

    call youcompleteme#finder#ui#SetSelected( window_id, 0 )
    call assert_equal(
          \ 1,
          \ YcmTest_FinderWindowFirstVisibleLine( window_id ) )

    call youcompleteme#finder#ui#SetSelected( window_id, -1 )
    call assert_false( getwinvar( window_id, '&cursorline' ) )
  finally
    call youcompleteme#finder#ui#Close( window_id, -1 )
    call WaitForAssert( { ->
          \ assert_false(
          \   YcmTest_FinderWindowIsVisible( window_id ) ) } )
  endtry
endfunction
