# Copyright (C) 2017-2018 YouCompleteMe Contributors
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
from io import BytesIO
import json
from unittest import TestCase
from unittest.mock import patch
from urllib.error import HTTPError

from ycm.tests.test_utils import MockVimBuffers, MockVimModule, VimBuffer
MockVimModule()

from hamcrest import assert_that, equal_to, has_entry

from ycm.client.base_request import ( BaseRequest,
                                      BuildRequestData,
                                      SendCancellationRequest,
                                      _JsonFromFuture )
from ycm.client.request_operation import ( RequestOperationManager,
                                           YCM_OPERATION_ID,
                                           YCM_RETIRED_OPERATION_ID )


class _Response:
  def __init__(
      self,
      response_text: bytes = b'',
      read_error: Exception | None = None
  ) -> None:
    self._response_text = response_text
    self._read_error = read_error
    self.closed: bool = False


  def read( self ) -> bytes:
    if self._read_error is not None:
      raise self._read_error
    return self._response_text


  def close( self ) -> None:
    self.closed = True


class _TrackedHttpError( HTTPError ):
  def __init__( self, code: int, response_text: bytes = b'' ) -> None:
    super().__init__(
      'http://127.0.0.1/test',
      code,
      'test error',
      {},
      BytesIO( response_text )
    )
    self.was_closed: bool = False


  def close( self ) -> None:
    self.was_closed = True
    super().close()


class BaseRequestTest( TestCase ):
  @patch( 'ycm.client.base_request.GetCurrentDirectory',
          return_value = '/some/dir' )
  def test_BuildRequestData_AddWorkingDir( self, *args ):
    current_buffer = VimBuffer( 'foo' )
    with MockVimBuffers( [ current_buffer ], [ current_buffer ] ):
      assert_that( BuildRequestData(), has_entry( 'working_dir', '/some/dir' ) )


  @patch( 'ycm.client.base_request.GetCurrentDirectory',
          return_value = '/some/dir' )
  def test_BuildRequestData_AddWorkingDirWithFileName( self, *args ):
    current_buffer = VimBuffer( 'foo' )
    with MockVimBuffers( [ current_buffer ], [ current_buffer ] ):
      assert_that( BuildRequestData( current_buffer.number ),
                   has_entry( 'working_dir', '/some/dir' ) )


  def test_PostCancellableRequestTracksItsFuture( self ) -> None:
    cancellation_requests: list[ dict[ str, object ] ] = []
    manager = RequestOperationManager( cancellation_requests.append )
    request = BaseRequest( manager )
    request_data: dict[ str, object ] = {}
    future: Future[ object ] = Future()

    with patch.object(
        BaseRequest,
        'PostDataToHandlerAsync',
        return_value = future
    ):
      returned_future = request.PostCancellableDataToHandlerAsync(
        request_data,
        'test_handler'
      )

    self.assertIs( returned_future, future )
    assert_that(
      request_data,
      equal_to( {
        YCM_OPERATION_ID: 0,
      } )
    )

    request.Cancel()

    assert_that(
      cancellation_requests,
      equal_to( [ {
        YCM_OPERATION_ID: 0,
      } ] )
    )


  def test_FailedSubmissionAllowsOperationToBeRetired( self ) -> None:
    cancellation_requests: list[ dict[ str, object ] ] = []
    manager = RequestOperationManager( cancellation_requests.append )
    request = BaseRequest( manager )

    with patch.object(
        BaseRequest,
        'PostDataToHandlerAsync',
        side_effect = RuntimeError( 'submission failed' )
    ):
      with self.assertRaisesRegex( RuntimeError, 'submission failed' ):
        request.PostCancellableDataToHandlerAsync(
          {},
          'test_handler'
        )

    next_request_data: dict[ str, object ] = {}
    manager.StartOperation( next_request_data )

    assert_that(
      next_request_data,
      equal_to( {
        YCM_OPERATION_ID: 1,
        YCM_RETIRED_OPERATION_ID: 0,
      } )
    )


  def test_CancellationResponseIsConsumedAndClosed( self ) -> None:
    request_data: dict[ str, object ] = {
      YCM_OPERATION_ID: 4,
    }
    future: Future[ object ] = Future()
    response = _Response()

    with patch.object(
        BaseRequest,
        'PostDataToHandlerAsync',
        return_value = future
    ) as post_request:
      SendCancellationRequest( request_data )
      future.set_result( response )

    post_request.assert_called_once_with(
      request_data,
      'cancel_request'
    )
    assert_that( response.closed, equal_to( True ) )


  def test_JsonFromFutureClosesResponseWhenReadFails( self ) -> None:
    future: Future[ object ] = Future()
    response = _Response(
      read_error = RuntimeError( 'read failed' )
    )
    future.set_result( response )

    with self.assertRaisesRegex( RuntimeError, 'read failed' ):
      _JsonFromFuture( future )

    assert_that( response.closed, equal_to( True ) )


  def test_JsonFromFutureClosesResponseWhenValidationFails( self ) -> None:
    future: Future[ object ] = Future()
    response = _Response( b'{}' )
    future.set_result( response )

    with patch(
        'ycm.client.base_request._ValidateResponseObject',
        side_effect = RuntimeError( 'validation failed' )
    ):
      with self.assertRaisesRegex( RuntimeError, 'validation failed' ):
        _JsonFromFuture( future )

    assert_that( response.closed, equal_to( True ) )


  def test_JsonFromFutureClosesResponseWhenJsonIsInvalid( self ) -> None:
    future: Future[ object ] = Future()
    response = _Response( b'not JSON' )
    future.set_result( response )

    with patch( 'ycm.client.base_request._ValidateResponseObject' ):
      with self.assertRaises( json.JSONDecodeError ):
        _JsonFromFuture( future )

    assert_that( response.closed, equal_to( True ) )


  def test_JsonFromFutureClosesNonServerHttpError( self ) -> None:
    future: Future[ object ] = Future()
    error_response = _TrackedHttpError( 404 )
    future.set_exception( error_response )

    with self.assertRaises( HTTPError ):
      _JsonFromFuture( future )

    assert_that( error_response.was_closed, equal_to( True ) )
