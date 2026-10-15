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

from ycm import vimsupport
from ycm.client.base_request import BaseRequest, BuildRequestData
from ycm.client.command_request import CommandRequest
from ycm.client.request_operation import ( OperationFuture,
                                           RequestOperationManager )


@dataclass( frozen = True )
class _RequestSnapshot:
  buffer_number: int
  changed_tick: int
  cursor_position: tuple[ int, int ]


def _CurrentSnapshot() -> _RequestSnapshot:
  buffer_number: int = vimsupport.GetCurrentBufferNumber()
  return _RequestSnapshot(
    buffer_number,
    vimsupport.GetBufferChangedTick( buffer_number ),
    vimsupport.CurrentLineAndColumn()
  )


class PrepareRenameRequest( BaseRequest ):
  def __init__(
      self,
      request_operation_manager: RequestOperationManager
  ) -> None:
    super().__init__( request_operation_manager )
    self._snapshot: _RequestSnapshot = _CurrentSnapshot()
    self._default_placeholder: str = vimsupport.CurrentWord()
    self._request_data: dict[ str, object ] = BuildRequestData()
    self._response_future: OperationFuture | None = None
    self._response: dict[ str, object ] | None = None
    self._response_processed: bool = False


  def Start( self ) -> None:
    self._response_future = self.PostCancellableDataToHandlerAsync(
      self._request_data,
      'prepare_rename'
    )


  def Done( self ) -> bool:
    return (
      self._response_future is not None and
      self._response_future.done()
    )


  def Response( self ) -> dict[ str, object ] | None:
    if self._response_processed:
      return self._response

    self._response_processed = True
    if self._response_future is None:
      return None

    response: object = self.HandleFuture( self._response_future )
    if ( not isinstance( response, dict ) or
         self._snapshot != _CurrentSnapshot() ):
      return None

    placeholder: object = response.get(
      'placeholder',
      self._default_placeholder
    )
    if not isinstance( placeholder, str ):
      return None

    self._response = {
      **response,
      'placeholder': placeholder,
    }
    return self._response


class RenameRequest( CommandRequest ):
  def __init__(
      self,
      new_name: str,
      extra_data: dict[ str, object ],
      buffer_command: str,
      response_handler: Callable[ [ object ], None ],
      request_operation_manager: RequestOperationManager
  ) -> None:
    prepared_extra_data: dict[ str, object ] = {
      **extra_data,
      'prepared_rename': True,
    }
    super().__init__(
      [ 'RefactorRename', new_name ],
      extra_data = prepared_extra_data,
      silent = False,
      response_handler = response_handler,
      request_operation_manager = request_operation_manager
    )
    self._buffer_command: str = buffer_command


  def ApplyResponse( self ) -> None:
    self.RunPostCommandActionsIfNeeded(
      '',
      self._buffer_command
    )
