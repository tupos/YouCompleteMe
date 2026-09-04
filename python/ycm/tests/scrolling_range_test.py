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


class ScrollingBufferRangeForTest( scrolling_range.ScrollingBufferRange ):

  def _NewRequest(
      self,
      request_range: dict[ str, dict[ str, object ] ]
  ) -> ReadyRequest:
    raise AssertionError( 'A new request should not be created' )


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
