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

from collections.abc import Iterator
import json
from typing import cast

import vim

from ycm import vimsupport
from ycm.document_highlights import ( DocumentHighlight,
                                      DocumentHighlightsRenderer )


DOCUMENT_HIGHLIGHT_NAMESPACE: str = 'ycm_document_highlights'
DOCUMENT_HIGHLIGHT_GROUPS: dict[ str, str ] = {
  'YcmDocumentHighlightText': 'Visual',
  'YcmDocumentHighlightRead': 'YcmDocumentHighlightText',
  'YcmDocumentHighlightWrite': 'YcmDocumentHighlightText',
}
DOCUMENT_HIGHLIGHT_KIND_TO_GROUP: dict[ str, str ] = {
  'Text': 'YcmDocumentHighlightText',
  'Read': 'YcmDocumentHighlightRead',
  'Write': 'YcmDocumentHighlightWrite',
}
# Keep document highlights above semantic highlighting. In Vim, the highest
# priority overlapping text property's override flag determines whether
# CursorLine may obscure the combined highlights.
_DOCUMENT_HIGHLIGHT_PRIORITY: int = 200


def DocumentHighlightsSupported() -> bool:
  return vimsupport.EditorFeatureSupported( 'document_highlights' )


def _HighlightProperties(
    highlights: list[ DocumentHighlight ]
) -> Iterator[ tuple[ str, dict[ str, dict[ str, object ] ] ] ]:
  for highlight in highlights:
    kind: str = str( highlight.get( 'kind', 'Text' ) )
    property_type: str = DOCUMENT_HIGHLIGHT_KIND_TO_GROUP.get(
      kind,
      DOCUMENT_HIGHLIGHT_KIND_TO_GROUP[ 'Text' ]
    )
    yield (
      property_type,
      cast(
        dict[ str, dict[ str, object ] ],
        highlight[ 'range' ]
      )
    )


class VimDocumentHighlightsRenderer:
  def Initialise( self ) -> bool:
    if not DocumentHighlightsSupported():
      return False

    property_types: set[ str ] = set(
      vimsupport.GetTextPropertyTypes()
    )
    for property_type, default_highlight_group in (
        DOCUMENT_HIGHLIGHT_GROUPS.items() ):
      vim.command(
        f'highlight default link '
        f'{ property_type } { default_highlight_group }'
      )
      if property_type in property_types:
        continue
      vimsupport.AddTextPropertyType(
        property_type,
        highlight = property_type,
        combine = 1,
        override = 1,
        priority = _DOCUMENT_HIGHLIGHT_PRIORITY
      )

    return True


  def Clear( self, buffer_number: int ) -> None:
    if not vimsupport.BufferExists( buffer_number ):
      return

    vimsupport.ClearTextProperties(
      buffer_number,
      prop_types = list( DOCUMENT_HIGHLIGHT_GROUPS )
    )


  def Render(
      self,
      buffer_number: int,
      highlights: list[ DocumentHighlight ]
  ) -> None:
    self.Clear( buffer_number )
    try:
      for property_type, property_range in _HighlightProperties( highlights ):
        vimsupport.AddTextPropertyForRange(
          buffer_number,
          None,
          property_type,
          property_range
        )
    except Exception:
      self.Clear( buffer_number )
      raise


class NeovimDocumentHighlightsRenderer:
  def __init__( self ) -> None:
    self._namespace_id: int = vimsupport.GetIntValue(
      f'nvim_create_namespace( '
      f'  "{ vimsupport.EscapeForVim( DOCUMENT_HIGHLIGHT_NAMESPACE ) }" )'
    )


  def Initialise( self ) -> bool:
    if not DocumentHighlightsSupported():
      return False

    for highlight_group, default_highlight_group in (
        DOCUMENT_HIGHLIGHT_GROUPS.items() ):
      vim.command(
        f'highlight default link '
        f'{ highlight_group } { default_highlight_group }'
      )

    return True


  def Clear( self, buffer_number: int ) -> None:
    if not vimsupport.BufferExists( buffer_number ):
      return
    vim.eval(
      f'nvim_buf_clear_namespace( { buffer_number }, '
      f'                          { self._namespace_id }, '
      f'                          0, '
      f'                          -1 )'
    )


  def Render(
      self,
      buffer_number: int,
      highlights: list[ DocumentHighlight ]
  ) -> None:
    self.Clear( buffer_number )
    try:
      for highlight_group, highlight_range in _HighlightProperties(
          highlights ):
        start: dict[ str, object ] = highlight_range[ 'start' ]
        end: dict[ str, object ] = highlight_range[ 'end' ]
        options: dict[ str, object ] = {
          'end_row': int( end[ 'line_num' ] ) - 1,
          'end_col': int( end[ 'column_num' ] ) - 1,
          'hl_group': highlight_group,
          'priority': _DOCUMENT_HIGHLIGHT_PRIORITY,
        }
        vim.eval(
          f'nvim_buf_set_extmark( { buffer_number }, '
          f'                      { self._namespace_id }, '
          f'                      { int( start[ "line_num" ] ) - 1 }, '
          f'                      { int( start[ "column_num" ] ) - 1 }, '
          f'                      { json.dumps( options ) } )'
        )
    except Exception:
      self.Clear( buffer_number )
      raise


def CreateDocumentHighlightsRenderer() -> DocumentHighlightsRenderer:
  if vimsupport.VimIsNeovim():
    return NeovimDocumentHighlightsRenderer()

  return VimDocumentHighlightsRenderer()
