function! youcompleteme#test#coverage#Start( profile_file ) abort
  if !exists( '$COVERAGE' )
    return
  endif

  pyx << EOF
def _InitYcmTestCoverage() -> object | None:
  try:
    import coverage
  except ImportError:
    return None

  test_coverage = coverage.Coverage(
    data_file = '.coverage.python',
    data_suffix = True
  )
  test_coverage.start()
  return test_coverage


_ycm_test_coverage = _InitYcmTestCoverage()
EOF

  execute 'profile start ' . fnameescape( a:profile_file )
  profile! file */youcompleteme.vim
  profile! file */youcompleteme/**.vim
endfunction


function! youcompleteme#test#coverage#Stop() abort
  if !exists( '$COVERAGE' )
    return
  endif

  if pyxeval( '_ycm_test_coverage is not None' )
    pyx _ycm_test_coverage.stop()
    pyx _ycm_test_coverage.save()
  endif
endfunction
