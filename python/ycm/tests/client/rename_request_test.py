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
from unittest.mock import MagicMock, patch

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from hamcrest import assert_that, equal_to, has_entries

from ycm.client import rename_request
from ycm.client.base_request import BaseRequest
from ycm.client.request_operation import ( RequestOperationManager,
                                           YCM_OPERATION_ID )


def _IgnoreCancellation(
    request_data: dict[ str, object ]
) -> None:
  pass


class RenameRequestTest( TestCase ):
  def test_PrepareRenameUsesCancellableEndpointAndDefaultPlaceholder(
      self
  ) -> None:
    request_data: dict[ str, object ] = {
      'filepath': '/test.cpp',
    }
    snapshot = rename_request._RequestSnapshot( 3, 7, ( 1, 4 ) )
    future: Future[ object ] = Future()

    with patch.object(
        rename_request,
        '_CurrentSnapshot',
        return_value = snapshot
    ):
      with patch.object(
          rename_request.vimsupport,
          'CurrentWord',
          return_value = 'fallback_name'
      ):
        with patch.object(
            rename_request,
            'BuildRequestData',
            return_value = request_data
        ):
          request = rename_request.PrepareRenameRequest(
            RequestOperationManager( _IgnoreCancellation )
          )

      with patch.object(
          BaseRequest,
          'PostDataToHandlerAsync',
          return_value = future
      ) as post_request:
        request.Start()

      with patch.object(
          request,
          'HandleFuture',
          return_value = {
            'default_behavior': True,
          }
      ):
        response = request.Response()

    assert_that(
      request_data,
      equal_to( {
        'filepath': '/test.cpp',
        YCM_OPERATION_ID: 0,
      } )
    )
    assert_that(
      post_request.call_args.args[ 1 ],
      equal_to( 'prepare_rename' )
    )
    assert_that(
      response,
      equal_to( {
        'default_behavior': True,
        'placeholder': 'fallback_name',
      } )
    )


  def test_PrepareRenamePreservesServerPlaceholder( self ) -> None:
    snapshot = rename_request._RequestSnapshot( 3, 7, ( 1, 4 ) )

    with patch.object(
        rename_request,
        '_CurrentSnapshot',
        return_value = snapshot
    ):
      with patch.object(
          rename_request.vimsupport,
          'CurrentWord',
          return_value = 'fallback_name'
      ):
        with patch.object(
            rename_request,
            'BuildRequestData',
            return_value = {}
        ):
          request = rename_request.PrepareRenameRequest(
            RequestOperationManager( _IgnoreCancellation )
          )

      request._response_future = Future()
      with patch.object(
          request,
          'HandleFuture',
          return_value = {
            'placeholder': 'server_name',
          }
      ):
        response = request.Response()

    assert_that(
      response,
      equal_to( {
        'placeholder': 'server_name',
      } )
    )


  def test_PrepareRenameDiscardsStaleResponse( self ) -> None:
    initial_snapshot = rename_request._RequestSnapshot(
      3,
      7,
      ( 1, 4 )
    )
    changed_snapshot = rename_request._RequestSnapshot(
      3,
      8,
      ( 1, 4 )
    )

    with patch.object(
        rename_request,
        '_CurrentSnapshot',
        side_effect = [ initial_snapshot, changed_snapshot ]
    ):
      with patch.object(
          rename_request.vimsupport,
          'CurrentWord',
          return_value = 'fallback_name'
      ):
        with patch.object(
            rename_request,
            'BuildRequestData',
            return_value = {}
        ):
          request = rename_request.PrepareRenameRequest(
            RequestOperationManager( _IgnoreCancellation )
          )

      request._response_future = Future()
      with patch.object(
          request,
          'HandleFuture',
          return_value = {
            'placeholder': 'server_name',
          }
      ):
        self.assertIsNone( request.Response() )


  def test_RenameMarksPreparationAndUsesCommandPostActions( self ) -> None:
    request_data: dict[ str, object ] = {
      'options': {},
    }
    request = rename_request.RenameRequest(
      'ft=new_name',
      request_data,
      'split',
      MagicMock(),
      RequestOperationManager( _IgnoreCancellation )
    )
    future: Future[ object ] = Future()

    with patch(
        'ycm.client.command_request.BuildRequestData',
        return_value = {}
    ):
      with patch.object(
          BaseRequest,
          'PostDataToHandlerAsync',
          return_value = future
      ) as post_request:
        request.Start()

    assert_that(
      post_request.call_args.args[ 0 ],
      has_entries( {
        'options': {},
        'prepared_rename': True,
        'command_arguments': [
          'RefactorRename',
          'ft=new_name',
        ],
        YCM_OPERATION_ID: 0,
      } )
    )
    assert_that(
      request_data,
      equal_to( {
        'options': {},
      } )
    )

    with patch.object(
        request,
        'RunPostCommandActionsIfNeeded'
    ) as run_post_actions:
      request.ApplyResponse()

    run_post_actions.assert_called_once_with( '', 'split' )
