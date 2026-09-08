" This file provides the Neovim adapter for the shared diagnostics integration
" tests. The actual tests and common setup are in test/shared/diagnostics.vim.

let s:diagnostic_virtual_text_namespace = nvim_create_namespace(
      \ 'ycm_diagnostic_virtual_text' )

function! YcmTest_DetailedDiagnosticWindow() abort
  redraw
  for window_id in nvim_list_wins()
    if getwinvar( window_id, 'ycm_diagnostic_popup', v:false )
      return window_id
    endif
  endfor

  return 0
endfunction


function! YcmTest_CheckDetailedDiagnosticWindow( window_id ) abort
  call assert_notequal(
        \ 0,
        \ a:window_id,
        \ "Couldn't find detailed diagnostic floating window" )
  if a:window_id == 0
    return
  endif

  call assert_true( nvim_win_is_valid( a:window_id ) )
  let window_config = nvim_win_get_config( a:window_id )
  call assert_equal( 'win', window_config.relative )
  call assert_equal( win_getid(), window_config.win )
  call assert_equal(
        \ [ line( '.' ) - 1, col( '.' ) - 1 ],
        \ window_config.bufpos )
  call assert_false( window_config.focusable )
endfunction


function! YcmTest_DetailedDiagnosticWindowExists( window_id ) abort
  return a:window_id > 0 && nvim_win_is_valid( a:window_id )
endfunction


function! YcmTest_CloseDetailedDiagnosticWindow( window_id ) abort
  call youcompleteme#diagnostic_popup#neovim#Close( a:window_id )
endfunction


function! YcmTest_SetCharAvailOverride( enabled ) abort
  " test_override() is a Vim-only test API. Neovim does not need its
  " char_avail override for these scenarios.
endfunction


function! YcmTest_ProcessCursorMoved() abort
  " Neovim normally dispatches CursorMoved after returning to its event loop.
  doautocmd <nomodeline> CursorMoved
endfunction


function! s:YcmExtmarks() abort
  if !exists( 'g:ycm_neovim_ns_id' )
    return []
  endif

  return nvim_buf_get_extmarks(
        \ bufnr( '%' ),
        \ g:ycm_neovim_ns_id,
        \ 0,
        \ -1,
        \ {
        \   'details': v:true,
        \   'hl_name': v:true,
        \ } )
endfunction


function! YcmTest_VirtualDiagnosticProperties() abort
  return nvim_buf_get_extmarks(
        \ bufnr( '%' ),
        \ s:diagnostic_virtual_text_namespace,
        \ 0,
        \ -1,
        \ { 'details': v:true } )
endfunction


function! YcmTest_RenderedVirtualDiagnostics() abort
  let rendered_diagnostics = []

  for extmark in YcmTest_VirtualDiagnosticProperties()
    let details = extmark[ 3 ]
    call assert_equal( 'inline', details.virt_text_pos )
    call assert_equal(
          \ strlen( getline( extmark[ 1 ] + 1 ) ),
          \ extmark[ 2 ] )

    call add( rendered_diagnostics, {
          \ 'line': extmark[ 1 ] + 1,
          \ 'chunks': details.virt_text,
          \ } )
  endfor

  return rendered_diagnostics
endfunction


function! YcmTest_DiagnosticHighlights( line_number ) abort
  let highlights = []
  for extmark in s:YcmExtmarks()
    if extmark[ 1 ] != a:line_number - 1
      continue
    endif

    let details = extmark[ 3 ]
    if details.hl_group ==# 'YcmErrorSection'
      let property_type = 'YcmErrorProperty'
    elseif details.hl_group ==# 'YcmWarningSection'
      let property_type = 'YcmWarningProperty'
    else
      continue
    endif

    call add( highlights, {
          \ 'column': extmark[ 2 ] + 1,
          \ 'length': get( details, 'end_col', extmark[ 2 ] )
          \             - extmark[ 2 ],
          \ 'type': property_type,
          \ } )
  endfor
  return highlights
endfunction


function! Test_DiagnosticVirtualTextUsesSpellingColorsWithoutDecoration() abort
  for [ diagnostic_group, spelling_group ] in [
        \ [ 'YcmErrorText', 'SpellBad' ],
        \ [ 'YcmWarningText', 'SpellCap' ],
        \ ]
    let diagnostic_highlight = nvim_get_hl(
          \ 0, { 'name': diagnostic_group, 'link': v:true } )
    let resolved_diagnostic_highlight = nvim_get_hl(
          \ 0, { 'name': diagnostic_group, 'link': v:false } )
    let spelling_highlight = nvim_get_hl(
          \ 0, { 'name': spelling_group, 'link': v:false } )

    call assert_false( has_key( diagnostic_highlight, 'link' ) )
    call assert_equal(
          \ get( spelling_highlight, 'fg', v:null ),
          \ get( resolved_diagnostic_highlight, 'fg', v:null ) )
    call assert_false(
          \ get( resolved_diagnostic_highlight, 'undercurl', v:false ) )
    call assert_false(
          \ get( resolved_diagnostic_highlight, 'underline', v:false ) )
  endfor
endfunction


execute 'source ' . fnameescape(
      \ expand( '<sfile>:p:h:h' ) . '/shared/diagnostics.vim' )
