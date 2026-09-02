# Copyright (C) 2022, YouCompleteMe Contributors
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


from ycm.client.inlay_hints_request import InlayHintsRequest
from ycm.client.base_request import BuildRequestData
from ycm import scrolling_range as sr
from ycm.virtual_text import ( CreateVirtualTextRenderer,
                               VirtualTextChunk,
                               VirtualTextRenderer )


HIGHLIGHT_GROUP: dict[ str, str ] = {
  'Type':      'YcmInlayHint',
  'Parameter': 'YcmInlayHint',
  'Enum':      'YcmInlayHint',
}
REPORTED_MISSING_TYPES: set[ str ] = set()
INLAY_HINT_HIGHLIGHT_GROUPS: dict[ str, str ] = {
  'YCM_INLAY_UNKNOWN': 'YcmInlayHint',
  'YCM_INLAY_PADDING': 'YcmInvisible',
  **{
    f'YCM_INLAY_{ token_type }': highlight_group
    for token_type, highlight_group in HIGHLIGHT_GROUP.items()
  }
}
INLAY_HINT_NAMESPACE: str = 'ycm_inlay_hints'


def Initialise() -> bool:
  return CreateVirtualTextRenderer(
    INLAY_HINT_NAMESPACE,
    INLAY_HINT_HIGHLIGHT_GROUPS
  ).Initialise()


class InlayHints( sr.ScrollingBufferRange ):
  """Stores the inlay hints state for a Vim buffer"""

  def __init__(
      self,
      bufnr: int,
      renderer: VirtualTextRenderer | None = None ) -> None:
    super().__init__( bufnr )
    self._renderer: VirtualTextRenderer = (
      renderer
      if renderer is not None
      else CreateVirtualTextRenderer(
        INLAY_HINT_NAMESPACE,
        INLAY_HINT_HIGHLIGHT_GROUPS
      )
    )


  def _NewRequest(
      self,
      request_range: dict[ str, dict[ str, object ] ]
  ) -> InlayHintsRequest:
    request_data: dict[ str, object ] = BuildRequestData( self._bufnr )
    request_data[ 'range' ] = request_range
    return InlayHintsRequest( request_data )


  def Clear( self ) -> None:
    self._renderer.Clear( self._bufnr )


  def _Draw( self ) -> None:
    self.Clear()

    for inlay_hint in self._latest_response:
      if 'kind' not in inlay_hint:
        prop_type = 'YCM_INLAY_UNKNOWN'
      elif inlay_hint[ 'kind' ] not in HIGHLIGHT_GROUP:
        prop_type = 'YCM_INLAY_UNKNOWN'
      else:
        prop_type = 'YCM_INLAY_' + inlay_hint[ 'kind' ]

      self.GrowRangeIfNeeded( {
        'start': inlay_hint[ 'position' ],
        'end': {
          'line_num': inlay_hint[ 'position' ][ 'line_num' ],
          'column_num': inlay_hint[ 'position' ][ 'column_num' ] + len(
            inlay_hint[ 'label' ] )
        }
      } )

      chunks: list[ VirtualTextChunk ] = []

      if inlay_hint.get( 'paddingLeft', False ):
        chunks.append( ( ' ', 'YCM_INLAY_PADDING' ) )

      chunks.append( ( inlay_hint[ 'label' ], prop_type ) )

      if inlay_hint.get( 'paddingRight', False ):
        chunks.append( ( ' ', 'YCM_INLAY_PADDING' ) )

      self._renderer.Render(
        self._bufnr,
        int( inlay_hint[ 'position' ][ 'line_num' ] ),
        int( inlay_hint[ 'position' ][ 'column_num' ] ),
        chunks
      )
