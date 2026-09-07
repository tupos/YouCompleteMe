function! YcmTest_CompletionInfoSupported() abort
  return exists( '*popup_findinfo' )
endfunction


function! YcmTest_WaitForCompletionInfoHidden() abort
  call WaitForAssert( {-> assert_true(
        \ popup_findinfo() == 0 ||
        \ !popup_getpos( popup_findinfo() ).visible ) } )
endfunction


function! YcmTest_WaitForCompletionInfoVisible() abort
  call WaitForAssert( {-> assert_true(
        \ popup_findinfo() != 0 &&
        \ !empty( popup_getpos( popup_findinfo() ) ) &&
        \ popup_getpos( popup_findinfo() ).visible ) } )
endfunction


function! YcmTest_CompletionInfoLines( first_line, last_line ) abort
  let info_popup_id = popup_findinfo()
  if info_popup_id == 0
    return []
  endif
  return getbufline(
        \ winbufnr( info_popup_id ),
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


function! Test_Using_Ondemand_Resolve()
  let debug_info = split( execute( 'YcmDebugInfo' ), "\n" )
  enew
  setf cpp

  call assert_equal( '', &completefunc )

  for line in debug_info
    if line =~# "^-- Resolve completions: "
      let ver = substitute( line, "^-- Resolve completions: ", "", "" )
      call assert_equal( 'On demand', ver, 'API version' )
      return
    endif
  endfor

  call assert_report( "Didn't find the resolve type in the YcmDebugInfo" )
endfunction
