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

from dataclasses import dataclass
from typing import Protocol

from ycm import vimsupport
from ycm.client.base_request import BuildRequestData
from ycm.client.document_highlights_request import DocumentHighlightsRequest
from ycm.client.request_operation import RequestOperationManager


DocumentHighlight = dict[ str, object ]


class DocumentHighlightsRenderer( Protocol ):
  def Initialise( self ) -> bool:
    ...


  def Clear( self, buffer_number: int ) -> None:
    ...


  def Render(
      self,
      buffer_number: int,
      highlights: list[ DocumentHighlight ]
  ) -> None:
    ...


class DocumentHighlightsRequestProtocol( Protocol ):
  def Start( self ) -> None:
    ...


  def Done( self ) -> bool:
    ...


  def Reset( self ) -> None:
    ...


  def Response( self ) -> list[ DocumentHighlight ]:
    ...


@dataclass( frozen = True )
class _RequestSnapshot:
  buffer_number: int
  changed_tick: int
  cursor_position: tuple[ int, int ]


class DocumentHighlights:
  def __init__(
      self,
      request_operation_manager: RequestOperationManager,
      renderer: DocumentHighlightsRenderer
  ) -> None:
    self._request_operation_manager = request_operation_manager
    self._renderer = renderer
    self._request: DocumentHighlightsRequestProtocol | None = None
    self._snapshot: _RequestSnapshot | None = None
    self._rendered_snapshot: _RequestSnapshot | None = None


  def Initialise( self ) -> bool:
    return self._renderer.Initialise()


  def Request( self ) -> None:
    current_snapshot: _RequestSnapshot = self._CurrentSnapshot()
    if ( current_snapshot == self._snapshot or
         current_snapshot == self._rendered_snapshot ):
      return

    self._CancelRequest()
    self._ClearRenderedHighlights()

    self._snapshot = current_snapshot
    request_data: dict[ str, object ] = BuildRequestData()
    self._request = self._NewRequest( request_data )
    self._request.Start()


  def Ready( self ) -> bool:
    return self._request is None or self._request.Done()


  def Update( self ) -> None:
    if self._request is None:
      return

    if not self._request.Done():
      return

    highlights: list[ DocumentHighlight ] = self._request.Response()
    self._request = None
    request_snapshot: _RequestSnapshot | None = self._snapshot
    self._snapshot = None

    if ( request_snapshot is None or
         not self._SnapshotIsCurrent( request_snapshot ) ):
      return

    self._renderer.Render(
      request_snapshot.buffer_number,
      highlights
    )
    self._rendered_snapshot = request_snapshot


  def Clear( self ) -> None:
    self._CancelRequest()
    self._ClearRenderedHighlights()


  def _CancelRequest( self ) -> None:
    if self._request is not None:
      self._request.Reset()
      self._request = None
    self._snapshot = None


  def _ClearRenderedHighlights( self ) -> None:
    if self._rendered_snapshot is None:
      return

    self._renderer.Clear( self._rendered_snapshot.buffer_number )
    self._rendered_snapshot = None


  def _CurrentSnapshot( self ) -> _RequestSnapshot:
    buffer_number: int = vimsupport.GetCurrentBufferNumber()
    return _RequestSnapshot(
      buffer_number,
      vimsupport.GetBufferChangedTick( buffer_number ),
      vimsupport.CurrentLineAndColumn()
    )


  def _SnapshotIsCurrent( self, snapshot: _RequestSnapshot ) -> bool:
    return snapshot == self._CurrentSnapshot()


  def _NewRequest(
      self,
      request_data: dict[ str, object ]
  ) -> DocumentHighlightsRequestProtocol:
    return DocumentHighlightsRequest(
      request_data,
      self._request_operation_manager
    )
