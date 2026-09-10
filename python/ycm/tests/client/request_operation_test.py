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

from hamcrest import assert_that, equal_to

from ycm.client.request_operation import (
  RequestOperationManager,
  YCM_OPERATION_ID,
  YCM_RETIRED_OPERATION_ID,
)


class _Future:
  def __init__( self ) -> None:
    self._done: bool = False


  def done( self ) -> bool:
    return self._done


  def Complete( self ) -> None:
    self._done = True


class RequestOperationManagerTest( TestCase ):
  def setUp( self ) -> None:
    self.cancellation_requests: list[ dict[ str, object ] ] = []
    self.manager = RequestOperationManager(
      self.cancellation_requests.append
    )


  def test_OperationsReceiveMonotonicallyIncreasingIds( self ) -> None:
    first_request: dict[ str, object ] = {}
    self.manager.StartOperation( first_request )

    second_request: dict[ str, object ] = {}
    self.manager.StartOperation( second_request )

    assert_that(
      first_request,
      equal_to( {
        YCM_OPERATION_ID: 0,
      } )
    )
    assert_that(
      second_request,
      equal_to( {
        YCM_OPERATION_ID: 1,
      } )
    )


  def test_CompletedOperationIsReportedAsRetired( self ) -> None:
    first_request: dict[ str, object ] = {}
    first_operation = self.manager.StartOperation( first_request )
    first_future = _Future()
    first_operation.AttachFuture( first_future )
    first_future.Complete()

    second_request: dict[ str, object ] = {}
    self.manager.StartOperation( second_request )

    assert_that(
      second_request,
      equal_to( {
        YCM_OPERATION_ID: 1,
        YCM_RETIRED_OPERATION_ID: 0,
      } )
    )


  def test_OnlyContiguousCompletedOperationsAreRetired( self ) -> None:
    first_request: dict[ str, object ] = {}
    first_operation = self.manager.StartOperation( first_request )
    first_future = _Future()
    first_operation.AttachFuture( first_future )

    second_request: dict[ str, object ] = {}
    second_operation = self.manager.StartOperation( second_request )
    second_operation.FinishWithoutFuture()

    third_request: dict[ str, object ] = {}
    third_operation = self.manager.StartOperation( third_request )

    assert_that(
      third_request,
      equal_to( {
        YCM_OPERATION_ID: 2,
      } )
    )

    third_operation.FinishWithoutFuture()
    first_future.Complete()

    fourth_request: dict[ str, object ] = {}
    self.manager.StartOperation( fourth_request )

    assert_that(
      fourth_request,
      equal_to( {
        YCM_OPERATION_ID: 3,
        YCM_RETIRED_OPERATION_ID: 2,
      } )
    )


  def test_OperationCanFinishWhenSubmissionFails( self ) -> None:
    first_request: dict[ str, object ] = {}
    first_operation = self.manager.StartOperation( first_request )
    first_operation.FinishWithoutFuture()

    second_request: dict[ str, object ] = {}
    self.manager.StartOperation( second_request )

    assert_that(
      second_request,
      equal_to( {
        YCM_OPERATION_ID: 1,
        YCM_RETIRED_OPERATION_ID: 0,
      } )
    )


  def test_CancelSendsOperationAndRetirementWatermark( self ) -> None:
    first_request: dict[ str, object ] = {}
    first_operation = self.manager.StartOperation( first_request )
    first_operation.FinishWithoutFuture()

    second_request: dict[ str, object ] = {}
    second_operation = self.manager.StartOperation( second_request )
    second_operation.Cancel()

    assert_that(
      self.cancellation_requests,
      equal_to( [ {
        YCM_OPERATION_ID: 1,
        YCM_RETIRED_OPERATION_ID: 0,
      } ] )
    )


  def test_CancelIsIdempotent( self ) -> None:
    request_data: dict[ str, object ] = {}
    operation = self.manager.StartOperation( request_data )

    operation.Cancel()
    operation.Cancel()

    assert_that(
      self.cancellation_requests,
      equal_to( [ {
        YCM_OPERATION_ID: 0,
      } ] )
    )


  def test_CompletedOperationIsNotCancelled( self ) -> None:
    request_data: dict[ str, object ] = {}
    operation = self.manager.StartOperation( request_data )
    future = _Future()
    operation.AttachFuture( future )
    future.Complete()

    operation.Cancel()

    assert_that( self.cancellation_requests, equal_to( [] ) )
