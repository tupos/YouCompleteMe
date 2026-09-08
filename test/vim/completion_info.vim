" Vim-specific adapters for shared tests involving completion-info windows.

function! YcmTest_CompletionInfoWindowVisible() abort
  let window_id = popup_findinfo()
  return window_id != 0
        \ && !empty( popup_getpos( window_id ) )
        \ && get( popup_getpos( window_id ), 'visible', v:false )
endfunction


function! YcmTest_CompletionInfoSupported() abort
  return exists( '*popup_findinfo' )
endfunction


function! YcmTest_WaitForCompletionInfoHidden() abort
  call WaitForAssert(
        \ {-> assert_false( YcmTest_CompletionInfoWindowVisible() ) } )
endfunction


function! YcmTest_WaitForCompletionInfoVisible() abort
  call WaitForAssert(
        \ {-> assert_true( YcmTest_CompletionInfoWindowVisible() ) } )
endfunction


function! YcmTest_CompletionInfoLines( first_line, last_line ) abort
  let window_id = popup_findinfo()
  if window_id == 0
    return []
  endif

  return getbufline(
        \ winbufnr( window_id ),
        \ a:first_line,
        \ a:last_line )
endfunction
