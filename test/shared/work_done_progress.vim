function! SetUp()
  let g:ycm_use_clangd = 1
  let g:ycm_keep_logfiles = 1
  let g:ycm_log_level = 'DEBUG'
  let g:ycm_status_change_count = 0
  call youcompleteme#test#setup#SetUp()

  augroup YcmWorkDoneProgressTest
    autocmd!
    autocmd User YcmStatusChanged
          \ let g:ycm_status_change_count += 1
  augroup END
endfunction


function! TearDown()
  augroup YcmWorkDoneProgressTest
    autocmd!
  augroup END
  call youcompleteme#test#setup#CleanUp()
  unlet g:ycm_status_change_count
endfunction


function! Test_WorkDoneProgress_Status()
  py3 ycm_state.UpdateWorkDoneProgress( {
        \ 'server': 'clangd',
        \ 'connection_generation': 1,
        \ 'token': 'index',
        \ 'kind': 'begin',
        \ 'title': 'Indexing',
        \ 'message': 'Loading files',
        \ 'percentage': 42 } )
  call youcompleteme#Test_UpdateWorkDoneProgress()

  call assert_equal( '⠋ Indexing Loading files 42%',
        \ youcompleteme#GetStatus() )
  call assert_equal( '⠋ Indexing Loading files 42%%',
        \ youcompleteme#GetStatus( 1 ) )
  call assert_true( g:ycm_status_change_count > 0 )
  call assert_true(
        \ youcompleteme#Test_GetPollers().work_done_progress.id >= 0 )

  py3 ycm_state.UpdateWorkDoneProgress( {
        \ 'server': 'clangd',
        \ 'connection_generation': 1,
        \ 'token': 'index',
        \ 'kind': 'end' } )
  call youcompleteme#Test_UpdateWorkDoneProgress()

  call assert_equal( '', youcompleteme#GetStatus() )
  call assert_equal(
        \ -1,
        \ youcompleteme#Test_GetPollers().work_done_progress.id )
endfunction


function! Test_WorkDoneProgress_Animation()
  py3 ycm_state.UpdateWorkDoneProgress( {
        \ 'server': 'clangd',
        \ 'connection_generation': 1,
        \ 'token': 'index',
        \ 'kind': 'begin',
        \ 'title': 'Indexing' } )
  call youcompleteme#Test_UpdateWorkDoneProgress()
  let initial_status = youcompleteme#GetStatus()

  call WaitForAssert(
        \ { -> assert_notequal( initial_status,
        \                       youcompleteme#GetStatus() ) } )

  py3 ycm_state.UpdateWorkDoneProgress( {
        \ 'server': 'clangd',
        \ 'connection_generation': 1,
        \ 'token': 'index',
        \ 'kind': 'end' } )
  call youcompleteme#Test_UpdateWorkDoneProgress()
endfunction


function! Test_WorkDoneProgress_Cleanup()
  py3 ycm_state.UpdateWorkDoneProgress( {
        \ 'server': 'clangd',
        \ 'connection_generation': 1,
        \ 'token': 'index',
        \ 'kind': 'begin',
        \ 'title': 'Indexing' } )
  call youcompleteme#Test_UpdateWorkDoneProgress()

  call assert_equal( '⠋ Indexing', youcompleteme#GetStatus() )
  call assert_true(
        \ youcompleteme#Test_GetPollers().work_done_progress.id >= 0 )

  py3 ycm_state.ClearWorkDoneProgress( {
        \ 'server': 'clangd',
        \ 'connection_generation': 1 } )
  call youcompleteme#Test_UpdateWorkDoneProgress()

  call assert_equal( '', youcompleteme#GetStatus() )
  call assert_equal(
        \ -1,
        \ youcompleteme#Test_GetPollers().work_done_progress.id )
endfunction
