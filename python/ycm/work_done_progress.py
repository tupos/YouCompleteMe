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

import math
from typing import TypeAlias


ProgressToken: TypeAlias = str | int
ProgressKey: TypeAlias = tuple[ str, int, ProgressToken ]
Progress: TypeAlias = dict[ str, object ]
ProgressDisplay: TypeAlias = dict[ str, str | int | None ]


class WorkDoneProgressState:
  def __init__( self ) -> None:
    self._progress: dict[ ProgressKey, ProgressDisplay ] = {}
    self._cleared_connection_generations: dict[ str, int ] = {}


  def Update( self, progress: object ) -> None:
    key = _ProgressKey( progress )
    if key is None:
      return

    server, connection_generation, _ = key
    if ( connection_generation <=
         self._cleared_connection_generations.get( server, 0 ) ):
      return

    assert isinstance( progress, dict )
    kind = progress.get( 'kind' )
    if kind == 'begin':
      self._Begin( key, progress )
    elif kind == 'report':
      self._Report( key, progress )
    elif kind == 'end':
      self._progress.pop( key, None )


  def _Begin( self, key: ProgressKey, progress: Progress ) -> None:
    if key in self._progress:
      return

    self._progress[ key ] = {
      'title': _Text( progress.get( 'title' ) ),
      'message': _Text( progress.get( 'message' ) ),
      'percentage': _Percentage( progress.get( 'percentage' ) ),
    }


  def _Report( self, key: ProgressKey, progress: Progress ) -> None:
    if key not in self._progress:
      return

    message = _Text( progress.get( 'message' ) )
    if message:
      self._progress[ key ][ 'message' ] = message

    if 'percentage' in progress:
      percentage = _Percentage( progress.get( 'percentage' ) )
      if percentage is not None:
        self._progress[ key ][ 'percentage' ] = percentage


  def Items( self ) -> list[ str ]:
    items: list[ str ] = []
    for progress in self._progress.values():
      parts = [ progress[ 'title' ], progress[ 'message' ] ]
      percentage = progress[ 'percentage' ]
      if percentage:
        parts.append( f'{ percentage }%' )
      items.append( ' '.join( part for part in parts if part ) )
    return items


  def ClearForServerGeneration( self,
                                server: str,
                                connection_generation: int ) -> None:
    last_cleared_generation = max(
      connection_generation,
      self._cleared_connection_generations.get( server, 0 ) )
    self._cleared_connection_generations[ server ] = last_cleared_generation
    self._progress = {
      key: progress for key, progress in self._progress.items()
      if key[ 0 ] != server or key[ 1 ] > last_cleared_generation
    }


  def Clear( self ) -> None:
    self._progress.clear()
    self._cleared_connection_generations.clear()


def _ProgressKey( progress: object ) -> ProgressKey | None:
  if not isinstance( progress, dict ):
    return None

  server = progress.get( 'server' )
  connection_generation = progress.get( 'connection_generation' )
  token = progress.get( 'token' )
  if ( not isinstance( server, str ) or
       not isinstance( connection_generation, int ) or
       isinstance( connection_generation, bool ) or
       connection_generation <= 0 or
       not isinstance( token, ( str, int ) ) or
       isinstance( token, bool ) ):
    return None
  return ( server, connection_generation, token )


def _Text( value: object ) -> str:
  if not isinstance( value, str ):
    return ''
  return value.replace( '\r\n', ' ' ).replace( '\n', ' ' )


def _Percentage( value: object ) -> int | None:
  if ( isinstance( value, bool ) or
       not isinstance( value, ( int, float ) ) or
       value < 0 or value > 100 or
       not math.isfinite( value ) ):
    return None
  return int( value + 0.5 )
