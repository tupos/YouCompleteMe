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
from unittest.mock import MagicMock, call, patch

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from ycm.client.base_request import BaseRequest
from ycm.client.language_server_state_request import (
  LanguageServerStateRequest,
)


class LanguageServerStateRequestTest( TestCase ):
  def test_StartTargetsAllLanguageServersWithoutFiletype( self ) -> None:
    request = LanguageServerStateRequest(
      False,
      None,
      MagicMock()
    )
    future: Future[ object ] = Future()

    with patch.object(
        BaseRequest,
        'PostDataToHandlerAsync',
        return_value = future
    ) as post_request:
      request.Start()

    post_request.assert_called_once_with(
      {
        'enabled': False,
      },
      'set_language_server_state'
    )


  def test_StartTargetsLanguageServerForFiletype( self ) -> None:
    request = LanguageServerStateRequest(
      True,
      'rust',
      MagicMock()
    )
    future: Future[ object ] = Future()

    with patch.object(
        BaseRequest,
        'PostDataToHandlerAsync',
        return_value = future
    ) as post_request:
      request.Start()

    post_request.assert_called_once_with(
      {
        'enabled': True,
        'filetype': 'rust',
      },
      'set_language_server_state'
    )


  def test_ResponseNotifiesHandler( self ) -> None:
    response_handler: MagicMock = MagicMock()
    request = LanguageServerStateRequest(
      False,
      'rust',
      response_handler
    )
    request._response_future = Future()
    response: dict[ str, object ] = {
      'enabled': False,
      'filetypes': [ 'rust' ],
      'work_done_progress_cleanups': [],
    }

    with patch.object(
        request,
        'HandleFuture',
        return_value = response
    ):
      self.assertEqual( response, request.Response() )

    response_handler.assert_has_calls( [ call( response ) ] )
