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

from hamcrest import assert_that, equal_to

from ycm.client.base_request import BaseRequest
from ycm.client.inlay_hints_request import InlayHintsRequest
from ycm.client.request_operation import ( RequestOperationManager,
                                           YCM_OPERATION_ID )
from ycm.client.semantic_tokens_request import SemanticTokensRequest


class ScrollingRequestTest( TestCase ):

  def test_ResetCancelsOutstandingRequests( self ) -> None:
    request_types = (
      SemanticTokensRequest,
      InlayHintsRequest,
    )

    for request_type in request_types:
      with self.subTest( request_type = request_type.__name__ ):
        cancellation_requests: list[ dict[ str, object ] ] = []
        manager = RequestOperationManager(
          cancellation_requests.append
        )
        request_data: dict[ str, object ] = {}
        request = request_type( request_data, manager )
        future: Future[ object ] = Future()

        with patch.object(
            BaseRequest,
            'PostDataToHandlerAsync',
            return_value = future
        ):
          request.Start()

        request.Reset()

        assert_that(
          request_data,
          equal_to( {
            YCM_OPERATION_ID: 0,
          } )
        )
        assert_that(
          cancellation_requests,
          equal_to( [ {
            YCM_OPERATION_ID: 0,
          } ] )
        )
