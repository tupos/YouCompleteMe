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

import logging
from typing import cast

from ycm.client.base_request import ( BaseRequest, DisplayServerException,
                                      MakeServerException )
from ycm.client.request_operation import ( OperationFuture,
                                           RequestOperationManager )


_logger = logging.getLogger( __name__ )


class DocumentHighlightsRequest( BaseRequest ):
  def __init__(
      self,
      request_data: dict[ str, object ],
      request_operation_manager: RequestOperationManager
  ) -> None:
    super().__init__( request_operation_manager )
    self.request_data = request_data
    self._response_future: OperationFuture | None = None


  def Start( self ) -> None:
    self._response_future = self.PostCancellableDataToHandlerAsync(
      self.request_data,
      'document_highlights'
    )


  def Done( self ) -> bool:
    return bool( self._response_future ) and self._response_future.done()


  def Reset( self ) -> None:
    self.Cancel()
    self._response_future = None


  def Response( self ) -> list[ dict[ str, object ] ]:
    if not self._response_future:
      return []

    response: dict[ str, object ] | None = self.HandleFuture(
      self._response_future,
      truncate_message = True
    )
    if not response:
      return []

    errors = cast(
      list[ dict[ str, object ] ],
      response.get( 'errors' ) or []
    )
    for error in errors:
      exception = MakeServerException( error )
      _logger.error( exception )
      DisplayServerException( exception, truncate_message = True )

    return cast(
      list[ dict[ str, object ] ],
      response.get( 'document_highlights' ) or []
    )
