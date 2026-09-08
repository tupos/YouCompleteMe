" Neovim-specific adapters for shared tests involving completion-info windows.

function! YcmTest_CompletionInfoWindowVisible() abort
  let window_id = get( complete_info(), 'preview_winid', 0 )
  return window_id != 0
        \ && nvim_win_is_valid( window_id )
        \ && !get(
        \   nvim_win_get_config( window_id ),
        \   'hide',
        \   v:false )
endfunction


function! YcmTest_CompletionInfoSupported() abort
  return youcompleteme#editor_support#FeatureSupported(
        \ 'completion_info_popup' )
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
  let window_id = get( complete_info(), 'preview_winid', 0 )
  if window_id == 0 || !nvim_win_is_valid( window_id )
    return []
  endif

  return getbufline(
        \ nvim_win_get_buf( window_id ),
        \ a:first_line,
        \ a:last_line )
endfunction
