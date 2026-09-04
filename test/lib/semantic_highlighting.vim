let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )

let s:python_paths = [
      \ s:repository_directory . '/python',
      \ s:repository_directory . '/third_party/ycmd',
      \ ]
execute 'py3 import sys; sys.path[ 0:0 ] = ' . string( s:python_paths )

py3 << EOF
import json
import vim

from ycm import semantic_highlighting


YCM_TEST_SEMANTIC_HIGHLIGHTING_SUPPORTED: bool = (
  semantic_highlighting.Initialise()
)
YCM_TEST_SEMANTIC_HIGHLIGHTERS: dict[
  int,
  semantic_highlighting.SemanticHighlighting
] = {}


def YcmTestDrawSemanticHighlights(
    buffer_number: int,
    tokens: list[ dict[ str, object ] ] ) -> bool:
  if not YCM_TEST_SEMANTIC_HIGHLIGHTING_SUPPORTED:
    raise RuntimeError(
      'Semantic highlighting is not supported by this editor'
    )

  highlighter = YCM_TEST_SEMANTIC_HIGHLIGHTERS.get( buffer_number )
  if highlighter is None:
    highlighter = semantic_highlighting.SemanticHighlighting(
      buffer_number
    )
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
    highlighter._last_requested_range = requested_range
    YCM_TEST_SEMANTIC_HIGHLIGHTERS[ buffer_number ] = highlighter

  highlighter._latest_response = { 'tokens': tokens }
  highlighter._Draw()
  return True
EOF


function! YcmTest_DrawSemanticHighlights(
      \ buffer_number,
      \ tokens ) abort
  let tokens_json = json_encode( a:tokens )
  call py3eval(
        \ 'YcmTestDrawSemanticHighlights('
        \ . 'int( vim.eval( "a:buffer_number" ) ), '
        \ . 'json.loads( vim.eval( "tokens_json" ) ) )' )
endfunction


function! Test_SemanticHighlights_AreRendered()
  if !py3eval( 'YCM_TEST_SEMANTIC_HIGHLIGHTING_SUPPORTED' )
    throw 'Skipped: semantic highlighting is not supported'
  endif

  new
  call setline( 1, [ 'føo value;', 'value = 1;' ] )
  let buffer_before = getline( 1, '$' )

  call YcmTest_DrawSemanticHighlights( bufnr(), [
        \ {
        \   'type': 'variable',
        \   'range': {
        \     'start': {
        \       'line_num': 1,
        \       'column_num': 6,
        \     },
        \     'end': {
        \       'line_num': 1,
        \       'column_num': 11,
        \     },
        \   },
        \ },
        \ {
        \   'type': 'number',
        \   'range': {
        \     'start': {
        \       'line_num': 2,
        \       'column_num': 9,
        \     },
        \     'end': {
        \       'line_num': 2,
        \       'column_num': 10,
        \     },
        \   },
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 6,
        \     'length': 5,
        \     'type': 'YCM_HL_variable',
        \   },
        \   {
        \     'line': 2,
        \     'column': 9,
        \     'length': 1,
        \     'type': 'YCM_HL_number',
        \   },
        \ ],
        \ YcmTest_GetRenderedSemanticHighlights( bufnr() ) )
  call assert_equal( buffer_before, getline( 1, '$' ) )

  silent %bwipe!
endfunction


function! Test_SemanticHighlights_ClearOnlyAffectsTargetBuffer()
  if !py3eval( 'YCM_TEST_SEMANTIC_HIGHLIGHTING_SUPPORTED' )
    throw 'Skipped: semantic highlighting is not supported'
  endif

  new
  call setline( 1, 'first' )
  let first_buffer = bufnr()
  call YcmTest_DrawSemanticHighlights( first_buffer, [
        \ {
        \   'type': 'variable',
        \   'range': {
        \     'start': {
        \       'line_num': 1,
        \       'column_num': 1,
        \     },
        \     'end': {
        \       'line_num': 1,
        \       'column_num': 6,
        \     },
        \   },
        \ },
        \ ] )

  new
  call setline( 1, 'second' )
  let second_buffer = bufnr()
  call YcmTest_DrawSemanticHighlights( second_buffer, [
        \ {
        \   'type': 'variable',
        \   'range': {
        \     'start': {
        \       'line_num': 1,
        \       'column_num': 1,
        \     },
        \     'end': {
        \       'line_num': 1,
        \       'column_num': 7,
        \     },
        \   },
        \ },
        \ ] )

  call YcmTest_DrawSemanticHighlights( first_buffer, [] )

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedSemanticHighlights( first_buffer ) )
  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 1,
        \     'length': 6,
        \     'type': 'YCM_HL_variable',
        \   },
        \ ],
        \ YcmTest_GetRenderedSemanticHighlights( second_buffer ) )

  silent %bwipe!
endfunction


