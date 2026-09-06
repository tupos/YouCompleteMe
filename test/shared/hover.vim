" Shared hover integration-test setup and assertions.
" Editor-specific adapters provide:
"
"   YcmTest_HoverWindow()
"   YcmTest_HoverWindowAtScreenPosition( position )
"   YcmTest_ClearHoverWindows()
"   YcmTest_HoverContentSize()

function! s:CheckNoCommandRequest()
  return youcompleteme#test#commands#CheckNoCommandRequest()
endfunction


function! s:CheckHoverVisible( text, syntax )
  redraw
  call s:CheckNoCommandRequest()
  call WaitForAssert( { ->
        \ assert_notequal(
        \   0,
        \   YcmTest_HoverWindow(),
        \   'Find visible hover window' )
        \ } )

  let window_id = YcmTest_HoverWindow()
  if a:text isnot v:null
    call assert_equal(
          \ a:text,
          \ getbufline( winbufnr( window_id ), 1, '$' ) )
  endif
  call assert_equal(
        \ a:syntax,
        \ getbufvar( winbufnr( window_id ), '&syntax' ) )
  return window_id
endfunction


function! s:CheckHoverNotVisible()
  redraw
  call s:CheckNoCommandRequest()
  call WaitForAssert( { ->
        \ assert_equal( 0, YcmTest_HoverWindow() )
        \ } )
endfunction

function! s:CheckPopupVisible( row, col, text, syntax )
  " Takes a buffer position, converts it to a screen position and checks the
  " popup found at that location
  redraw
  let loc = screenpos( win_getid(), a:row, a:col )
  return s:CheckPopupVisibleScreenPos( loc, a:text, a:syntax )
endfunction

function! s:CheckPopupVisibleScreenPos( loc, text, syntax )
  " Takes a position dict like the one returned by screenpos() and verifies it
  " has 'text' (a list of lines) and 'syntax' the &syntax setting
  " popup found at that location
  redraw
  call s:CheckNoCommandRequest()
  call WaitForAssert( { ->
        \   assert_notequal( 0,
        \                    YcmTest_HoverWindowAtScreenPosition( a:loc ),
        \                    'Locate popup at ('
        \                    . a:loc.row
        \                    . ','
        \                    . a:loc.col
        \                    . ')' )
       \ } )
  let popup = YcmTest_HoverWindowAtScreenPosition( a:loc )
  if a:text isnot v:null
    call assert_equal( a:text,
                     \ getbufline( winbufnr( popup ), 1, '$' ) )
  endif
  call assert_equal( a:syntax, getbufvar( winbufnr( popup ), '&syntax' ) )
endfunction

function! s:CheckPopupNotVisible( row, col )
  " Takes a buffer position and ensures there is no popup visible at that
  " position. Like CheckPopupVisible, the position must be valid (i.e. there
  " must be buffer text at that position). Otherwise, you need to pass the
  " _screen_ position to CheckPopupNotVisibleScreenPos
  redraw
  let loc = screenpos( win_getid(), a:row, a:col )
  return s:CheckPopupNotVisibleScreenPos( loc )
endfunction

function! s:CheckPopupNotVisibleScreenPos( loc )
  " Takes a position dict like the one returned by screenpos() and verifies it
  " does not have a popup drawn on it.
  redraw
  call s:CheckNoCommandRequest()
  call WaitForAssert( { ->
        \   assert_equal(
        \     0,
        \     YcmTest_HoverWindowAtScreenPosition( a:loc ) )
        \ } )
endfunction

let s:python_oneline = {
      \ 'GetDoc': [ 'Test_OneLine()', '', 'This is the one line output.' ],
      \ 'GetType': [ 'def Test_OneLine()' ],
      \ }
let s:python_long_wrapped = [
      \ 'Really_Long_Method_2()',
      \ '',
      \ 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum '
      \ . 'egestas',
      \ 'libero urna, vel sagittis felis condimentum in. Nulla arcu eros, '
      \ . 'aliquet vel',
      \ 'mollis vitae, semper eu ex. Donec posuere quam et ornare sagittis. '
      \ . 'Curabitur',
      \ 'nunc ex, fringilla quis lorem sed, dignissim congue felis. Integer '
      \ . 'vestibulum',
      \ 'ac elit vel blandit. Nam non dui urna. Integer eu semper massa. '
      \ . 'Nullam ac elit',
      \ 'interdum, aliquet elit nec, porttitor orci. Duis tempus justo lorem, ac',
      \ 'fringilla ante viverra egestas. Etiam eleifend enim ac libero '
      \ . 'dapibus, quis',
      \ 'condimentum lectus tristique. Fusce feugiat, lorem et faucibus '
      \ . 'eleifend, ipsum',
      \ 'nisi maximus justo, at consectetur ligula leo vitae justo.',
      \ ]
