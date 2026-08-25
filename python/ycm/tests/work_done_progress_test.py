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

from hamcrest import assert_that, contains_exactly, empty
from unittest import TestCase

from ycm.work_done_progress import WorkDoneProgressState


class WorkDoneProgressStateTest( TestCase ):
  def test_WorkDoneProgressState_Lifecycle( self ):
    state = WorkDoneProgressState()

    state.Update( {
      'server': 'clangd',
      'connection_generation': 1,
      'token': 'index',
      'kind': 'begin',
      'title': 'Indexing',
      'message': 'Loading\nfiles',
      'percentage': 12.5,
    } )
    assert_that( state.Items(), contains_exactly(
      'Indexing Loading files 13%' ) )

    state.Update( {
      'server': 'clangd',
      'connection_generation': 1,
      'token': 'index',
      'kind': 'report',
      'percentage': 42.4,
    } )
    assert_that( state.Items(), contains_exactly(
      'Indexing Loading files 42%' ) )

    state.Update( {
      'server': 'clangd',
      'connection_generation': 1,
      'token': 'index',
      'kind': 'report',
      'message': 'Finishing',
    } )
    assert_that( state.Items(), contains_exactly(
      'Indexing Finishing 42%' ) )

    state.Update( {
      'server': 'clangd',
      'connection_generation': 1,
      'token': 'index',
      'kind': 'end',
    } )
    assert_that( state.Items(), empty() )


  def test_WorkDoneProgressState_ConcurrentProgress( self ):
    state = WorkDoneProgressState()
    state.Update( {
      'server': 'clangd',
      'connection_generation': 1,
      'token': 1,
      'kind': 'begin',
      'title': 'Indexing',
    } )
    state.Update( {
      'server': 'rust-analyzer',
      'connection_generation': 1,
      'token': 1,
      'kind': 'begin',
      'title': 'Checking',
      'percentage': 50,
    } )

    assert_that( state.Items(), contains_exactly(
      'Indexing', 'Checking 50%' ) )

    state.Clear()
    assert_that( state.Items(), empty() )


  def test_WorkDoneProgressState_IgnoresInvalidTransitions( self ):
    state = WorkDoneProgressState()

    for progress in (
        { 'kind': 'begin', 'server': None,
          'connection_generation': 1, 'token': 1 },
        { 'kind': 'begin', 'server': 'clangd',
          'connection_generation': True, 'token': 1 },
        { 'kind': 'begin', 'server': 'clangd',
          'connection_generation': 0, 'token': 1 },
        { 'kind': 'begin', 'server': 'clangd',
          'connection_generation': 1, 'token': True },
        { 'kind': 'report', 'server': 'clangd',
          'connection_generation': 1, 'token': 1 },
        { 'kind': 'end', 'server': 'clangd',
          'connection_generation': 1, 'token': 1 } ):
      state.Update( progress )

    assert_that( state.Items(), empty() )


  def test_WorkDoneProgressState_IgnoresDuplicateBeginAndBadPercentage(
      self ):
    state = WorkDoneProgressState()
    state.Update( {
      'server': 'clangd',
      'connection_generation': 1,
      'token': 1,
      'kind': 'begin',
      'title': 'Indexing',
      'percentage': 10,
    } )
    state.Update( {
      'server': 'clangd',
      'connection_generation': 1,
      'token': 1,
      'kind': 'begin',
      'title': 'Replacement',
    } )

    for percentage in ( True, -1, 101, float( 'nan' ) ):
      state.Update( {
        'server': 'clangd',
        'connection_generation': 1,
        'token': 1,
        'kind': 'report',
        'percentage': percentage,
      } )

    assert_that( state.Items(), contains_exactly( 'Indexing 10%' ) )


  def test_WorkDoneProgressState_ClearsOnlyEndedConnectionGeneration( self ):
    state = WorkDoneProgressState()
    state.Update( {
      'server': 'clangd',
      'connection_generation': 7,
      'token': 'old',
      'kind': 'begin',
      'title': 'Old indexing',
    } )
    state.Update( {
      'server': 'clangd',
      'connection_generation': 8,
      'token': 'new',
      'kind': 'begin',
      'title': 'New indexing',
    } )
    state.Update( {
      'server': 'rust-analyzer',
      'connection_generation': 3,
      'token': 'check',
      'kind': 'begin',
      'title': 'Checking',
    } )

    state.ClearForServerGeneration( 'clangd', 7 )

    assert_that( state.Items(), contains_exactly(
      'New indexing', 'Checking' ) )


  def test_WorkDoneProgressState_IgnoresDelayedClearedGeneration( self ):
    state = WorkDoneProgressState()
    state.ClearForServerGeneration( 'clangd', 7 )

    state.Update( {
      'server': 'clangd',
      'connection_generation': 7,
      'token': 'old',
      'kind': 'begin',
      'title': 'Old indexing',
    } )
    state.Update( {
      'server': 'clangd',
      'connection_generation': 8,
      'token': 'new',
      'kind': 'begin',
      'title': 'New indexing',
    } )

    assert_that( state.Items(), contains_exactly( 'New indexing' ) )


  def test_WorkDoneProgressState_FullClearResetsGenerationHistory( self ):
    state = WorkDoneProgressState()
    state.ClearForServerGeneration( 'clangd', 7 )
    state.Clear()

    state.Update( {
      'server': 'clangd',
      'connection_generation': 1,
      'token': 'after-ycmd-restart',
      'kind': 'begin',
      'title': 'Indexing',
    } )

    assert_that( state.Items(), contains_exactly( 'Indexing' ) )
