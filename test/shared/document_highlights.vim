let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )

highlight link YcmDocumentHighlightRead ErrorMsg

let s:python_paths = [
      \ s:repository_directory . '/python',
      \ s:repository_directory . '/third_party/ycmd',
      \ ]
execute 'py3 import sys; sys.path[ 0:0 ] = ' . string( s:python_paths )

py3 << EOF
import json
import vim

from ycm.document_highlights import ( DocumentHighlight,
                                      DocumentHighlightsRenderer )
from ycm.document_highlights_renderer import (
  CreateDocumentHighlightsRenderer )


YCM_TEST_DOCUMENT_HIGHLIGHTS_RENDERER: DocumentHighlightsRenderer = (
  CreateDocumentHighlightsRenderer()
)
YCM_TEST_DOCUMENT_HIGHLIGHTS_SUPPORTED: bool = (
  YCM_TEST_DOCUMENT_HIGHLIGHTS_RENDERER.Initialise()
)


def YcmTestDrawDocumentHighlights(
    buffer_number: int,
    highlights: list[ DocumentHighlight ]
) -> bool:
  if not YCM_TEST_DOCUMENT_HIGHLIGHTS_SUPPORTED:
    raise RuntimeError(
      'Document highlights are not supported by this editor'
    )

  YCM_TEST_DOCUMENT_HIGHLIGHTS_RENDERER.Render(
    buffer_number,
    highlights
  )
  return True
EOF


function! YcmTest_DrawDocumentHighlights(
      \ buffer_number,
      \ highlights ) abort
  let highlights_json = json_encode( a:highlights )
  call py3eval(
        \ 'YcmTestDrawDocumentHighlights('
        \ . 'int( vim.eval( "a:buffer_number" ) ), '
        \ . 'json.loads( vim.eval( "highlights_json" ) ) )' )
endfunction


function! SetUp() abort
  let g:ycm_use_clangd = 1
  let g:ycm_auto_hover = ''
  let g:ycm_enable_document_highlights = 1
  call youcompleteme#test#setup#SetUp()
endfunction


function! TearDown() abort
  call youcompleteme#test#setup#CleanUp()
endfunction


function! Test_DocumentHighlights_RendersKindsAndByteRanges() abort
  if !py3eval( 'YCM_TEST_DOCUMENT_HIGHLIGHTS_SUPPORTED' )
    throw 'Skipped: document highlights are not supported'
  endif

  new
  call setline( 1, [ 'føo', 'read', 'write' ] )
  let buffer_before = getline( 1, '$' )

  call YcmTest_DrawDocumentHighlights( bufnr(), [
        \ {
        \   'kind': 'Text',
        \   'range': {
        \     'start': { 'line_num': 1, 'column_num': 1 },
        \     'end': { 'line_num': 1, 'column_num': 5 },
        \   },
        \ },
        \ {
        \   'kind': 'Read',
        \   'range': {
        \     'start': { 'line_num': 2, 'column_num': 1 },
        \     'end': { 'line_num': 2, 'column_num': 5 },
        \   },
        \ },
        \ {
        \   'kind': 'Write',
        \   'range': {
        \     'start': { 'line_num': 3, 'column_num': 1 },
        \     'end': { 'line_num': 3, 'column_num': 6 },
        \   },
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 1,
        \     'length': 4,
        \     'group': 'YcmDocumentHighlightText',
        \   },
        \   {
        \     'line': 2,
        \     'column': 1,
        \     'length': 4,
        \     'group': 'YcmDocumentHighlightRead',
        \   },
        \   {
        \     'line': 3,
        \     'column': 1,
        \     'length': 5,
        \     'group': 'YcmDocumentHighlightWrite',
        \   },
        \ ],
        \ YcmTest_GetRenderedDocumentHighlights( bufnr() ) )
  call assert_equal( buffer_before, getline( 1, '$' ) )

  silent %bwipe!
endfunction


