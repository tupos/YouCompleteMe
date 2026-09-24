# Copyright (C) 2026 YouCompleteMe contributors
#
# This file is part of YouCompleteMe.
#
# YouCompleteMe is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# YouCompleteMe is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with YouCompleteMe.  If not, see <http://www.gnu.org/licenses/>.

from hamcrest import assert_that
from unittest import TestCase
from unittest.mock import call, MagicMock, patch

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from ycm import virtual_text


HIGHLIGHT_GROUPS: dict[ str, str ] = {
  'YCM_INLAY_UNKNOWN': 'YcmInlayHint',
  'YCM_INLAY_PADDING': 'YcmInvisible',
  'YCM_INLAY_Type': 'YcmInlayHint',
}


class RecordingVirtualTextRenderer:

  def __init__( self ) -> None:
    self.initialise_calls: int = 0
    self.clear_calls: list[ int ] = []
    self.render_calls: list[
      tuple[ int, int, int, list[ virtual_text.VirtualTextChunk ] ]
    ] = []


  def Initialise( self ) -> bool:
    self.initialise_calls += 1
    return True


  def Clear( self, buffer_number: int ) -> None:
    self.clear_calls.append( buffer_number )


  def Render(
      self,
      buffer_number: int,
      line_number: int,
      column_number: int,
      chunks: list[ virtual_text.VirtualTextChunk ] ) -> None:
    self.render_calls.append(
      ( buffer_number, line_number, column_number, chunks )
    )


  def RenderAtEndOfLine(
      self,
      buffer_number: int,
      line_number: int,
      chunks: list[ virtual_text.VirtualTextChunk ] ) -> None:
    raise AssertionError( 'Unexpected end-of-line render' )


