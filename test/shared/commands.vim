" Shared command integration-test setup and assertions.
" Editor-specific adapters provide:
"
"   YcmTest_FeedInput( keys )

function! SetUp()
  let g:ycm_use_clangd = 1
  let g:ycm_keep_logfiles = 1
  let g:ycm_log_level = 'DEBUG'
  call youcompleteme#test#setup#SetUp()
endfunction

function! Test_ToggleLogs()
  let log_files = pyxeval( 'ycm_state.GetLogfiles()' )
  let bcount = len( getbufinfo() )

  " default - show
  silent exe 'YcmToggleLogs' keys( log_files )[ 0 ]
  call assert_equal( bcount + 1, len( getbufinfo() ) )
  let win = getbufinfo( keys( log_files )[ 0 ] )[ 0 ].windows[ 0 ]
  call assert_equal( &previewheight, winheight( win_id2win( win ) ) )

  " default - hide
  silent exe 'YcmToggleLogs' keys( log_files )[ 0 ]
  " buffer is wiped out
  call assert_equal( bcount, len( getbufinfo() ) )
  call assert_equal( [], getbufinfo( keys( log_files )[ 0 ] ) )

  " show - 10 lines
  silent exe '10YcmToggleLogs' keys( log_files )[ 0 ]
  call assert_equal( bcount + 1, len( getbufinfo() ) )
  let win = getbufinfo( keys( log_files )[ 0 ] )[ 0 ].windows[ 0 ]
  call assert_equal( 10, winheight( win_id2win( win ) ) )

  " hide
  silent exe '10YcmToggleLogs' keys( log_files )[ 0 ]
  call assert_equal( bcount, len( getbufinfo() ) )
  call assert_equal( [], getbufinfo( keys( log_files )[ 0 ] ) )

  " show - 15 cols
  silent exe 'vertical 15YcmToggleLogs' keys( log_files )[ 0 ]
  call assert_equal( bcount + 1, len( getbufinfo() ) )
  let win = getbufinfo( keys( log_files )[ 0 ] )[ 0 ].windows[ 0 ]
  call assert_equal( 15, winwidth( win_id2win( win ) ) )

  " hide
  silent exe 'YcmToggleLogs' keys( log_files )[ 0 ]
  call assert_equal( bcount, len( getbufinfo() ) )
  call assert_equal( [], getbufinfo( keys( log_files )[ 0 ] ) )


endfunction

function! Test_GetCommandResponse()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )

  " detailed_info
  call setpos( '.', [ 0, 12, 3 ] )
  call assert_equal( "Test_OneLine()\n\nThis is the one line output.",
                   \ youcompleteme#GetCommandResponse( 'GetDoc' ) )

  call setpos( '.', [ 0, 13, 7 ] )
  call assert_equal( "Test_MultiLine()\n\nThis is the one line output.\n"
                   \ . "This is second line.",
                   \ youcompleteme#GetCommandResponse( 'GetDoc' ) )

  " display message
  call setpos( '.', [ 0, 12, 10 ] )
  call assert_equal( 'def Test_OneLine()',
                   \ youcompleteme#GetCommandResponse( 'GetType' ) )

  " Location
  call setpos( '.', [ 0, 12, 10 ] )
  call assert_equal( '',
                   \ youcompleteme#GetCommandResponse( 'GoTo' ) )

  " Error
  call setpos( '.', [ 0, 12, 10 ] )
  call assert_equal( '',
                   \ youcompleteme#GetCommandResponse( 'NotACommand', 'arg' ) )

  " Specify completer
  call setpos( '.', [ 0, 13, 7 ] )
  call assert_equal( "Test_MultiLine()\n\nThis is the one line output.\n"
                   \ . "This is second line.",
                   \ youcompleteme#GetCommandResponse( 'ft=python', 'GetDoc' ) )

  " on a command, no error
  call setpos( '.', [ 0, 1, 3 ] )
  call assert_equal( '', youcompleteme#GetCommandResponse( 'GetDoc' ) )

endfunction


function! Test_GetCommandResponse_FixIt()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/cpp/fixit.c', {} )

  " fixit returns empty
  call setpos( '.', [ 0, 3, 4 ] )
  call assert_equal( '',
                   \ youcompleteme#GetCommandResponse( 'FixIt' ) )

endfunction

function! Test_GetDefinedSubcommands_Native()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/cpp/fixit.c', {} )
  call assert_equal( 1, count( youcompleteme#GetDefinedSubcommands(),
                             \ 'GetDoc' ) )
endfunction

function! Test_GetDefinedSubcommands_NoNative()
  enew
  setf not_a_filetype
  call assert_equal( [], youcompleteme#GetDefinedSubcommands() )

  " The above call prints ValueError: No semantic completer ...."
  messages clear
endfunction


function! Test_LanguageServerStateCommands()
  YcmDisableLanguageServer
  call youcompleteme#test#commands#CheckNoCommandRequest()

  YcmEnableLanguageServer
  call youcompleteme#test#commands#CheckNoCommandRequest()

  YcmDisableLanguageServer cpp
  call youcompleteme#test#commands#CheckNoCommandRequest()

  YcmEnableLanguageServer cpp
  call youcompleteme#test#commands#CheckNoCommandRequest()
endfunction


function! Test_PrepareRenamePromptsAndAppliesRename() abort
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/document_highlights.cpp',
        \ {} )
  call cursor( 3, 8 )

  function! FeedRename( timer_id ) closure
    call YcmTest_FeedInput(
          \ "\<C-U>renamed_value\<CR>" )
  endfunction

  let timer_id = timer_start(
        \ 100,
        \ funcref( 'FeedRename' ) )
  YcmCompleter RefactorRename

  call WaitForAssert(
        \ { ->
        \   assert_equal(
        \     [
        \       '  int renamed_value = 1;',
        \       '  renamed_value += 1;',
        \       '  return renamed_value;',
        \     ],
        \     getline( 3, 5 ) ) },
        \ 10000 )
  call youcompleteme#test#commands#CheckNoCommandRequest()

  silent! call timer_stop( timer_id )
  delfunction FeedRename
  %bwipeout!
endfunction
