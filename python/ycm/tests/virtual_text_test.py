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


class VirtualTextTest( TestCase ):

  @patch( 'ycm.virtual_text.vimsupport.GetTextPropertyTypes' )
  @patch( 'ycm.virtual_text.vimsupport.VimVersionAtLeast',
          return_value = False )
  def test_VimInitialiseRejectsUnsupportedVersion(
      self,
      vim_version_at_least: MagicMock,
      get_text_property_types: MagicMock ) -> None:
    renderer: virtual_text.VimVirtualTextRenderer = (
      virtual_text.VimVirtualTextRenderer( HIGHLIGHT_GROUPS )
    )

    assert_that( not renderer.Initialise() )
    vim_version_at_least.assert_called_once_with( '9.0.214' )
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


  @patch( 'ycm.virtual_text.vimsupport.GetBoolValue',
          return_value = False )
  @patch( 'ycm.virtual_text.vimsupport.GetIntValue', return_value = 42 )
  @patch( 'ycm.virtual_text.vim.command' )
  def test_NeovimInitialiseRejectsUnsupportedVersion(
      self,
      vim_command: MagicMock,
      get_int_value: MagicMock,
      get_bool_value: MagicMock ) -> None:
    renderer: virtual_text.NeovimVirtualTextRenderer = (
      virtual_text.NeovimVirtualTextRenderer(
        'ycm_inlay_hints',
        HIGHLIGHT_GROUPS
      )
    )

    assert_that( not renderer.Initialise() )
    get_bool_value.assert_called_once_with( "has( 'nvim-0.10' )" )
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