let s:cpp_lifetime = {
      \ 'GetDoc': [ 'field lifetime',
      \             '',
      \             'Type: char',
      \             'Offset: 16 bytes',
      \             'Size: 1 byte (+7 bytes padding), alignment 1 byte',
      \             'nobody will live > 128 years',
      \             '',
      \             '// In PointInTime',
      \             'public: char lifetime' ],
      \ 'GetType': [ 'public: char lifetime; // In PointInTime' ],
      \ }

function! SetUp()
  let g:ycm_use_clangd = 1
  let g:ycm_keep_logfiles = 1
  let g:ycm_log_level = 'DEBUG'
  let g:ycm_enable_semantic_highlighting = 1

  set signcolumn=no
  nmap <leader>D <Plug>(YCMHover)
  call youcompleteme#test#setup#SetUp()
endfunction

function! TearDown()
  let g:ycm_auto_hover='CursorHold'

  call assert_equal( -1, youcompleteme#Test_GetPollers().command.id )
endfunction

function! Test_Hover_Uses_GetDoc()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )

  call assert_equal( 'python', &syntax )

  " no doc
  call setpos( '.', [ 0, 1, 1 ] )
  doautocmd CursorHold
  call assert_equal( { 'command': 'GetDoc', 'syntax': '' }, b:ycm_hover )

  call s:CheckHoverNotVisible()

  " some doc - autocommand
  call setpos( '.', [ 0, 12, 3 ] )
  doautocmd CursorHold
  call s:CheckHoverVisible( s:python_oneline.GetDoc, '' )
  call YcmTest_ClearHoverWindows()

  " some doc - mapping
  call setpos( '.', [ 0, 12, 3 ] )
  normal \D
  call s:CheckHoverVisible( s:python_oneline.GetDoc, '' )
  call YcmTest_ClearHoverWindows()
endfunction

function! Test_Hover_Uses_GetHover()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )
  py3 <<EOPYTHON
from unittest import mock
with mock.patch.object( ycm_state,
                        'GetDefinedSubcommands',
                        return_value = [ 'GetHover' ] ):
  vim.command( 'doautocmd CursorHold' )
EOPYTHON

  call assert_equal( { 'command': 'GetHover', 'syntax': 'markdown' },
                   \ b:ycm_hover )

  " Only the generic LSP completer supports the GetHover response, so i guess we
  " test the error condition here...

  " Python desn't support GetHover
  call setpos( '.', [ 0, 12, 3 ] )
  normal \D
  call s:CheckHoverNotVisible()
  call YcmTest_ClearHoverWindows()

endfunction

function! Test_Hover_Uses_None()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )
  py3 <<EOPYTHON
from unittest import mock
with mock.patch.object( ycm_state, 'GetDefinedSubcommands', return_value = [] ):
  vim.command( 'doautocmd CursorHold' )
EOPYTHON

  call assert_equal( {}, b:ycm_hover )

  call setpos( '.', [ 0, 12, 3 ] )
  normal \D
  call s:CheckHoverNotVisible()

  call YcmTest_ClearHoverWindows()
endfunction

function! Test_Hover_Uses_GetType()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )

  py3 <<EOPYTHON
from unittest import mock
with mock.patch.object( ycm_state,
                        'GetDefinedSubcommands',
                        return_value = [ 'GetType' ] ):
  vim.command( 'doautocmd CursorHold' )
