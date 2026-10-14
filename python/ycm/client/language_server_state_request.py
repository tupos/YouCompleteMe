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
from concurrent.futures import Future

from ycm.client.base_request import BaseRequest


LanguageServerStateResponseHandler = Callable[ [ object ], None ]


class LanguageServerStateRequest( BaseRequest ):
  def __init__(
      self,
      enabled: bool,
      filetype: str | None,
      response_handler: LanguageServerStateResponseHandler
  ) -> None:
    super().__init__()
    self._enabled: bool = enabled
    self._filetype: str | None = filetype
    self._response_handler: LanguageServerStateResponseHandler = (
      response_handler
    )
    self._response_future: Future[ object ] | None = None
    self._response: object | None = None


  def Start( self ) -> None:
    request_data: dict[ str, object ] = {
      'enabled': self._enabled,
    }
    if self._filetype is not None:
      request_data[ 'filetype' ] = self._filetype

    self._response_future = self.PostDataToHandlerAsync(
      request_data,
      'set_language_server_state'
    )


  def Done( self ) -> bool:
    return (
      self._response_future is not None and
      self._response_future.done()
    )


  def Response( self ) -> object | None:
    if self._response is None and self._response_future is not None:
      self._response = self.HandleFuture( self._response_future )
      self._response_handler( self._response )

    return self._response


  def StringResponse( self ) -> str:
    self.Response()
    return ''


def SendLanguageServerStateRequestAsync(
    enabled: bool,
    filetype: str | None,
    response_handler: LanguageServerStateResponseHandler
) -> LanguageServerStateRequest:
  request = LanguageServerStateRequest(
    enabled,
    filetype,
    response_handler
  )
  request.Start()
  return request
