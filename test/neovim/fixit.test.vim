" This file provides the Neovim adapter for the shared FixIt integration tests.
" The actual tests and common setup are in test/shared/fixit.vim.

function! YcmTest_FeedInput( keys ) abort
  call feedkeys( a:keys, 't' )
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/fixit.vim' )
