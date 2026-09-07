scriptencoding utf-8

" Shared completion-info integration tests.
" Editor-specific adapters provide:
"
"   YcmTest_CompletionInfoSupported()
"   YcmTest_WaitForCompletionInfoHidden()
"   YcmTest_WaitForCompletionInfoVisible()
"   YcmTest_CompletionInfoLines()
"   YcmTest_PrepareForCompletion()
"   YcmTest_FinishCompletion()

function! Test_ResolveCompletion_OnChange()
  call SkipIf(
        \ !YcmTest_CompletionInfoSupported(), 'no completion info window' )

  " Only the java completer actually uses the completion resolve
  call youcompleteme#test#setup#OpenFile(
        \ '/third_party/ycmd/ycmd/tests/java/testdata/simple_eclipse_project' .
        \ '/src/com/test/TestWithDocumentation.java', { 'delay': 15 } )

  call setpos( '.', [ 0, 6, 21 ] )
  " Required to trigger TextChangedI
  " https://github.com/vim/vim/issues/4665#event-2480928194
  call YcmTest_PrepareForCompletion()

  function! Check1( id )
    call WaitForCompletion()
    call YcmTest_WaitForCompletionInfoHidden()
    call FeedAndCheckAgain( "\<Tab>", funcref( 'Check2', [ 0 ] ) )
  endfunction

  let found_getAString = 0

  function! Check2( counter, id ) closure
    call WaitForCompletion()
    call YcmTest_WaitForCompletionInfoVisible()

    let compl = complete_info()
    let selected = compl.items[ compl.selected ]

    " All items should be resolved
    " NOTE: Even after resolving the item still has this as there's no way to
    " update the user data of the item at this point (need a vim change to do
    " that)
    call assert_true( has_key( json_decode( selected.user_data ),
          \ 'resolve' ) )

    if selected.word ==# 'getAString'
      " It's line 5 because we truncated the signature to fit it in
      call WaitForAssert( { ->
            \ assert_equal( [ 'MethodsWithDocumentation.getAString() : String',
                            \ '',
                            \ 'getAString() : String',
                            \ '',
                            \ 'Single line description.',
                            \ ],
            \               YcmTest_CompletionInfoLines( 1, 5 ) )
            \ } )
      let found_getAString += 1
    endif

    if a:counter < 10
      call FeedAndCheckAgain( "\<Tab>", funcref( 'Check2', [ a:counter + 1 ] ) )
    else
      call feedkeys( "\<Esc>" )
    endif
  endfunction

  call FeedAndCheckMain( 'cw', funcref( 'Check1' ) )

  call assert_false( pumvisible(), 'pumvisible()' )
  call assert_equal( 1, found_getAString )

  call YcmTest_FinishCompletion()
endfunction

function! Test_Resolve_FixIt()
  call SkipIf(
        \ !YcmTest_CompletionInfoSupported(), 'no completion info window' )

  " Only the java completer actually uses the completion resolve
  call youcompleteme#test#setup#OpenFile(
        \ '/third_party/ycmd/ycmd/tests/java/testdata/simple_eclipse_project' .
        \ '/src/com/test/TestWithDocumentation.java', { 'delay': 15 } )

  " Required to trigger TextChangedI
  " https://github.com/vim/vim/issues/4665#event-2480928194
  call YcmTest_PrepareForCompletion()

  function! Check1( id )
    call WaitForCompletion()
    call CheckCurrentLine( '    Tes' )
    call CheckCompletionItemsHasItems( [ 'Test - com.youcompleteme' ] )
    let tabs = IndexOfCompletionItemInList( 'Test - com.youcompleteme' ) + 1
    let tabs = repeat( "\<Tab>", tabs )
    call FeedAndCheckAgain( tabs, funcref( 'Check2' ) )
  endfunction

  function! Check2( id )
    call WaitForCompletion()
    call CheckCompletionItemsHasItems( [ 'Test - com.youcompleteme' ] )
    call CheckCurrentLine( '    Test' )
    call FeedAndCheckAgain( "\<C-y>", funcref( 'Check3' ) )
  endfunction

  function! Check3( id )
    call WaitForAssert( {-> assert_false( pumvisible(), 'pumvisible()' ) } )
    call CheckCurrentLine( '    Test' )
    call assert_equal( 'import com.youcompleteme.Test;', getline( 3 ) )
    call feedkeys( "\<Esc>" )
  endfunction

  call setpos( '.', [ 0, 7, 1 ] )
  call FeedAndCheckMain( "oTes\<C-space>", funcref( 'Check1' ) )

  call YcmTest_FinishCompletion()