function! Test_DocumentHighlights_ReplacesAndClearsRendering() abort
  if !py3eval( 'YCM_TEST_DOCUMENT_HIGHLIGHTS_SUPPORTED' )
    throw 'Skipped: document highlights are not supported'
  endif

  new
  call setline( 1, [ 'first', 'second' ] )

  call YcmTest_DrawDocumentHighlights( bufnr(), [
        \ {
        \   'kind': 'Text',
        \   'range': {
        \     'start': { 'line_num': 1, 'column_num': 1 },
        \     'end': { 'line_num': 1, 'column_num': 6 },
        \   },
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 1,
        \     'column': 1,
        \     'length': 5,
        \     'group': 'YcmDocumentHighlightText',
        \   },
        \ ],
        \ YcmTest_GetRenderedDocumentHighlights( bufnr() ) )

  call YcmTest_DrawDocumentHighlights( bufnr(), [
        \ {
        \   'kind': 'Write',
        \   'range': {
        \     'start': { 'line_num': 2, 'column_num': 1 },
        \     'end': { 'line_num': 2, 'column_num': 7 },
        \   },
        \ },
        \ ] )

  call assert_equal(
        \ [
        \   {
        \     'line': 2,
        \     'column': 1,
        \     'length': 6,
        \     'group': 'YcmDocumentHighlightWrite',
        \   },
        \ ],
        \ YcmTest_GetRenderedDocumentHighlights( bufnr() ) )

  call YcmTest_DrawDocumentHighlights( bufnr(), [] )
  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedDocumentHighlights( bufnr() ) )

  silent %bwipe!
endfunction


function! Test_DocumentHighlights_ClearPreservesUnrelatedDecorations() abort
  if !py3eval( 'YCM_TEST_DOCUMENT_HIGHLIGHTS_SUPPORTED' )
    throw 'Skipped: document highlights are not supported'
  endif

  new
  call setline( 1, 'value' )
  let buffer_number = bufnr()
  let unrelated_decoration =
        \ YcmTest_AddUnrelatedDocumentHighlightDecoration(
        \   buffer_number )

  call YcmTest_DrawDocumentHighlights( buffer_number, [
        \ {
        \   'kind': 'Read',
        \   'range': {
        \     'start': { 'line_num': 1, 'column_num': 1 },
        \     'end': { 'line_num': 1, 'column_num': 6 },
        \   },
        \ },
        \ ] )
  call YcmTest_DrawDocumentHighlights( buffer_number, [] )

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedDocumentHighlights( buffer_number ) )
  call assert_true(
        \ YcmTest_UnrelatedDocumentHighlightDecorationExists(
        \   buffer_number,
        \   unrelated_decoration ) )

  silent %bwipe!
endfunction


function! Test_DocumentHighlights_PreservesCustomHighlight() abort
  call assert_equal(
        \ 'ErrorMsg',
        \ synIDattr(
        \   synIDtrans( hlID( 'YcmDocumentHighlightRead' ) ),
        \   'name' ) )
endfunction


function!
      \ Test_DocumentHighlights_RepeatedCursorHoldPreservesAndCursorMovedClears()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/document_highlights.cpp',
        \ {} )
  call cursor( 4, 3 )

  doautocmd CursorHold
  call WaitForAssert( { ->
        \ assert_equal(
        \   -1,
        \   youcompleteme#Test_GetPollers().document_highlights.id ) },
        \ 10000 )

  let highlights = YcmTest_GetRenderedDocumentHighlights( bufnr() )
  call assert_equal(
        \ [
        \   [ 3, 7, 5 ],
        \   [ 4, 3, 5 ],
        \   [ 5, 10, 5 ],
        \ ],
        \ map(
        \   copy( highlights ),
        \   { _, highlight ->
        \     [
        \       highlight.line,
        \       highlight.column,
        \       highlight.length,
        \     ] } ) )

  doautocmd CursorHold
  call assert_equal(
        \ highlights,
        \ YcmTest_GetRenderedDocumentHighlights( bufnr() ) )
  call WaitForAssert( { ->
        \ assert_equal(
        \   -1,
        \   youcompleteme#Test_GetPollers().document_highlights.id ) },
        \ 10000 )

  call cursor( 1, 1 )
  doautocmd CursorMoved

  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedDocumentHighlights( bufnr() ) )
  call assert_equal(
        \ -1,
        \ youcompleteme#Test_GetPollers().document_highlights.id )
endfunction


function! Test_DocumentHighlights_BufferLocalOptionDisablesRequests()
  call youcompleteme#test#setup#OpenFile(
        \ '/test/testdata/cpp/document_highlights.cpp',
        \ {} )
  let b:ycm_enable_document_highlights = 0
  call cursor( 4, 3 )

  doautocmd CursorHold

  call assert_equal(
        \ -1,
        \ youcompleteme#Test_GetPollers().document_highlights.id )
  call assert_equal(
        \ [],
        \ YcmTest_GetRenderedDocumentHighlights( bufnr() ) )
endfunction
