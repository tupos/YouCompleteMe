" This file is the Vim entry point for the shared editor-support tests.
" The actual tests are in test/shared/editor_support.vim.

execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/editor_support.vim' )
