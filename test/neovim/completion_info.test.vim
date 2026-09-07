" Neovim adapter for the shared completion-info integration tests.

function! s:CompletionInfoWindowIsVisible() abort
  let window_id = get( complete_info(), 'preview_winid', 0 )
  return window_id != 0 &&
        \ nvim_win_is_valid( window_id ) &&
        \ !get( nvim_win_get_config( window_id ), 'hide', v:false )
endfunction


function! YcmTest_CompletionInfoSupported() abort
  return has( 'nvim-0.10' )
endfunction


function! YcmTest_WaitForCompletionInfoHidden() abort
  call WaitForAssert(
        \ { -> assert_false( s:CompletionInfoWindowIsVisible() ) } )
endfunction


function! YcmTest_WaitForCompletionInfoVisible() abort
  call WaitForAssert(
        \ { -> assert_true( s:CompletionInfoWindowIsVisible() ) } )
endfunction


function! YcmTest_CompletionInfoLines( first_line, last_line ) abort
  let window_id = get( complete_info(), 'preview_winid', 0 )
  if window_id == 0 || !nvim_win_is_valid( window_id )
    return []
  endif

  return getbufline(
        \ nvim_win_get_buf( window_id ),
        \ a:first_line,
        \ a:last_line )
endfunction


function! SetUp()
  let g:ycm_use_clangd = 1
  let g:ycm_confirm_extra_conf = 0
  let g:ycm_auto_trigger = 1
  let g:ycm_keep_logfiles = 1
  let g:ycm_log_level = 'DEBUG'

  let g:ycm_add_preview_to_completeopt = 'popup'
  let g:ycm_enable_semantic_highlighting = 1

  set completeopt-=preview
  set completeopt+=popup

  call youcompleteme#test#setup#SetUp()
endfunction


function! TearDown()
  call youcompleteme#test#setup#CleanUp()
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h' ) . '/completion.vim' )
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/completion.vim' )
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/completion_info.vim' )


function! Test_Using_Upfront_Resolve()
  let debug_info = split( execute( 'YcmDebugInfo' ), "\n" )
  enew
  setf cpp

  call assert_equal( '', &completefunc )

  for line in debug_info
    if line =~# "^-- Resolve completions: "
      let ver = substitute( line, "^-- Resolve completions: ", "", "" )
      call assert_equal( 'Up front', ver, 'API version' )
      return
    endif
  endfor

  call assert_report( "Didn't find the resolve type in the YcmDebugInfo" )
endfunction