endfunction

function! Test_DontResolveCompletion_AlreadyResolved()
  call SkipIf(
        \ !YcmTest_CompletionInfoSupported(), 'no completion info window' )

  " Only the java completer actually uses the completion resolve
  call youcompleteme#test#setup#OpenFile(
        \ '/third_party/ycmd/ycmd/tests/java/testdata/simple_eclipse_project' .
        \ '/src/com/test/TestWithDocumentation.java', { 'delay': 15 } )

  call setpos( '.', [ 0, 7, 12 ] )
  " Required to trigger TextChangedI
  " https://github.com/vim/vim/issues/4665#event-2480928194
  call YcmTest_PrepareForCompletion()

  function! Check1( id )
    call WaitForCompletion()
    call CheckCompletionItemsContainsExactly( [ 'hashCode' ], 'word' )
    call YcmTest_WaitForCompletionInfoHidden()
    call assert_equal( -1, complete_info().selected )

    let compl = complete_info()
    let hashCode = compl.items[ 0 ]
    call assert_equal( 1, len( compl.items ) )
    call assert_equal( 'hashCode', hashCode.word )
    call assert_false( has_key( json_decode( hashCode.user_data ),
          \ 'resolve' ) )

    call FeedAndCheckAgain( "\<Tab>", funcref( 'Check2' ) )
  endfunction

  function! Check2( id )
    call WaitForCompletion()
    call YcmTest_WaitForCompletionInfoVisible()

    let compl = complete_info()
    let selected = compl.items[ 0 ]
    call assert_equal( 1, len( compl.items ) )
    call assert_equal( 'hashCode', selected.word )
    call assert_false( has_key( json_decode( selected.user_data ),
          \ 'resolve' ) )
    call feedkeys( "\<Esc>" )
  endfunction

  call FeedAndCheckMain( 'C', funcref( 'Check1' ) )

  call assert_false( pumvisible(), 'pumvisible()' )

  call YcmTest_FinishCompletion()
endfunction

function! Test_SwitchingToSemanticCompletionAfterSelectingIdentifierCandidate()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/cpp/identifier_semantic_switch.cpp', {} )
  call setpos( '.', [ 0, 3, 0 ] )
  call YcmTest_PrepareForCompletion()

  function! Check1( id )
    call WaitForCompletion()
    call CheckCompletionItemsContainsExactly( [ 'ZbCdE' ], 'word' )
    let compl = complete_info()
    call assert_equal( -1, compl.selected )
    call assert_equal( 1, len( compl.items ) )
    let ZbCdE = compl.items[ 0 ]
    call assert_equal( 'ZbCdE', ZbCdE.word )
    call assert_equal( '[ID]', ZbCdE.menu )
    call assert_equal( '', ZbCdE.kind )
    call FeedAndCheckAgain( "\<Tab>", funcref( 'Check2' ) )
  endfunction

  function! Check2( id )
    call WaitForCompletion()
    call assert_match( 'ZbCdE', getline( '.' ) )
    call FeedAndCheckAgain( "\<C-Space>", funcref( 'Check3' ) )
  endfunction

  function! Check3( id )
    call WaitForCompletion()
    call CheckCompletionItemsContainsExactly( [ 'ZbCdE' ], 'word' )
    let compl = complete_info()
    call assert_equal( -1, compl.selected )
    call assert_match( 'ZbCdE', getline( '.' ) )
    call assert_equal( 1, len( compl.items ) )
    let ZbCdE = compl.items[ 0 ]
    call assert_equal( 'ZbCdE', ZbCdE.word )
    call assert_equal( 'void', ZbCdE.menu )
    call assert_equal( 'f', ZbCdE.kind )
    call feedkeys( "\<Esc>" )
  endfunction


  call FeedAndCheckMain( 'ZCE', funcref( 'Check1' ) )
  call assert_false( pumvisible(), 'pumvisible()' )
  call YcmTest_FinishCompletion()
endfunction
