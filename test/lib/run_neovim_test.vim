" Let each test run for at most one minute.
let s:single_test_timeout = 60000

set nocompatible
set encoding=utf-8
set nomore
lang messages C

let g:testname = expand( '%' )
let g:testpath = expand( '%:p' )
let s:done = 0
let s:errors = []
let s:current_test = ''


function! s:FinishTesting() abort
  if s:done == 0
    call add( s:errors, 'NO tests executed' )
  endif

  let summary = [ 'Executed ' . s:done .
                \ ( s:done == 1 ? ' test' : ' tests' ) ]
  call writefile( summary + s:errors, 'messages' )

  if !empty( s:errors )
    call writefile( s:errors, 'test.log' )
    echo len( s:errors ) . ' FAILED'
    cquit!
  endif

  call writefile( [], g:testname . '.res' )
  echo summary[ 0 ]
  qall!
endfunction


function! s:Abort( timer_id ) abort
  call add( s:errors, 'Test timed out: ' . s:current_test )
  call s:FinishTesting()
endfunction


function! s:RunTest( test ) abort
  echo 'Executing ' . a:test
  let s:current_test = a:test
  let s:done += 1
  let v:errors = []
  let timer = timer_start(
        \ s:single_test_timeout,
        \ function( 's:Abort' ) )

  try
    if exists( '*SetUp' )
      call SetUp()
    endif
    execute 'call ' . a:test
  catch
    call add( v:errors,
          \ 'Caught exception in ' . a:test . ': ' .
          \ v:exception . ' @ ' . v:throwpoint )
  endtry

  if exists( '*TearDown' )
    try
      call TearDown()
    catch
      call add( v:errors,
            \ 'Caught exception in TearDown() after ' . a:test . ': ' .
            \ v:exception . ' @ ' . v:throwpoint )
    endtry
  endif

  call timer_stop( timer )
  if !empty( v:errors )
    call add( s:errors, 'Found errors in ' . g:testpath . ':' . a:test )
    call extend( s:errors, v:errors )
  endif
endfunction


try
  execute 'source ' . fnameescape( g:testpath )
catch
  call add( s:errors,
        \ 'Caught exception while loading test: ' .
        \ v:exception . ' @ ' . v:throwpoint )
endtry

redir => s:functions
silent function /^Test_
redir END
let s:tests = map(
      \ split( s:functions, "\n" ),
      \ 'matchstr( v:val, ''^function \zsTest_\k*()'' )' )
call filter( s:tests, '!empty( v:val )' )

if argc() > 1
  let s:tests = filter(
        \ s:tests,
        \ 'v:val =~ argv( 1 )' )
endif

for s:test in sort( s:tests )
  call s:RunTest( s:test )
endfor

call s:FinishTesting()