EOPYTHON

  call assert_equal( { 'command': 'GetType', 'syntax': 'python' }, b:ycm_hover )

  call s:CheckHoverNotVisible()

  " some doc - autocommand
  call setpos( '.', [ 0, 12, 3 ] )
  doautocmd CursorHold
  call s:CheckHoverVisible( s:python_oneline.GetType, 'python' )
  call YcmTest_ClearHoverWindows()

  " some doc - mapping
  call setpos( '.', [ 0, 12, 3 ] )
  normal \D
  call s:CheckHoverVisible( s:python_oneline.GetType, 'python' )

  " hide it again
  normal \D
  call s:CheckHoverNotVisible()

  " show it again
  normal \D
  call s:CheckHoverVisible( s:python_oneline.GetType, 'python' )
  call YcmTest_ClearHoverWindows()

endfunction

function! Test_Hover_NonNative()
  call youcompleteme#test#setup#OpenFile( '_not_a_file', { 'native_ft': 0 } )
  setfiletype NoASupportedFileType
  let messages_before = execute( 'messages' )
  doautocmd CursorHold
  call s:CheckNoCommandRequest()
  call assert_false( exists( 'b:ycm_hover' ) )
  call assert_equal( messages_before, execute( 'messages' ) )

  normal \D
  call s:CheckNoCommandRequest()
  call assert_false( exists( 'b:ycm_hover' ) )
  call assert_equal( messages_before, execute( 'messages' ) )

  call YcmTest_ClearHoverWindows()
endfunction

function SetUp_Test_Hover_Disabled_NonNative()
  let g:ycm_auto_hover = ''
endfunction

function! Test_Hover_Disabled_NonNative()
  call youcompleteme#test#setup#OpenFile( '_not_a_file', { 'native_ft': 0 } )
  setfiletype NoASupportedFileType
  let messages_before = execute( 'messages' )
  silent! doautocmd CursorHold
  call s:CheckNoCommandRequest()
  call assert_false( exists( 'b:ycm_hover' ) )
  call assert_equal( messages_before, execute( 'messages' ) )

  call YcmTest_ClearHoverWindows()
endfunction

function! SetUp_Test_AutoHover_Disabled()
  let g:ycm_auto_hover = ''
endfunction

function! Test_AutoHover_Disabled()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )

  let messages_before = execute( 'messages' )

  call assert_false( exists( 'b:ycm_hover' ) )

  call setpos( '.', [ 0, 12, 3 ] )
  silent! doautocmd CursorHold
  call s:CheckHoverNotVisible()
  call assert_equal( messages_before, execute( 'messages' ) )

  " Manual hover is still supported
  normal \D
  call assert_true( exists( 'b:ycm_hover' ) )
  call s:CheckHoverVisible( s:python_oneline.GetDoc, '' )
  call assert_equal( messages_before, execute( 'messages' ) )

  " Manual close hover is still supported
  normal \D
  call s:CheckHoverNotVisible()
  call assert_equal( messages_before, execute( 'messages' ) )

  call YcmTest_ClearHoverWindows()
endfunction

function! Test_Hover_Dismiss()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )

  call setpos( '.', [ 0, 12, 3 ] )
  doautocmd CursorHold
  call s:CheckHoverVisible( s:python_oneline.GetDoc, '' )

  " Dismiss
  normal \D
  call s:CheckHoverNotVisible()

  " Make sure it doesn't come back
  silent! doautocmd CursorHold
  call s:CheckHoverNotVisible()

  " Explicitly dispatch CursorMoved because movement while executing a test
  " script does not reliably dispatch it in every editor.
  doautocmd CursorMoved
  doautocmd CursorHold
  call s:CheckHoverVisible( s:python_oneline.GetDoc, '' )

  call YcmTest_ClearHoverWindows()
endfunction

function! SetUp_Test_Hover_Custom_Syntax()
  augroup MyYCMCustom
    autocmd!
    autocmd FileType cpp let b:ycm_hover = {
      \ 'command': 'GetDoc',
      \ 'syntax': 'cpp',
      \ }
  augroup END
endfunction

function! Test_Hover_Custom_Syntax()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/cpp/completion.cc',
                                        \ {} )
  call assert_equal( 'cpp', &filetype )
  call assert_equal( { 'command': 'GetDoc', 'syntax': 'cpp' }, b:ycm_hover )

  call setpos( '.', [ 0, 6, 8 ] )
  doautocmd CursorHold
  call assert_equal( { 'command': 'GetDoc', 'syntax': 'cpp' }, b:ycm_hover )
  call s:CheckHoverVisible( s:cpp_lifetime.GetDoc, 'cpp' )

  normal \D
  call s:CheckHoverNotVisible()

  call YcmTest_ClearHoverWindows()
