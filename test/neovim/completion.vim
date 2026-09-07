" Neovim-specific adapters for the shared completion integration tests.

let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )


function! YcmTest_PrepareForCompletion() abort
endfunction


function! YcmTest_FinishCompletion() abort
endfunction
