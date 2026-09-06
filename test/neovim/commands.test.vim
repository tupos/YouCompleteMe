" This file is the Neovim entry point for the shared command integration tests.
" The actual tests and common setup are in test/shared/commands.vim.

execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/commands.vim' )
