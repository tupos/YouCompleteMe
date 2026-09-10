# Copyright (C) 2016-2018 YouCompleteMe contributors
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
from ycm.tests.test_utils import MockVimModule, MockVimBuffers, VimBuffer
MockVimModule()

from hamcrest import assert_that, contains_exactly, equal_to, has_entries
from unittest.mock import patch
from unittest import TestCase

from ycm.tests import YouCompleteMeInstance
from ycm.client.base_request import BaseRequest
from ycm.client.request_operation import YCM_OPERATION_ID
from ycm.youcompleteme import YouCompleteMe


class CommandTest( TestCase ):
  @YouCompleteMeInstance()
  def test_CommandResponse_CleansWorkDoneProgress( self, ycm ):
    ycm.UpdateWorkDoneProgress( {
      'server': 'clangd',
      'connection_generation': 7,
      'token': 'index',
      'kind': 'begin',
      'title': 'Indexing',
    } )

    ycm._HandleCommandResponse( {
      'work_done_progress_cleanup': {
        'server': 'clangd',
        'connection_generation': 7,
      }
    } )

    assert_that( ycm.GetWorkDoneProgress(), contains_exactly() )


  @YouCompleteMeInstance()
  def test_FlushCommandRequest_CancelsPendingRequest(
      self,
      ycm: YouCompleteMe
  ) -> None:
    current_buffer = VimBuffer( 'buffer' )
    command_future: Future[ object ] = Future()
    cancellation_future: Future[ object ] = Future()

    with MockVimBuffers( [ current_buffer ], [ current_buffer ] ):
      with patch.object(
          BaseRequest,
          'PostDataToHandlerAsync',
          side_effect = [
            command_future,
            cancellation_future,
          ]
      ) as post_request:
        request_id = ycm.SendCommandRequestAsync( [ 'GoTo' ] )
        ycm.FlushCommandRequest( request_id )

    posted_requests = post_request.call_args_list
    assert_that(
      [
        request_call.args[ 1 ]
        for request_call in posted_requests
      ],
      contains_exactly(
        'run_completer_command',
        'cancel_request'
      )
    )
    assert_that(
      posted_requests[ 0 ].args[ 0 ],
      has_entries( {
        'command_arguments': contains_exactly( 'GoTo' ),
        YCM_OPERATION_ID: 0,
      } )
    )
    assert_that(
      posted_requests[ 1 ].args[ 0 ],
      equal_to( {
        YCM_OPERATION_ID: 0,
      } )
    )
    self.assertIsNone( ycm.GetCommandRequest( request_id ) )


  @YouCompleteMeInstance( { 'g:ycm_extra_conf_vim_data': [ 'tempname()' ] } )
  def test_SendCommandRequest_ExtraConfVimData_Works( self, ycm ):
    current_buffer = VimBuffer( 'buffer' )
    with MockVimBuffers( [ current_buffer ], [ current_buffer ] ):
      with patch( 'ycm.youcompleteme.SendCommandRequest' ) as send_request:
        ycm.SendCommandRequest( [ 'GoTo' ], 'aboveleft', False, 1, 1 )
        assert_that(
          # Positional arguments passed to SendCommandRequest.
          send_request.call_args[ 0 ],
          contains_exactly(
            contains_exactly( 'GoTo' ),
            'aboveleft',
            'same-buffer',
            has_entries( {
              'options': has_entries( {
                'tab_size': 2,
                'insert_spaces': True,
              } ),
              'extra_conf_data': has_entries( {
                'tempname()': '_TEMP_FILE_'
              } ),
            } ),
          )
        )
        self.assertIs(
          send_request.call_args.kwargs[ 'request_operation_manager' ],
          ycm._request_operation_manager
        )


  @YouCompleteMeInstance( {
    'g:ycm_extra_conf_vim_data': [ 'undefined_value' ] } )
  def test_SendCommandRequest_ExtraConfData_UndefinedValue( self, ycm ):
    current_buffer = VimBuffer( 'buffer' )
    with MockVimBuffers( [ current_buffer ], [ current_buffer ] ):
      with patch( 'ycm.youcompleteme.SendCommandRequest' ) as send_request:
        ycm.SendCommandRequest( [ 'GoTo' ], 'belowright', False, 1, 1 )
        assert_that(
          # Positional arguments passed to SendCommandRequest.
          send_request.call_args[ 0 ],
          contains_exactly(
            contains_exactly( 'GoTo' ),
            'belowright',
            'same-buffer',
            has_entries( {
              'options': has_entries( {
                'tab_size': 2,
                'insert_spaces': True,
              } )
            } ),
          )
        )
        self.assertIs(
          send_request.call_args.kwargs[ 'request_operation_manager' ],
          ycm._request_operation_manager
        )


  @YouCompleteMeInstance()
  def test_SendCommandRequest_BuildRange_NoVisualMarks( self, ycm, *args ):
    current_buffer = VimBuffer( 'buffer', contents = [ 'first line',
                                                       'second line' ] )
    with MockVimBuffers( [ current_buffer ], [ current_buffer ] ):
      with patch( 'ycm.youcompleteme.SendCommandRequest' ) as send_request:
        ycm.SendCommandRequest( [ 'GoTo' ], '', True, 1, 2 )
        send_request.assert_called_once_with(
          [ 'GoTo' ],
          '',
          'same-buffer',
          {
            'options': {
              'tab_size': 2,
              'insert_spaces': True
            },
            'range': {
              'start': {
                'line_num': 1,
                'column_num': 1
              },
              'end': {
                'line_num': 2,
                'column_num': 12
              }
            }
          },
          response_handler = ycm._HandleCommandResponse,
          request_operation_manager = ycm._request_operation_manager,
        )


  @YouCompleteMeInstance()
  def test_SendCommandRequest_BuildRange_VisualMarks( self, ycm, *args ):
    current_buffer = VimBuffer( 'buffer',
                                contents = [ 'first line',
                                             'second line' ],
                                visual_start = [ 1, 4 ],
                                visual_end = [ 2, 8 ] )
    with MockVimBuffers( [ current_buffer ], [ current_buffer ] ):
      with patch( 'ycm.youcompleteme.SendCommandRequest' ) as send_request:
        ycm.SendCommandRequest( [ 'GoTo' ], 'tab', True, 1, 2 )
        send_request.assert_called_once_with(
          [ 'GoTo' ],
          'tab',
          'same-buffer',
          {
            'options': {
              'tab_size': 2,
              'insert_spaces': True
            },
            'range': {
              'start': {
                'line_num': 1,
                'column_num': 5
              },
              'end': {
                'line_num': 2,
                'column_num': 9
              }
            }
          },
          response_handler = ycm._HandleCommandResponse,
          request_operation_manager = ycm._request_operation_manager,
        )


  @YouCompleteMeInstance()
  def test_SendCommandRequest_IgnoreFileTypeOption( self, ycm, *args ):
    current_buffer = VimBuffer( 'buffer' )
    with MockVimBuffers( [ current_buffer ], [ current_buffer ] ):
      expected_args = (
        [ 'GoTo' ],
        '',
        'same-buffer',
        {
          'completer_target': 'python',
          'options': {
            'tab_size': 2,
            'insert_spaces': True
          },
        },
      )

      with patch( 'ycm.youcompleteme.SendCommandRequest' ) as send_request:
        ycm.SendCommandRequest( [ 'ft=python', 'GoTo' ], '', False, 1, 1 )
        send_request.assert_called_once_with(
          *expected_args,
          response_handler = ycm._HandleCommandResponse,
          request_operation_manager = ycm._request_operation_manager
        )

      with patch( 'ycm.youcompleteme.SendCommandRequest' ) as send_request:
        ycm.SendCommandRequest( [ 'GoTo', 'ft=python' ], '', False, 1, 1 )
        send_request.assert_called_once_with(
          *expected_args,
          response_handler = ycm._HandleCommandResponse,
          request_operation_manager = ycm._request_operation_manager
        )
