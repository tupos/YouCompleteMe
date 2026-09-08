" This file provides the Neovim-specific adapter for the shared signature-help
" integration tests. The actual tests are in
" test/shared/signature_help.vim.

let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )


function! YcmTest_SignatureHelpWindowVisible( window_id ) abort
  return a:window_id > 0
        \ && nvim_win_is_valid( a:window_id )
        \ && !nvim_win_get_config( a:window_id ).hide
endfunction


function! YcmTest_SignatureHelpSelectedLine( window_id ) abort
  return nvim_win_get_cursor( a:window_id )[ 0 ]
endfunction


function! YcmTest_SignatureHelpHighlights( window_id ) abort
  let namespace = get(
        \ nvim_get_namespaces(),
        \ 'ycm_signature_help',
        \ -1 )
  if namespace < 0
    return []
  endif

  let highlights = []
  for extmark in nvim_buf_get_extmarks(
        \ nvim_win_get_buf( a:window_id ),
        \ namespace,
        \ 0,
        \ -1,
        \ {
        \   'details': v:true,
        \   'hl_name': v:true,
        \ } )
    let details = extmark[ 3 ]
    call add( highlights, {
          \ 'line': extmark[ 1 ],
          \ 'column': extmark[ 2 ],
          \ 'length': details.end_col - extmark[ 2 ],
          \ 'group': details.hl_group,
          \ } )
  endfor

  return highlights
endfunction


function! YcmTest_SetCharAvailOverride( enabled ) abort
  " test_override() is a Vim-only test API. Neovim does not need its
  " char_avail override for this scenario.
endfunction


function! YcmTest_SignatureHelpEmptyBufferHasKnownBug() abort
  return v:false
endfunction


function! YcmTest_SignatureHelpIsBelowAnchor( window_id ) abort
  return nvim_win_get_config( a:window_id ).anchor ==# 'NW'
endfunction


function! YcmTest_SignatureHelpScreenRectangle( window_id ) abort
  let position = screenpos( a:window_id, 1, 1 )
  return [
        \ position.row - 2,
        \ position.col - 2,
        \ nvim_win_get_height( a:window_id ) + 2,
        \ nvim_win_get_width( a:window_id ) + 2,
        \ ]
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h' ) . '/completion_info.vim' )
execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/signature_help.vim' )


function! SetUp() abort
  let g:ycm_use_clangd = 1
  let g:ycm_confirm_extra_conf = 0
  let g:ycm_auto_trigger = 1
  let g:ycm_keep_logfiles = 1
  let g:ycm_log_level = 'DEBUG'

  call youcompleteme#test#setup#SetUp()
endfunction


function! TearDown() abort
  call youcompleteme#signature_help#Clear()
  call youcompleteme#test#setup#CleanUp()
endfunction


function! Test_SignatureHelp_UI_PreservesUnrelatedExtmarks() abort
  new
  call setline(
        \ 1,
        \ repeat( [ repeat( 'x', 40 ) ], 20 ) )
  call cursor( 10, 10 )
  redraw

  let signature_info = {
        \ 'activeSignature': 0,
        \ 'activeParameter': 0,
        \ 'signatures': [
        \   {
        \     'label': 'function(int value)',
        \     'parameters': [
        \       { 'label': [ 9, 18 ] },
        \     ],
        \   },
        \ ],
        \ }
  call youcompleteme#signature_help#Update( signature_info )

  let window_id = youcompleteme#signature_help#WindowID()
  let buffer_number = nvim_win_get_buf( window_id )
  let unrelated_namespace = nvim_create_namespace(
        \ 'ycm_signature_help_test_unrelated' )
  let unrelated_extmark = nvim_buf_set_extmark(
        \ buffer_number,
        \ unrelated_namespace,
        \ 0,
        \ 0,
        \ {
        \   'end_row': 0,
        \   'end_col': 1,
        \   'hl_group': 'Search',
        \ } )

  call youcompleteme#signature_help#Update( signature_info )

  call assert_notequal(
        \ [],
        \ nvim_buf_get_extmark_by_id(
        \   buffer_number,
        \   unrelated_namespace,
        \   unrelated_extmark,
        \   {} ) )
endfunction


function! Test_SignatureHelp_UI_UsesNativePlacement() abort
  new
  call setline(
        \ 1,
        \ repeat( [ repeat( 'x', 40 ) ], 30 ) )
  let source_window_id = win_getid()
  let signature_info = {
        \ 'activeSignature': 0,
        \ 'activeParameter': 0,
        \ 'signatures': [
        \   {
        \     'label': 'function(int value)',
        \     'parameters': [
        \       { 'label': [ 9, 18 ] },
        \     ],
        \   },
        \ ],
        \ }

  call cursor( 2, 10 )
  redraw
  call youcompleteme#signature_help#Update( signature_info )

  let window_id = youcompleteme#signature_help#WindowID()
  let configuration = nvim_win_get_config( window_id )
  call assert_equal(
        \ 'win',
        \ configuration.relative )
  call assert_equal(
        \ source_window_id,
        \ configuration.win )
  call assert_equal(
        \ [ 1, 9 ],
        \ configuration.bufpos )
  call assert_equal(
        \ 'NW',
        \ configuration.anchor )

  call youcompleteme#signature_help#Clear()
  call cursor( 25, 10 )
  redraw
  call youcompleteme#signature_help#Update( signature_info )

  let window_id = youcompleteme#signature_help#WindowID()
  let configuration = nvim_win_get_config( window_id )
  call assert_equal(
        \ 'win',
        \ configuration.relative )
  call assert_equal(
        \ source_window_id,
        \ configuration.win )
  call assert_equal(
        \ [ 24, 9 ],
        \ configuration.bufpos )
  call assert_equal(
        \ 'SW',
        \ configuration.anchor )
endfunction