endfunction

function! TearDown_Test_Hover_Custom_Syntax()
  silent! au! MyYCMCustom
endfunction

function! SetUp_Test_Hover_Custom_Command()
  augroup MyYCMCustom
    autocmd!
    autocmd FileType cpp let b:ycm_hover = {
      \ 'command': 'GetType',
      \ 'syntax': 'cpp',
      \ }
  augroup END
endfunction

function! Test_Hover_Custom_Command()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/cpp/completion.cc',
                                        \ {} )
  call assert_equal( 'cpp', &filetype )
  call assert_equal( { 'command': 'GetType', 'syntax': 'cpp' }, b:ycm_hover )

  call setpos( '.', [ 0, 6, 8 ] )
  doautocmd CursorHold
  call assert_equal( { 'command': 'GetType', 'syntax': 'cpp' }, b:ycm_hover )

  call s:CheckHoverVisible( s:cpp_lifetime.GetType, 'cpp' )

  call YcmTest_ClearHoverWindows()
endfunction

function! TearDown_Test_Hover_Custom_Command()
  silent! au! MyYCMCustom
endfunction

function! SetUp_Test_Hover_Custom_Popup()
  augroup MyYCMCustom
    autocmd!
    autocmd FileType cpp let b:ycm_hover = {
      \ 'command': 'GetDoc',
      \ 'syntax': 'cpp',
      \ 'popup_params': {
      \     'maxwidth': 10,
      \   }
      \ }
  augroup END
endfunction

function! Test_Hover_Custom_Popup()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/cpp/completion.cc',
                                        \ {} )
  call assert_equal( 'cpp', &filetype )
  call assert_equal( {
                   \   'command': 'GetDoc',
                   \   'syntax': 'cpp',
                   \   'popup_params': { 'maxwidth': 10 }
                   \ }, b:ycm_hover )

  call setpos( '.', [ 0, 6, 8 ] )
  doautocmd CursorHold
  call assert_equal( {
                   \   'command': 'GetDoc',
                   \   'syntax': 'cpp',
                   \   'popup_params': { 'maxwidth': 10 }
                   \ }, b:ycm_hover )

  call s:CheckPopupVisibleScreenPos( { 'row': 7, 'col': 9 },
                                   \ s:cpp_lifetime.GetDoc,
                                   \ 'cpp' )
  " Check that popup's width is limited by maxwidth being passed
  call s:CheckPopupNotVisibleScreenPos( { 'row': 7, 'col': 20 } )

  normal \D
  call s:CheckPopupNotVisibleScreenPos( { 'row': 7, 'col': 9 } )

  call YcmTest_ClearHoverWindows()
endfunction

function! TearDown_Test_Hover_Custom_Popup()
  silent! au! MyYCMCustom
endfunction

function! Test_Long_Single_Line()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )
  call cursor( [ 37, 3 ] )
  normal \D

  " The popup should cover at least the whole of the line above, and not the
  " current line
  call s:CheckPopupVisible( 36, 1, v:null, '' )
  call s:CheckPopupVisible( 36, &columns, v:null, '' )

  call s:CheckPopupNotVisible( 37, 1 )
  call s:CheckPopupNotVisible( 37, &columns )

  " Also wrap is ON so it should cover at least 2 lines + 2 for the header/empty
  " line
  call s:CheckPopupVisible( 35, 1, v:null, '' )
  call s:CheckPopupVisible( 35, &columns, v:null, '' )
  call s:CheckPopupVisible( 33, 1, v:null, '' )
  call s:CheckPopupVisible( 33, &columns, v:null, '' )

  call YcmTest_ClearHoverWindows()
endfunction

function! Test_Long_Wrapped()
  call youcompleteme#test#setup#OpenFile( '/test/testdata/python/doc.py', {} )
  call cursor( [ 38, 22 ] )
  normal \D

  call s:CheckHoverVisible( s:python_long_wrapped, '' )
  call assert_equal(
        \ {
        \   'height': len( s:python_long_wrapped ),
        \   'width': &columns - 2,
        \ },
        \ YcmTest_HoverContentSize() )

  call YcmTest_ClearHoverWindows()
endfunction
