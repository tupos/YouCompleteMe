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

from collections.abc import Callable
from dataclasses import dataclass
import logging
from typing import Protocol


_logger = logging.getLogger( __name__ )


# These JSON fields identify a cancellable YCM operation to ycmd. The
# retirement watermark tells ycmd that YCM will never send another operation
# whose ID is less than or equal to that value.
YCM_OPERATION_ID: str = 'operation_id'
YCM_RETIRED_OPERATION_ID: str = 'retired_operation_id'


class OperationFuture( Protocol ):
  def done( self ) -> bool:
    ...


@dataclass
class _OperationState:
  future: OperationFuture | None = None
  finished_without_future: bool = False
  cancellation_requested: bool = False


  def Done( self ) -> bool:
    if self.finished_without_future:
      return True

    return self.future is not None and self.future.done()


class RequestOperationManager:
  """Owns the lifecycle of cancellable YCM requests.

  The manager is used only from the editor's main thread, so its state does not
  require a mutex.
  """

  def __init__(
      self,
      send_cancellation: Callable[ [ dict[ str, object ] ], None ]
  ) -> None:
    self._send_cancellation = send_cancellation
    self._next_operation_id: int = 0
    self._retired_operation_id: int = -1
    self._operations: dict[ int, _OperationState ] = {}


  def StartOperation(
      self,
      request_data: dict[ str, object ]
  ) -> RequestOperation:
    self._RetireCompletedOperations()

    operation_id = self._next_operation_id
    self._next_operation_id += 1
    self._operations[ operation_id ] = _OperationState()

    request_data[ YCM_OPERATION_ID ] = operation_id
    self._AddRetirementWatermark( request_data )

    _logger.debug(
      'Started request operation %d (retired through %d)',
      operation_id,
      self._retired_operation_id
    )

    return RequestOperation( self, operation_id )


  def _AttachFuture(
      self,
      operation_id: int,
      future: OperationFuture
  ) -> None:
    operation = self._OperationState( operation_id )
    if ( operation.future is not None or
         operation.finished_without_future ):
      raise RuntimeError(
        f'Operation { operation_id } has already been started' )

    operation.future = future
    _logger.debug(
      'Attached an HTTP request to operation %d',
      operation_id
    )


  def _FinishWithoutFuture( self, operation_id: int ) -> None:
    operation = self._OperationState( operation_id )
    if ( operation.future is not None or
         operation.finished_without_future ):
      raise RuntimeError(
        f'Operation { operation_id } has already been started' )

    operation.finished_without_future = True
    _logger.debug(
      'Operation %d finished before HTTP request submission',
      operation_id
    )


  def _CancelOperation( self, operation_id: int ) -> None:
    self._RetireCompletedOperations()

    operation = self._operations.get( operation_id )
    if operation is None:
      _logger.debug(
        'Ignored cancellation of inactive operation %d',
        operation_id
      )
      return

    if operation.cancellation_requested:
      _logger.debug(
        'Ignored duplicate cancellation of operation %d',
        operation_id
      )
      return

    operation.cancellation_requested = True
    request_data: dict[ str, object ] = {
      YCM_OPERATION_ID: operation_id,
    }
    self._AddRetirementWatermark( request_data )
    _logger.debug(
      'Requesting cancellation of operation %d (retired through %d)',
      operation_id,
      self._retired_operation_id
    )
    self._send_cancellation( request_data )


  def _RetireCompletedOperations( self ) -> None:
    previous_retired_operation_id: int = self._retired_operation_id

    while True:
      operation_id = self._retired_operation_id + 1
      operation = self._operations.get( operation_id )
      if operation is None or not operation.Done():
        break

      del self._operations[ operation_id ]
      self._retired_operation_id = operation_id

    if self._retired_operation_id != previous_retired_operation_id:
      _logger.debug(
        'Retired completed request operations through %d',
        self._retired_operation_id
      )


  def _AddRetirementWatermark(
      self,
      request_data: dict[ str, object ]
  ) -> None:
    if self._retired_operation_id >= 0:
      request_data[ YCM_RETIRED_OPERATION_ID ] = (
        self._retired_operation_id
      )


  def _OperationState( self, operation_id: int ) -> _OperationState:
    operation = self._operations.get( operation_id )
    if operation is None:
      raise RuntimeError(
        f'Operation { operation_id } is no longer active' )

    return operation


class RequestOperation:
  """A handle through which one YCM request manages its operation."""

  def __init__(
      self,
      manager: RequestOperationManager,
      operation_id: int
  ) -> None:
    self._manager = manager
    self._operation_id = operation_id


  @property
  def operation_id( self ) -> int:
    return self._operation_id


  def AttachFuture( self, future: OperationFuture ) -> None:
    self._manager._AttachFuture( self._operation_id, future )


  def FinishWithoutFuture( self ) -> None:
    self._manager._FinishWithoutFuture( self._operation_id )


  def Cancel( self ) -> None:
    self._manager._CancelOperation( self._operation_id )