function! Test_SemanticHighlights_ClearPreservesUnrelatedDecorations()
  if !py3eval( 'YCM_TEST_SEMANTIC_HIGHLIGHTING_SUPPORTED' )
    throw 'Skipped: semantic highlighting is not supported'
  endif

  new
  call setline( 1, 'value' )
  let buffer_number = bufnr()
  let unrelated_decoration = YcmTest_AddUnrelatedDecoration(
        \ buffer_number )

  call YcmTest_DrawSemanticHighlights( buffer_number, [
        \ {
        \   'type': 'variable',
        \   'range': {
        \     'start': {
        \       'line_num': 1,
        \       'column_num': 1,
        \     },
        \     'end': {
        \       'line_num': 1,
        \       'column_num': 6,
        \     },
        \   },
        \ },
        \ ] )
  call YcmTest_DrawSemanticHighlights( buffer_number, [] )

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedSemanticHighlights( buffer_number ) )
  call assert_true(
        \ YcmTest_UnrelatedDecorationExists(
        \   buffer_number,
        \   unrelated_decoration ) )

  silent %bwipe!
endfunction


function! Test_SemanticHighlights_CustomTokenTypeUsesDefinedHighlight()
  if !py3eval( 'YCM_TEST_SEMANTIC_HIGHLIGHTING_SUPPORTED' )
    throw 'Skipped: semantic highlighting is not supported'
  endif

  new
  call setline( 1, 'custom' )

  call YcmTest_DrawSemanticHighlights( bufnr(), [
        \ {
        \   'type': 'ycmTestCustom',
        \   'range': {
        \     'start': {
        \       'line_num': 1,
        \       'column_num': 1,
        \     },
        \     'end': {
        \       'line_num': 1,
        \       'column_num': 7,
        \     },
        \   },
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 1,
        \     'length': 6,
        \     'type': 'YCM_HL_ycmTestCustom',
        \   },
        \ ],
        \ YcmTest_GetRenderedSemanticHighlights( bufnr() ) )
  call assert_equal(
        \ 'ErrorMsg',
        \ YcmTest_GetCustomSemanticHighlight() )

  silent %bwipe!
endfunction


function! Test_SemanticHighlights_RedrawReplacesOldHighlights()
  if !py3eval( 'YCM_TEST_SEMANTIC_HIGHLIGHTING_SUPPORTED' )
    throw 'Skipped: semantic highlighting is not supported'
  endif

  new
  call setline( 1, [ 'first', 'second' ] )

  call YcmTest_DrawSemanticHighlights( bufnr(), [
        \ {
        \   'type': 'variable',
        \   'range': {
        \     'start': {
        \       'line_num': 1,
        \       'column_num': 1,
        \     },
        \     'end': {
        \       'line_num': 1,
        \       'column_num': 6,
        \     },
        \   },
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 1,
        \     'length': 5,
        \     'type': 'YCM_HL_variable',
        \   },
        \ ],
        \ YcmTest_GetRenderedSemanticHighlights( bufnr() ) )

  call YcmTest_DrawSemanticHighlights( bufnr(), [
        \ {
        \   'type': 'variable',
        \   'range': {
        \     'start': {
        \       'line_num': 2,
        \       'column_num': 1,
        \     },
        \     'end': {
        \       'line_num': 2,
        \       'column_num': 7,
        \     },
        \   },
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 2,
        \     'column': 1,
        \     'length': 6,
        \     'type': 'YCM_HL_variable',
        \   },
        \ ],
        \ YcmTest_GetRenderedSemanticHighlights( bufnr() ) )

  call YcmTest_DrawSemanticHighlights( bufnr(), [] )

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedSemanticHighlights( bufnr() ) )

  silent %bwipe!
endfunction


function! Test_SemanticHighlights_UnsupportedTypeWarnsOnce()
  if !py3eval( 'YCM_TEST_SEMANTIC_HIGHLIGHTING_SUPPORTED' )
    throw 'Skipped: semantic highlighting is not supported'
  endif

  new
  call setline( 1, 'missing' )

  let missing_tokens = [
        \ {
        \   'type': 'ycmTestMissing',
        \   'range': {
        \     'start': {
        \       'line_num': 1,
        \       'column_num': 1,
        \     },
        \     'end': {
        \       'line_num': 1,
        \       'column_num': 8,
        \     },
        \   },
        \ },
        \ ]

  call YcmTest_DrawSemanticHighlights(
        \ bufnr(),
        \ missing_tokens )
  call YcmTest_DrawSemanticHighlights(
        \ bufnr(),
        \ missing_tokens )

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedSemanticHighlights( bufnr() ) )

  let expected_message =
        \ 'Token type ycmTestMissing not supported. ' .
        \ 'Define property type YCM_HL_ycmTestMissing. ' .
        \ 'See :help youcompleteme-customising-highlight-groups'
  call assert_equal(
        \ 1,
        \ count( execute( 'messages' ), expected_message ) )

  " The warning is expected by this test. Prevent the test runner from
  " treating it as unexpected message output.
  messages clear
  silent %bwipe!
endfunction
