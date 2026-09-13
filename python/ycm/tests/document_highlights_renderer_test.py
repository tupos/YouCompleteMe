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

from unittest import TestCase
from unittest.mock import call, patch

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from ycm import document_highlights_renderer


_RANGE: dict[ str, dict[ str, object ] ] = {
  'start': {
    'line_num': 2,
    'column_num': 3,
  },
  'end': {
    'line_num': 2,
    'column_num': 7,
  },
}


class DocumentHighlightsRendererTest( TestCase ):
  @patch(
    'ycm.document_highlights_renderer.vimsupport.AddTextPropertyType'
  )
  @patch(
    'ycm.document_highlights_renderer.vimsupport.GetTextPropertyTypes',
    return_value = [ 'YcmDocumentHighlightText' ]
  )
  def test_VimInitialiseDefinesMissingPropertyTypes(
      self,
      get_text_property_types: object,
      add_text_property_type: object
  ) -> None:
    renderer = (
      document_highlights_renderer.VimDocumentHighlightsRenderer()
    )

    with patch(
        'ycm.document_highlights_renderer.DocumentHighlightsSupported',
        return_value = True
    ):
      self.assertTrue( renderer.Initialise() )

    self.assertEqual(
      [
        call(
          'YcmDocumentHighlightRead',
          highlight = 'YcmDocumentHighlightRead',
          combine = 1,
          override = 1,
          priority = 200
        ),
        call(
          'YcmDocumentHighlightWrite',
          highlight = 'YcmDocumentHighlightWrite',
          combine = 1,
          override = 1,
          priority = 200
        ),
      ],
      add_text_property_type.call_args_list
    )


  @patch(
    'ycm.document_highlights_renderer.vimsupport.AddTextPropertyForRange'
  )
  @patch(
    'ycm.document_highlights_renderer.vimsupport.ClearTextProperties'
  )
  def test_VimRenderMapsKindsAndClearsOnlyDocumentHighlights(
      self,
      clear_text_properties: object,
      add_text_property_for_range: object
  ) -> None:
    renderer = (
      document_highlights_renderer.VimDocumentHighlightsRenderer()
    )

    renderer.Render(
      4,
      [
        { 'kind': 'Read', 'range': _RANGE },
        { 'kind': 'Write', 'range': _RANGE },
        { 'kind': 'unknown', 'range': _RANGE },
      ]
    )

    clear_text_properties.assert_called_once_with(
      4,
      prop_types = [
        'YcmDocumentHighlightText',
        'YcmDocumentHighlightRead',
        'YcmDocumentHighlightWrite',
      ]
    )
    self.assertEqual(
      [
        call( 4, None, 'YcmDocumentHighlightRead', _RANGE ),
        call( 4, None, 'YcmDocumentHighlightWrite', _RANGE ),
        call( 4, None, 'YcmDocumentHighlightText', _RANGE ),
      ],
      add_text_property_for_range.call_args_list
    )


  @patch( 'ycm.document_highlights_renderer.vim.eval', return_value = 17 )
  def test_NeovimRenderUsesDedicatedNamespaceAndByteRanges(
      self,
      vim_eval: object
  ) -> None:
    renderer = (
      document_highlights_renderer.NeovimDocumentHighlightsRenderer()
    )
    vim_eval.reset_mock()

    renderer.Render(
      4,
      [ { 'kind': 'Read', 'range': _RANGE } ]
    )

    self.assertEqual(
      [
        call(
          'nvim_buf_clear_namespace( 4, '
          '                          17, '
          '                          0, '
          '                          -1 )'
        ),
        call(
          'nvim_buf_set_extmark( 4, '
          '                      17, '
          '                      1, '
          '                      2, '
          '                      {"end_row": 1, "end_col": 6, '
          '"hl_group": "YcmDocumentHighlightRead", "priority": 200} )'
        ),
      ],
      vim_eval.call_args_list
    )
