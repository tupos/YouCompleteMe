" This file is the Neovim entry point for the shared command integration tests.
" The actual tests and common setup are in test/shared/commands.vim.

function! s:FeedInputWhenPromptIsVisible( keys, timer_id ) abort
  if mode( 1 ) !=# 'c'
    return
  endif

  call timer_stop( a:timer_id )
  call feedkeys( a:keys, 't' )
endfunction


function! YcmTest_FeedInput( keys ) abort
  call timer_start(
        \ 10,
        \ function( 's:FeedInputWhenPromptIsVisible', [ a:keys ] ),
        \ { 'repeat': 1000 } )
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/commands.vim' )
