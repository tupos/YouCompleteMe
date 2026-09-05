let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )

highlight default link YcmInvisible Normal
highlight default link YcmInlayHint NonText

let s:python_paths = [
      \ s:repository_directory . '/python',
      \ s:repository_directory . '/third_party/ycmd',
      \ ]
execute 'py3 import sys; sys.path[ 0:0 ] = ' . string( s:python_paths )

py3 << EOF
import json
import vim

from ycm import inlay_hints


YCM_TEST_INLAY_HINTS_SUPPORTED: bool = inlay_hints.Initialise()
YCM_TEST_INLAY_HINTS: dict[ int, inlay_hints.InlayHints ] = {}


def YcmTestDrawInlayHints(
    buffer_number: int,
    response: list[ dict[ str, object ] ] ) -> bool:
  if not YCM_TEST_INLAY_HINTS_SUPPORTED:
    raise RuntimeError( 'Inlay hints are not supported by this editor' )

  hints: inlay_hints.InlayHints | None = YCM_TEST_INLAY_HINTS.get(
    buffer_number
  )
  if hints is None:
    hints = inlay_hints.InlayHints( buffer_number )
    requested_range: dict[
      str,
      dict[ str, int | None ]
    ] = {
      'start': {
        'line_num': None,
        'column_num': None,
      },
      'end': {
        'line_num': None,
        'column_num': None,
      },
    }
    hints._last_requested_range = requested_range
    YCM_TEST_INLAY_HINTS[ buffer_number ] = hints

  hints._latest_response = response
  hints._Draw()
  return True
EOF


function! YcmTest_DrawInlayHints( buffer_number, response ) abort
  let response_json = json_encode( a:response )
  call py3eval(
        \ 'YcmTestDrawInlayHints('
        \ . 'int( vim.eval( "a:buffer_number" ) ), '
        \ . 'json.loads( vim.eval( "response_json" ) ) )' )
endfunction


function! Test_InlayHint_IsRendered()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, 'call()' )
  let buffer_before = getline( 1, '$' )

  call YcmTest_DrawInlayHints( bufnr(), [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 5,
        \   },
        \   'label': ': int',
        \   'paddingLeft': v:true,
        \   'paddingRight': v:true,
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 5,
        \     'chunks': [
        \       [ ' ', 'YCM_INLAY_PADDING' ],
        \       [ ': int', 'YCM_INLAY_Type' ],
        \       [ ' ', 'YCM_INLAY_PADDING' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )
  call assert_equal( buffer_before, getline( 1, '$' ) )
endfunction


function! Test_InlayHint_EmptyResponseClearsHints()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, 'call()' )

  call YcmTest_DrawInlayHints( bufnr(), [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 5,
        \   },
        \   'label': ': int',
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 5,
        \     'chunks': [
        \       [ ': int', 'YCM_INLAY_Type' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )

  call YcmTest_DrawInlayHints( bufnr(), [] )

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )
endfunction


function! Test_InlayHint_ClearOnlyAffectsTargetBuffer()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, 'first' )
  let first_buffer = bufnr()
  call YcmTest_DrawInlayHints( first_buffer, [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 1,
        \   },
        \   'label': ': first',
        \ },
        \ ] )

  new
  call setline( 1, 'second' )
  let second_buffer = bufnr()
  call YcmTest_DrawInlayHints( second_buffer, [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 1,
        \   },
        \   'label': ': second',
        \ },
        \ ] )

  call YcmTest_DrawInlayHints( first_buffer, [] )

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedInlayHints( first_buffer ) )
  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 1,
        \     'chunks': [
        \       [ ': second', 'YCM_INLAY_Type' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( second_buffer ) )
endfunction


function! Test_InlayHint_ClearPreservesUnrelatedDecorations()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, 'call()' )
  let buffer_number = bufnr()
  let unrelated_decoration = YcmTest_AddUnrelatedDecoration(
        \ buffer_number )

  call YcmTest_DrawInlayHints( buffer_number, [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 5,
        \   },
        \   'label': ': int',
        \ },
        \ ] )
  call YcmTest_DrawInlayHints( buffer_number, [] )

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedInlayHints( buffer_number ) )
  call assert_true(
        \ YcmTest_UnrelatedDecorationExists(
        \   buffer_number,
        \   unrelated_decoration ) )
endfunction


function! Test_InlayHint_PreservesCustomHighlight()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  call assert_equal(
        \ 'Normal',
        \ YcmTest_GetCustomInlayHintHighlight() )
endfunction


function! Test_InlayHint_RedrawReplacesOldHints()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, [ 'first()', 'second()' ] )

  call YcmTest_DrawInlayHints( bufnr(), [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 6,
        \   },
        \   'label': ': old',
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 6,
        \     'chunks': [
        \       [ ': old', 'YCM_INLAY_Type' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )

  call YcmTest_DrawInlayHints( bufnr(), [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 2,
        \     'column_num': 7,
        \   },
        \   'label': ': new',
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 2,
        \     'column': 7,
        \     'chunks': [
        \       [ ': new', 'YCM_INLAY_Type' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )
endfunction


function! Test_InlayHint_MultipleKindsUseExpectedHighlights()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, [ 'call()', 'value' ] )

  call YcmTest_DrawInlayHints( bufnr(), [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 5,
        \   },
        \   'label': ': int',
        \ },
        \ {
        \   'kind': 'FutureKind',
        \   'position': {
        \     'line_num': 2,
        \     'column_num': 6,
        \   },
        \   'label': ': inferred',
        \   'paddingLeft': v:true,
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 5,
        \     'chunks': [
        \       [ ': int', 'YCM_INLAY_Type' ],
        \     ],
        \   },
        \   {
        \     'line': 2,
        \     'column': 6,
        \     'chunks': [
        \       [ ' ', 'YCM_INLAY_PADDING' ],
        \       [ ': inferred', 'YCM_INLAY_UNKNOWN' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )
endfunction


function! Test_InlayHint_MissingKindUsesUnknownHighlight()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, 'call()' )

  call YcmTest_DrawInlayHints( bufnr(), [
        \ {
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 5,
        \   },
        \   'label': ': inferred',
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 5,
        \     'chunks': [
        \       [ ': inferred', 'YCM_INLAY_UNKNOWN' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )
endfunction


function! Test_InlayHint_UsesByteColumn()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, 'føo()' )

  call YcmTest_DrawInlayHints( bufnr(), [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 5,
        \   },
        \   'label': ': int',
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 5,
        \     'chunks': [
        \       [ ': int', 'YCM_INLAY_Type' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )
endfunction


function! Test_InlayHint_MultipleHintsAtSamePositionPreserveOrder()
  if !py3eval( 'YCM_TEST_INLAY_HINTS_SUPPORTED' )
    throw 'Skipped: virtual text is not supported'
  endif

  new
  call setline( 1, 'call()' )

  call YcmTest_DrawInlayHints( bufnr(), [
        \ {
        \   'kind': 'Type',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 5,
        \   },
        \   'label': ': first',
        \ },
        \ {
        \   'kind': 'Parameter',
        \   'position': {
        \     'line_num': 1,
        \     'column_num': 5,
        \   },
        \   'label': ': second',
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 5,
        \     'chunks': [
        \       [ ': first', 'YCM_INLAY_Type' ],
        \       [ ': second', 'YCM_INLAY_Parameter' ],
        \     ],
        \   },
        \ ],
        \ YcmTest_GetRenderedInlayHints( bufnr() ) )
endfunction
