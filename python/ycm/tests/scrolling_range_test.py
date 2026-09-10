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
from unittest.mock import patch

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from ycm import scrolling_range


class ReadyRequest:

  def Done( self ) -> bool:
    return True


class PendingRequest:

  def __init__( self ) -> None:
    self.started: bool = False
    self.was_reset: bool = False


  def Start( self ) -> None:
    self.started = True


  def Done( self ) -> bool:
    return False


  def Reset( self ) -> None:
    self.was_reset = True


class ScrollingBufferRangeForTest( scrolling_range.ScrollingBufferRange ):

  def _NewRequest(
      self,
      request_range: dict[ str, dict[ str, object ] ]
  ) -> ReadyRequest:
    raise AssertionError( 'A new request should not be created' )


  def _Draw( self ) -> None:
    pass


class TrackingScrollingBufferRange( scrolling_range.ScrollingBufferRange ):

  def __init__( self, bufnr: int ) -> None:
    super().__init__( bufnr )
    self.requests: list[ PendingRequest ] = []


  def _NewRequest(
      self,
      request_range: dict[ str, dict[ str, object ] ]
  ) -> PendingRequest:
    request = PendingRequest()
    self.requests.append( request )
    return request


  def _Draw( self ) -> None:
    pass


class ScrollingBufferRangeTest( TestCase ):

  @patch(
    'ycm.scrolling_range.vimsupport.VisibleRangeOfBufferOverlaps',
    return_value = True
  )
  @patch(
    'ycm.scrolling_range.vimsupport.GetBufferChangedTick',
    return_value = -1
  )
  def test_RequestKeepsPollingWhenExistingRequestIsReady(
      self,
      get_buffer_changed_tick: object,
      visible_range_of_buffer_overlaps: object ) -> None:
    scrollable = ScrollingBufferRangeForTest( 1 )
    request = ReadyRequest()
    scrollable._request = request

    self.assertTrue( scrollable.Ready() )
    self.assertTrue( scrollable.Request() )
    self.assertIs( request, scrollable._request )


  @patch(
    'ycm.scrolling_range.vimsupport.VisibleRangeOfBufferOverlaps',
    return_value = True
  )
  @patch(
    'ycm.scrolling_range.vimsupport.GetBufferChangedTick',
    return_value = 1
  )
  def test_RequestKeepsPendingRequestForCurrentSnapshot(
      self,
      get_buffer_changed_tick: object,
      visible_range_of_buffer_overlaps: object ) -> None:
    scrollable = TrackingScrollingBufferRange( 1 )
    request = PendingRequest()
    request.Start()
    scrollable._request = request
    scrollable._tick = 1

    self.assertTrue( scrollable.Request() )
    self.assertFalse( request.was_reset )
    self.assertIs( request, scrollable._request )
    self.assertEqual( [], scrollable.requests )


  def test_RequestReplacesPendingRequestForStaleSnapshot( self ) -> None:
    requested_range: dict[ str, dict[ str, object ] ] = {
      'start': {
        'line_num': 1,
        'column_num': 1,
      },
      'end': {
        'line_num': 20,
        'column_num': 1,
      },
    }
    scenarios = (
      {
        'name': 'forced refresh',
        'force': True,
        'previous_tick': 1,
        'current_tick': 1,
        'overlaps': True,
      },
      {
        'name': 'changed buffer',
        'force': False,
        'previous_tick': 1,
        'current_tick': 2,
        'overlaps': True,
      },
      {
        'name': 'non-overlapping scroll',
        'force': False,
        'previous_tick': 1,
        'current_tick': 1,
        'overlaps': False,
      },
    )

    for scenario in scenarios:
      with self.subTest( scenario[ 'name' ] ):
        scrollable = TrackingScrollingBufferRange( 1 )
        previous_request = PendingRequest()
        previous_request.Start()
        scrollable._request = previous_request
        scrollable._tick = scenario[ 'previous_tick' ]

        with patch(
            'ycm.scrolling_range.vimsupport.GetBufferChangedTick',
            return_value = scenario[ 'current_tick' ]
        ):
          with patch(
              'ycm.scrolling_range.vimsupport.VisibleRangeOfBufferOverlaps',
              return_value = scenario[ 'overlaps' ]
          ):
            with patch(
                'ycm.scrolling_range.vimsupport.RangeVisibleInBuffer',
                return_value = requested_range
            ):
              self.assertTrue(
                scrollable.Request( force = scenario[ 'force' ] )
              )

        self.assertTrue( previous_request.was_reset )
        self.assertEqual( 1, len( scrollable.requests ) )
        self.assertTrue( scrollable.requests[ 0 ].started )
        self.assertIs( scrollable.requests[ 0 ], scrollable._request )
