" This file is the Neovim entry point for the shared filesize integration tests.
" The actual tests and common setup are in test/shared/filesize.vim.

execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/filesize.vim' )
