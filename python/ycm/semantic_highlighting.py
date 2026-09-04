# Copyright (C) 2020, YouCompleteMe Contributors
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


from ycm.client.semantic_tokens_request import SemanticTokensRequest
from ycm.client.base_request import BuildRequestData
from ycm import scrolling_range as sr
from ycm import vimsupport
from ycm.semantic_highlighting_renderer import (
  CreateSemanticHighlightingRenderer,
  SemanticHighlight,
  SemanticHighlightingRenderer )


HIGHLIGHT_GROUP: dict[ str, str ] = {
  'namespace': 'Type',
  'type': 'Type',
  'class': 'Structure',
  'enum': 'Structure',
  'interface': 'Structure',
  'struct': 'Structure',
  'typeParameter': 'Identifier',
  'parameter': 'Identifier',
  'variable': 'Identifier',
  'property': 'Identifier',
  'enumMember': 'Identifier',
  'enumConstant': 'Constant',
  'event': 'Identifier',
  'function': 'Function',
  'member': 'Identifier',
  'macro': 'Macro',
  'method': 'Function',
  'keyword': 'Keyword',
  'modifier': 'Keyword',
  'comment': 'Comment',
  'string': 'String',
  'number': 'Number',
  'regexp': 'String',
  'operator': 'Operator',
  'decorator': 'Special',
  'unknown': 'Normal',

  # These are not part of the spec, but are used by clangd
  'bracket': 'Normal',
  'concept': 'Type',
  # These are not part of the spec, but are used by jdt.ls
  'annotation': 'Macro',
}
REPORTED_MISSING_TYPES: set[ str ] = set()
SEMANTIC_HIGHLIGHT_GROUPS: dict[ str, str ] = {
  'YCM_HL_UNKNOWN': 'WarningMsg',
  **{
    f'YCM_HL_{ token_type }': highlight_group
    for token_type, highlight_group in HIGHLIGHT_GROUP.items()
  }
}


def Initialise() -> bool:
  if vimsupport.VimIsNeovim():
    return False
  return CreateSemanticHighlightingRenderer(
    SEMANTIC_HIGHLIGHT_GROUPS
  ).Initialise()



class SemanticHighlighting( sr.ScrollingBufferRange ):
  """Stores the semantic highlighting state for a Vim buffer"""

  def __init__(
      self,
      bufnr: int,
      renderer: SemanticHighlightingRenderer | None = None ) -> None:
    super().__init__( bufnr )
    self._renderer: SemanticHighlightingRenderer = (
      renderer
      if renderer is not None
      else CreateSemanticHighlightingRenderer( SEMANTIC_HIGHLIGHT_GROUPS )
    )


  def _NewRequest(
      self,
      request_range: dict[ str, dict[ str, object ] ]
  ) -> SemanticTokensRequest:
    request: dict[ str, object ] = BuildRequestData( self._bufnr )
    request[ 'range' ] = request_range
    return SemanticTokensRequest( request )


  def _Draw( self ) -> None:
    # We requested a snapshot
    tokens = self._latest_response.get( 'tokens', [] )

    highlights: list[ SemanticHighlight ] = []
    for token in tokens:
      rng = token[ 'range' ]
      self.GrowRangeIfNeeded( rng )
      highlights.append( (
        f"YCM_HL_{ token[ 'type' ] }",
        rng
      ) )

    for property_type in self._renderer.Render(
        self._bufnr,
        highlights ):
      token_type = property_type.removeprefix( 'YCM_HL_' )
      if token_type in REPORTED_MISSING_TYPES:
        continue
      REPORTED_MISSING_TYPES.add( token_type )
      vimsupport.PostVimMessage(
        f"Token type { token_type } not supported. "
        f"Define property type { property_type }. "
        f"See :help youcompleteme-customising-highlight-groups" )
