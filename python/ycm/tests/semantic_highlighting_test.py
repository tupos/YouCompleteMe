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
from unittest.mock import MagicMock

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from ycm import semantic_highlighting
from ycm.client.request_operation import RequestOperationManager
from ycm.semantic_highlighting_renderer import SemanticHighlight


class RecordingRenderer:

  def __init__( self ) -> None:
    self.rendered: list[ tuple[ int, list[ SemanticHighlight ] ] ] = []


  def Initialise( self ) -> bool:
    return True


  def Render(
      self,
      buffer_number: int,
      highlights: list[ SemanticHighlight ]
  ) -> list[ str ]:
    self.rendered.append( ( buffer_number, highlights ) )
    return []


class SemanticHighlightingTest( TestCase ):

  def test_DrawUsesReportedCoverageInsteadOfSparseTokenBounds( self ) -> None:
    renderer = RecordingRenderer()
    highlighter = semantic_highlighting.SemanticHighlighting(
      4,
      RequestOperationManager( MagicMock() ),
      renderer
    )
    requested_range: dict[ str, dict[ str, object ] ] = {
      'start': {
        'line_num': 2853,
        'column_num': 1,
      },
      'end': {
        'line_num': 2921,
        'column_num': 1,
      },
    }
    highlighter._last_requested_range = requested_range
    first_token_range: dict[ str, dict[ str, object ] ] = {
      'start': {
        'line_num': 1,
        'column_num': 30,
      },
      'end': {
        'line_num': 1,
        'column_num': 35,
      },
    }
    last_token_range: dict[ str, dict[ str, object ] ] = {
      'start': {
        'line_num': 3020,
        'column_num': 1,
      },
      'end': {
        'line_num': 3021,
        'column_num': 1,
      },
    }
    highlighter._latest_response = {
      'covered_range': requested_range,
      'tokens': [
        {
          'type': 'variable',
          'range': first_token_range,
        },
        {
          'type': 'comment',
          'range': last_token_range,
        },
      ],
    }

    highlighter._Draw()

    self.assertEqual( requested_range, highlighter._last_requested_range )
    self.assertEqual(
      [
        (
          4,
          [
            ( 'YCM_HL_variable', first_token_range ),
            ( 'YCM_HL_comment', last_token_range ),
          ]
        )
      ],
      renderer.rendered
    )
