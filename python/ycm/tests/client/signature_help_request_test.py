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

from ycm import vimsupport
from ycm.client.base_request import BaseRequest
from ycm.client.request_operation import ( RequestOperationManager,
                                           YCM_OPERATION_ID )
from ycm.client.signature_help_request import SignatureHelpRequest
from ycm.youcompleteme import YouCompleteMe


class _AvailableRequest:
  def Done( self ) -> bool:
    return True


  def Response( self ) -> str:
    return 'YES'


class _CompletionRequest:
  def __init__( self ) -> None:
    self.request_data: dict[ str, object ] = {}


class SignatureHelpRequestTest( TestCase ):
  def test_ResetCancelsOutstandingRequest( self ) -> None:
    cancellation_requests: list[ dict[ str, object ] ] = []
    manager = RequestOperationManager( cancellation_requests.append )
    request_data: dict[ str, object ] = {}
    request = SignatureHelpRequest( request_data, manager )
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


  def test_NewSignatureHelpCancelsOutstandingRequest( self ) -> None:
    cancellation_requests: list[ dict[ str, object ] ] = []
    manager = RequestOperationManager( cancellation_requests.append )
    first_request = SignatureHelpRequest( {}, manager )
    first_future: Future[ object ] = Future()

    with patch.object(
        BaseRequest,
        'PostDataToHandlerAsync',
        return_value = first_future
    ):
      first_request.Start()

    ycm = YouCompleteMe.__new__( YouCompleteMe )
    ycm._request_operation_manager = manager
    ycm._latest_signature_help_request = first_request
    ycm._latest_completion_request = _CompletionRequest()
    ycm._signature_help_available_requests = {
      'cpp': _AvailableRequest(),
    }

    second_future: Future[ object ] = Future()
    with patch.object(
        ycm,
        'NativeFiletypeCompletionUsable',
        return_value = True
    ):
      with patch.object(
          vimsupport,
          'CurrentFiletypes',
          return_value = [ 'cpp' ]
      ):
        with patch.object( ycm, '_AddExtraConfDataIfNeeded' ):
          with patch.object(
              BaseRequest,
              'PostDataToHandlerAsync',
              return_value = second_future
          ):
            request_sent = ycm.SendSignatureHelpRequest( 'ACTIVE' )

    assert_that( request_sent, equal_to( True ) )
    assert_that(
      cancellation_requests,
      equal_to( [ {
        YCM_OPERATION_ID: 0,
      } ] )
    )
    assert_that(
      ycm._latest_signature_help_request.request_data,
      equal_to( {
        'signature_help_state': 'ACTIVE',
        YCM_OPERATION_ID: 1,
      } )
    )
