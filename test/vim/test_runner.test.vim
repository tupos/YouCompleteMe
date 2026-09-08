" Verify that the Vim test runner handles attributes on test functions.

function! Test_TestRunner_IgnoresFunctionAttributes() abort
  call assert_true( v:true )
endfunction
