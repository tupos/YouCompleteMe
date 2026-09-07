" Vim-specific adapters for the shared completion integration tests.

function! YcmTest_PrepareForCompletion() abort
  call test_override( 'char_avail', 1 )
endfunction


function! YcmTest_FinishCompletion() abort
  call test_override( 'ALL', 0 )
endfunction
