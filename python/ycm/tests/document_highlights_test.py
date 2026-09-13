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
from unittest.mock import patch

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from hamcrest import assert_that, empty, equal_to

from ycm.client.request_operation import RequestOperationManager
from ycm.document_highlights import ( DocumentHighlight,
                                      DocumentHighlights,
                                      DocumentHighlightsRenderer,
                                      DocumentHighlightsRequestProtocol )


def _IgnoreCancellation(
    request_data: dict[ str, object ]
) -> None:
  pass


class _RecordingRenderer:
  def __init__( self ) -> None:
    self.cleared_buffers: list[ int ] = []
    self.rendered: list[ tuple[ int, list[ DocumentHighlight ] ] ] = []
    self.initialised: bool = False


  def Initialise( self ) -> bool:
    self.initialised = True
    return True


  def Clear( self, buffer_number: int ) -> None:
    self.cleared_buffers.append( buffer_number )


  def Render(
      self,
      buffer_number: int,
      highlights: list[ DocumentHighlight ]
  ) -> None:
    self.rendered.append( ( buffer_number, highlights ) )


class _Request:
  def __init__( self, request_data: dict[ str, object ] ) -> None:
    self.request_data = request_data
    self.started: bool = False
    self.done: bool = False
    self.reset: bool = False
    self.response: list[ DocumentHighlight ] = []


  def Start( self ) -> None:
    self.started = True


  def Done( self ) -> bool:
    return self.done


  def Reset( self ) -> None:
    self.reset = True


  def Response( self ) -> list[ DocumentHighlight ]:
    return self.response


class _DocumentHighlightsForTest( DocumentHighlights ):
  def __init__(
      self,
      renderer: DocumentHighlightsRenderer
  ) -> None:
    super().__init__(
      RequestOperationManager( _IgnoreCancellation ),
      renderer
    )
    self.requests: list[ _Request ] = []


  def _NewRequest(
      self,
      request_data: dict[ str, object ]
  ) -> DocumentHighlightsRequestProtocol:
    request = _Request( request_data )
    self.requests.append( request )
    return request


class DocumentHighlightsTest( TestCase ):
  def test_InitialiseDelegatesToRenderer( self ) -> None:
    renderer = _RecordingRenderer()
    highlights = _DocumentHighlightsForTest( renderer )

    assert_that( highlights.Initialise(), equal_to( True ) )
    assert_that( renderer.initialised, equal_to( True ) )


  @patch(
    'ycm.document_highlights.vimsupport.CurrentLineAndColumn',
    return_value = ( 2, 3 )
  )
  @patch(
    'ycm.document_highlights.vimsupport.GetBufferChangedTick',
    return_value = 7
  )
  @patch(
    'ycm.document_highlights.vimsupport.GetCurrentBufferNumber',
    return_value = 4
  )
  @patch(
    'ycm.document_highlights.BuildRequestData',
    side_effect = [ { 'request': 1 }, { 'request': 2 } ]
  )
  def test_RequestReplacesPendingRequest(
      self,
      build_request_data: object,
      get_current_buffer_number: object,
      get_buffer_changed_tick: object,
      current_line_and_column: object
  ) -> None:
    renderer = _RecordingRenderer()
    highlights = _DocumentHighlightsForTest( renderer )

    highlights.Request()
    first_request = highlights.requests[ 0 ]
    highlights.Request()
    second_request = highlights.requests[ 1 ]

    assert_that( len( highlights.requests ), equal_to( 2 ) )
    assert_that( first_request.started, equal_to( True ) )
    assert_that( first_request.reset, equal_to( True ) )
    assert_that( second_request.started, equal_to( True ) )
    assert_that(
      second_request.request_data,
      equal_to( { 'request': 2 } )
    )

    first_request.done = True
    first_request.response = [ { 'kind': 'Read', 'range': {} } ]

    assert_that( highlights.Ready(), equal_to( False ) )
    highlights.Update()
    assert_that( renderer.rendered, empty() )


  @patch(
    'ycm.document_highlights.vimsupport.CurrentLineAndColumn',
    return_value = ( 2, 3 )
  )
  @patch(
    'ycm.document_highlights.vimsupport.GetBufferChangedTick',
    return_value = 7
  )
  @patch(
    'ycm.document_highlights.vimsupport.GetCurrentBufferNumber',
    return_value = 4
  )
  @patch(
    'ycm.document_highlights.BuildRequestData',
    return_value = {}
  )
  def test_UpdateRendersCurrentResponseAndClearRemovesIt(
      self,
      build_request_data: object,
      get_current_buffer_number: object,
      get_buffer_changed_tick: object,
      current_line_and_column: object
  ) -> None:
    renderer = _RecordingRenderer()
    highlights = _DocumentHighlightsForTest( renderer )
    highlights.Request()
    request = highlights.requests[ 0 ]
    response: list[ DocumentHighlight ] = [ {
      'kind': 'Text',
      'range': {
        'start': { 'line_num': 2, 'column_num': 1 },
        'end': { 'line_num': 2, 'column_num': 5 },
      },
    } ]
    request.response = response
    request.done = True

    assert_that( highlights.Ready(), equal_to( True ) )
    highlights.Update()

    assert_that(
      renderer.rendered,
      equal_to( [ ( 4, response ) ] )
    )

    highlights.Clear()

    assert_that( renderer.cleared_buffers, equal_to( [ 4 ] ) )


  def test_UpdateDiscardsResponseForStaleEditorState( self ) -> None:
    scenarios = (
      {
        'name': 'buffer',
        'current_buffer': 5,
        'current_tick': 7,
        'current_cursor': ( 2, 3 ),
      },
      {
        'name': 'changed tick',
        'current_buffer': 4,
        'current_tick': 8,
        'current_cursor': ( 2, 3 ),
      },
      {
        'name': 'cursor',
        'current_buffer': 4,
        'current_tick': 7,
        'current_cursor': ( 2, 4 ),
      },
    )

    for scenario in scenarios:
      with self.subTest( scenario[ 'name' ] ):
        renderer = _RecordingRenderer()
        highlights = _DocumentHighlightsForTest( renderer )

        with patch(
            'ycm.document_highlights.BuildRequestData',
            return_value = {}
        ):
          with patch(
              'ycm.document_highlights.vimsupport.GetCurrentBufferNumber',
              return_value = 4
          ):
            with patch(
                'ycm.document_highlights.vimsupport.GetBufferChangedTick',
                return_value = 7
            ):
              with patch(
                  'ycm.document_highlights.vimsupport.CurrentLineAndColumn',
                  return_value = ( 2, 3 )
              ):
                highlights.Request()

        request = highlights.requests[ 0 ]
        request.done = True
        request.response = [ { 'kind': 'Read', 'range': {} } ]

        with patch(
            'ycm.document_highlights.vimsupport.GetCurrentBufferNumber',
            return_value = scenario[ 'current_buffer' ]
        ):
          with patch(
              'ycm.document_highlights.vimsupport.GetBufferChangedTick',
              return_value = scenario[ 'current_tick' ]
          ):
            with patch(
                'ycm.document_highlights.vimsupport.CurrentLineAndColumn',
                return_value = scenario[ 'current_cursor' ]
            ):
              highlights.Update()

        assert_that( renderer.rendered, empty() )
