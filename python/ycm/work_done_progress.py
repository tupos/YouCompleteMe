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


class WorkDoneProgressState:
  def __init__( self ):
    self._progress = {}


  def Update( self, progress ):
    key = _ProgressKey( progress )
    if key is None:
      return

    kind = progress.get( 'kind' )
    if kind == 'begin':
      self._Begin( key, progress )
    elif kind == 'report':
      self._Report( key, progress )
    elif kind == 'end':
      self._progress.pop( key, None )


  def _Begin( self, key, progress ):
    if key in self._progress:
      return

    self._progress[ key ] = {
      'title': _Text( progress.get( 'title' ) ),
      'message': _Text( progress.get( 'message' ) ),
      'percentage': _Percentage( progress.get( 'percentage' ) ),
    }


  def _Report( self, key, progress ):
    if key not in self._progress:
      return

    message = _Text( progress.get( 'message' ) )
    if message:
      self._progress[ key ][ 'message' ] = message

    if 'percentage' in progress:
      percentage = _Percentage( progress.get( 'percentage' ) )
      if percentage is not None:
        self._progress[ key ][ 'percentage' ] = percentage


  def Items( self ):
    items = []
    for progress in self._progress.values():
      parts = [ progress[ 'title' ], progress[ 'message' ] ]
      percentage = progress[ 'percentage' ]
      if percentage:
        parts.append( f'{ percentage }%' )
      items.append( ' '.join( part for part in parts if part ) )
    return items


  def Clear( self ):
    self._progress.clear()


def _ProgressKey( progress ):
  if not isinstance( progress, dict ):
    return None

  server = progress.get( 'server' )
  token = progress.get( 'token' )
  if ( not isinstance( server, str ) or
       not isinstance( token, ( str, int ) ) or
       isinstance( token, bool ) ):
    return None
  return ( server, token )


def _Text( value ):
  if not isinstance( value, str ):
    return ''
  return value.replace( '\r\n', ' ' ).replace( '\n', ' ' )


def _Percentage( value ):
  if ( isinstance( value, bool ) or
       not isinstance( value, ( int, float ) ) or
       value < 0 or value > 100 or
       not math.isfinite( value ) ):
    return None
  return int( value + 0.5 )
