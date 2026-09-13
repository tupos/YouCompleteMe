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

from concurrent.futures import Future
from unittest import TestCase
from unittest.mock import patch

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from hamcrest import assert_that, empty, equal_to

from ycm.client.base_request import BaseRequest
from ycm.client.document_highlights_request import DocumentHighlightsRequest
from ycm.client.request_operation import ( RequestOperationManager,
                                           YCM_OPERATION_ID )


def _IgnoreCancellation(
    request_data: dict[ str, object ]
) -> None:
  pass


class DocumentHighlightsRequestTest( TestCase ):
  def test_StartAndResetUseCancellableDocumentHighlightsEndpoint(
      self
  ) -> None:
    cancellation_requests: list[ dict[ str, object ] ] = []
    manager = RequestOperationManager( cancellation_requests.append )
    request_data: dict[ str, object ] = {}
    request = DocumentHighlightsRequest( request_data, manager )
    future: Future[ object ] = Future()

    with patch.object(
        BaseRequest,
        'PostDataToHandlerAsync',
        return_value = future
    ) as post_request:
      request.Start()

    assert_that(
      request_data,
      equal_to( {
        YCM_OPERATION_ID: 0,
      } )
    )
    assert_that(
      post_request.call_args.args[ 1 ],
      equal_to( 'document_highlights' )
    )

    request.Reset()

    assert_that(
      cancellation_requests,
      equal_to( [ {
        YCM_OPERATION_ID: 0,
      } ] )
    )


  def test_ResponseReturnsDocumentHighlights( self ) -> None:
    request = DocumentHighlightsRequest(
      {},
      RequestOperationManager( _IgnoreCancellation )
    )
    request._response_future = Future()
    document_highlights: list[ dict[ str, object ] ] = [ {
      'kind': 'Read',
      'range': {
        'start': {
          'line_num': 1,
          'column_num': 1,
        },
        'end': {
          'line_num': 1,
          'column_num': 4,
        },
      },
    } ]

    with patch.object(
        request,
        'HandleFuture',
        return_value = {
          'document_highlights': document_highlights,
          'errors': [],
        }
    ):
      assert_that(
        request.Response(),
        equal_to( document_highlights )
      )


  def test_ResponseWithoutFutureIsEmpty( self ) -> None:
    request = DocumentHighlightsRequest(
      {},
      RequestOperationManager( _IgnoreCancellation )
    )

    assert_that( request.Response(), empty() )
