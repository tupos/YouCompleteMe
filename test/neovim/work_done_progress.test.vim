" This file is the Neovim entry point for the shared work-done-progress tests.
" The actual tests and common setup are in test/shared/work_done_progress.vim.

execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/work_done_progress.vim' )