class VirtualTextTest( TestCase ):

  @patch( 'ycm.virtual_text.vimsupport.GetTextPropertyTypes' )
  @patch( 'ycm.virtual_text.vimsupport.EditorFeatureSupported',
          return_value = False )
  def test_VimInitialiseRejectsUnsupportedVersion(
      self,
      editor_feature_supported: MagicMock,
      get_text_property_types: MagicMock ) -> None:
    renderer: virtual_text.VimVirtualTextRenderer = (
      virtual_text.VimVirtualTextRenderer( HIGHLIGHT_GROUPS )
    )

    assert_that( not renderer.Initialise() )
    editor_feature_supported.assert_called_once_with(
      'virtual_text' )
    get_text_property_types.assert_not_called()


  @patch(
    'ycm.virtual_text.vimsupport.AddTextPropertyForRange'
  )
  def test_VimRenderAtEndOfLineUsesWrappedVirtualText(
      self,
      add_text_property_for_range: MagicMock ) -> None:
    renderer: virtual_text.VimVirtualTextRenderer = (
      virtual_text.VimVirtualTextRenderer( HIGHLIGHT_GROUPS )
    )

    renderer.RenderAtEndOfLine(
      3,
      7,
      [
        ( '  ', 'YcmVirtDiagPadding' ),
        ( '⚠ bad', 'YcmVirtDiagError' ),
      ]
    )

    property_range: dict[ str, dict[ str, object ] ] = {
      'start': {
        'line_num': 7,
        'column_num': 0,
      }
    }
    add_text_property_for_range.assert_has_calls( [
      call(
        3,
        None,
        'YcmVirtDiagPadding',
        property_range,
        {
          'text_align': 'after',
          'text_wrap': 'wrap',
          'text': '  ',
        }
      ),
      call(
        3,
        None,
        'YcmVirtDiagError',
        property_range,
        {
          'text_align': 'after',
          'text_wrap': 'wrap',
          'text': '⚠ bad',
        }
      ),
    ] )


  @patch( 'ycm.virtual_text.vimsupport.EditorFeatureSupported',
          return_value = False )
  @patch( 'ycm.virtual_text.vimsupport.GetIntValue', return_value = 42 )
  @patch( 'ycm.virtual_text.vim.command' )
  def test_NeovimInitialiseRejectsUnsupportedVersion(
      self,
      vim_command: MagicMock,
      get_int_value: MagicMock,
      editor_feature_supported: MagicMock ) -> None:
    renderer: virtual_text.NeovimVirtualTextRenderer = (
      virtual_text.NeovimVirtualTextRenderer(
        'ycm_inlay_hints',
        HIGHLIGHT_GROUPS
      )
    )

    assert_that( not renderer.Initialise() )
    editor_feature_supported.assert_called_once_with(
      'virtual_text' )
    vim_command.assert_not_called()


  @patch( 'ycm.virtual_text.vimsupport.GetIntValue', return_value = 42 )
  @patch( 'ycm.virtual_text.vim.eval' )
  @patch(
    'ycm.virtual_text.vim.buffers',
    { 3: [ '', '', '', '', '', '', 'λx' ] }
  )
  def test_NeovimRenderAtEndOfLineUsesInlineExtmarkAtLineEnd(
      self,
      vim_eval: MagicMock,
      get_int_value: MagicMock ) -> None:
    renderer: virtual_text.NeovimVirtualTextRenderer = (
      virtual_text.NeovimVirtualTextRenderer(
        'ycm_diagnostic_virtual_text',
        HIGHLIGHT_GROUPS
      )
    )

    renderer.RenderAtEndOfLine(
      3,
      7,
      [
        ( '  ', 'YcmVirtDiagPadding' ),
        ( '⚠ bad', 'YcmVirtDiagError' ),
      ]
    )

    get_int_value.assert_called_once_with(
      "nvim_create_namespace( 'ycm_diagnostic_virtual_text' )"
    )
    vim_eval.assert_called_once_with(
      'nvim_buf_set_extmark( 3, '
      '                      42, '
      '                      6, '
      '                      3, '
      '                      {"virt_text": [["  ", "YcmVirtDiagPadding"], '
      '["\\u26a0 bad", "YcmVirtDiagError"]], "virt_text_pos": "inline"} )'
    )


  def test_DoubleBufferedRendererAddsOnlyPreviouslyUnseenDecorations(
      self ) -> None:
    first_renderer = RecordingVirtualTextRenderer()
    second_renderer = RecordingVirtualTextRenderer()
    renderer = virtual_text.DoubleBufferedVirtualTextRenderer( (
      first_renderer,
      second_renderer,
    ) )
    first: virtual_text.VirtualTextDecoration = (
      1,
      6,
      ( ( ': first', 'YCM_INLAY_Type' ), ),
    )
    retained: virtual_text.VirtualTextDecoration = (
      2,
      7,
      ( ( ': retained', 'YCM_INLAY_Type' ), ),
    )
    new: virtual_text.VirtualTextDecoration = (
      3,
      4,
      ( ( ': new', 'YCM_INLAY_Type' ), ),
    )

    self.assertTrue( renderer.Initialise() )
    renderer.Render(
      3,
      [ first, retained ],
      False
    )

    self.assertEqual( 1, first_renderer.initialise_calls )
    self.assertEqual( 1, second_renderer.initialise_calls )
    self.assertEqual( [ 3 ], first_renderer.clear_calls )
    self.assertEqual( [ 3 ], second_renderer.clear_calls )
    self.assertEqual(
      [
        ( 3, 1, 6, [ ( ': first', 'YCM_INLAY_Type' ) ] ),
        ( 3, 2, 7, [ ( ': retained', 'YCM_INLAY_Type' ) ] ),
      ],
      second_renderer.render_calls
    )

    first_renderer.clear_calls.clear()
    second_renderer.clear_calls.clear()
    second_renderer.render_calls.clear()

    renderer.Render(
      3,
      [ retained, new ],
      True
    )

    self.assertEqual( [], first_renderer.clear_calls )
    self.assertEqual( [], second_renderer.clear_calls )
    self.assertEqual(
      [ ( 3, 3, 4, [ ( ': new', 'YCM_INLAY_Type' ) ] ) ],
      second_renderer.render_calls
    )
