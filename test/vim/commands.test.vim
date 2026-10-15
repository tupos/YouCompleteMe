" This file is the Vim entry point for the shared command integration tests.
" The actual tests and common setup are in test/shared/commands.vim.

function! YcmTest_FeedInput( keys ) abort
  call test_feedinput( a:keys )
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/commands.vim' )
