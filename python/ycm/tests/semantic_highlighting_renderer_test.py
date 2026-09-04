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
from unittest.mock import MagicMock, patch

from ycm.tests.test_utils import MockVimModule, VimError
MockVimModule()

from ycm import semantic_highlighting_renderer


class ComparisonCountingString( str ):
  comparisons: int = 0

  def __eq__( self, other: object ) -> bool:
    ComparisonCountingString.comparisons += 1
    return super().__eq__( other )


  def __hash__( self ) -> int:
    return int( self.removeprefix( 'YCM_HL_missing_' ) )


class SemanticHighlightingRendererTest( TestCase ):

  @patch(
    'ycm.semantic_highlighting_renderer.vimsupport.ClearTextProperties'
  )
  @patch(
    'ycm.semantic_highlighting_renderer.vimsupport.'
    'AddTextPropertyForRange',
    side_effect = VimError( 'E971: Property type does not exist' )
  )
  def test_VimRenderDoesNotScanPreviouslyMissingPropertyTypes(
      self,
      add_text_property_for_range: MagicMock,
      clear_text_properties: MagicMock ) -> None:
    renderer: (
      semantic_highlighting_renderer.VimSemanticHighlightingRenderer
    ) = semantic_highlighting_renderer.VimSemanticHighlightingRenderer( {} )
    property_range: semantic_highlighting_renderer.SemanticRange = {
      'start': {
        'line_num': 1,
        'column_num': 1,
      },
      'end': {
        'line_num': 1,
        'column_num': 2,
      },
    }
    property_type_count: int = 100
    property_types: list[ ComparisonCountingString ] = [
      ComparisonCountingString( f'YCM_HL_missing_{ index }' )
      for index in range( property_type_count )
    ]
    highlights: list[
      semantic_highlighting_renderer.SemanticHighlight
    ] = [
      ( property_type, property_range )
      for property_type in property_types
    ]

    ComparisonCountingString.comparisons = 0
    missing_property_types: list[ str ] = renderer.Render( 1, highlights )

    self.assertEqual( 0, ComparisonCountingString.comparisons )
    self.assertEqual( property_types, missing_property_types )
    self.assertEqual(
      property_type_count,
      add_text_property_for_range.call_count
    )
    clear_text_properties.assert_called_once()
