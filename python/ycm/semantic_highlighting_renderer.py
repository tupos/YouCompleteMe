# Copyright (C) 2026, YouCompleteMe Contributors
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

import json
from typing import Protocol

import vim

from ycm import vimsupport


SemanticRange = dict[ str, dict[ str, object ] ]
SemanticHighlight = tuple[ str, SemanticRange ]
SemanticHighlightKey = tuple[ str, int, int, int, int ]
_NEOVIM_HIGHLIGHT_PRIORITY: int = 125


def SemanticHighlightingSupported() -> bool:
  return vimsupport.EditorFeatureSupported(
    'semantic_highlighting' )


class SemanticHighlightingRenderer( Protocol ):

  def Initialise( self ) -> bool:
    ...


  def Render(
      self,
      buffer_number: int,
      highlights: list[ SemanticHighlight ],
      preserve_existing: bool ) -> list[ str ]:
    ...


def _HighlightKey( highlight: SemanticHighlight ) -> SemanticHighlightKey:
  property_type, property_range = highlight
  start: dict[ str, object ] = property_range[ 'start' ]
  end: dict[ str, object ] = property_range[ 'end' ]
  return (
    property_type,
    int( start[ 'line_num' ] ),
    int( start[ 'column_num' ] ),
    int( end[ 'line_num' ] ),
    int( end[ 'column_num' ] ),
  )


_NEXT_TEXT_PROPERTY_ID: int = 70784


def _NextTextPropertyID() -> int:
  global _NEXT_TEXT_PROPERTY_ID
  try:
    return _NEXT_TEXT_PROPERTY_ID
  finally:
    _NEXT_TEXT_PROPERTY_ID += 1


class VimSemanticHighlightingRenderer:

  def __init__( self, highlight_groups: dict[ str, str ] ) -> None:
    self._highlight_groups: dict[ str, str ] = highlight_groups
    self._property_id: int = _NextTextPropertyID()
    self._rendered_highlights: set[ SemanticHighlightKey ] = set()


  def Initialise( self ) -> bool:
    property_types: list[ str ] = vimsupport.GetTextPropertyTypes()

    for property_type, highlight_group in self._highlight_groups.items():
      if property_type in property_types:
        continue

      if not vimsupport.GetIntValue(
          f"hlexists( '{ vimsupport.EscapeForVim( highlight_group ) }' )" ):
        continue

      vimsupport.AddTextPropertyType(
        property_type,
        highlight = highlight_group,
        priority = 0
      )

    return True


  def _RenderHighlights(
      self,
      buffer_number: int,
      property_id: int,
      highlights: list[ SemanticHighlight ],
      preserve_existing: bool,
      rendered_highlights: set[ SemanticHighlightKey ] ) -> list[ str ]:
    missing_property_types: list[ str ] = []
    missing_property_type_set: set[ str ] = set()

    for highlight in highlights:
      highlight_key: SemanticHighlightKey = _HighlightKey( highlight )
      if (
        preserve_existing and
        highlight_key in self._rendered_highlights
      ):
        continue

      property_type, property_range = highlight
      if property_type in missing_property_type_set:
        continue

      try:
        vimsupport.AddTextPropertyForRange(
          buffer_number,
          property_id,
          property_type,
          property_range
        )
      except vim.error as error:
        if 'E971:' not in str( error ):
          raise
        missing_property_types.append( property_type )
        missing_property_type_set.add( property_type )
        continue

      rendered_highlights.add( highlight_key )

    return missing_property_types


  def Render(
      self,
      buffer_number: int,
      highlights: list[ SemanticHighlight ],
      preserve_existing: bool ) -> list[ str ]:
    previous_property_id = self._property_id
    property_id: int = (
      previous_property_id
      if preserve_existing
      else _NextTextPropertyID()
    )
    rendered_highlights: set[ SemanticHighlightKey ] = set()

    try:
      missing_property_types: list[ str ] = self._RenderHighlights(
        buffer_number,
        property_id,
        highlights,
        preserve_existing,
        rendered_highlights
      )
    except Exception:
      if preserve_existing:
        self._rendered_highlights.update( rendered_highlights )
      else:
        vimsupport.ClearTextProperties(
          buffer_number,
          prop_id = property_id
        )
      raise

    if preserve_existing:
      self._rendered_highlights.update( rendered_highlights )
    else:
      vimsupport.ClearTextProperties(
        buffer_number,
        prop_id = previous_property_id
      )
      self._property_id = property_id
      self._rendered_highlights = rendered_highlights

    return missing_property_types


class NeovimSemanticHighlightingRenderer:

  def __init__(
      self,
      namespace: str,
      highlight_groups: dict[ str, str ] ) -> None:
    self._highlight_groups: dict[ str, str ] = highlight_groups
    escaped_namespace: str = vimsupport.EscapeForVim( namespace )
    self._namespace_ids: tuple[ int, int ] = (
      vimsupport.GetIntValue(
        f"nvim_create_namespace( '{ escaped_namespace }_0' )"
      ),
      vimsupport.GetIntValue(
        f"nvim_create_namespace( '{ escaped_namespace }_1' )"
      ),
    )
    self._active_namespace_index: int = 0
    self._rendered_highlights: set[ SemanticHighlightKey ] = set()


  def Initialise( self ) -> bool:
    if not SemanticHighlightingSupported():
      return False

    for highlight_group, default_highlight_group in (
        self._highlight_groups.items() ):
      vim.command(
        f'highlight default link '
        f'{ highlight_group } { default_highlight_group }'
      )

    return True


  def _ClearNamespace(
      self,
      buffer_number: int,
      namespace_id: int ) -> None:
    vim.eval(
      f'nvim_buf_clear_namespace( { buffer_number }, '
      f'                          { namespace_id }, '
      f'                          0, '
      f'                          -1 )'
    )


  def _DeleteExtmark(
      self,
      buffer_number: int,
      namespace_id: int,
      extmark_id: int ) -> None:
    vim.eval(
      f'nvim_buf_del_extmark( { buffer_number }, '
      f'                      { namespace_id }, '
      f'                      { extmark_id } )'
    )


  def _RenderHighlights(
      self,
      buffer_number: int,
      namespace_id: int,
      highlights: list[ SemanticHighlight ],
      preserve_existing: bool,
      rendered_highlights: set[ SemanticHighlightKey ],
      rendered_extmark_ids: list[ int ] ) -> list[ str ]:
    property_type_support: dict[ str, bool ] = {}
    missing_property_types: list[ str ] = []

    for highlight in highlights:
      highlight_key: SemanticHighlightKey = _HighlightKey( highlight )
      if (
        preserve_existing and
        highlight_key in self._rendered_highlights
      ):
        continue

      property_type, property_range = highlight
      if property_type not in property_type_support:
        property_type_support[ property_type ] = (
          property_type in self._highlight_groups or
          vimsupport.GetBoolValue(
            f"hlexists( '"
            f"{ vimsupport.EscapeForVim( property_type ) }' )"
          )
        )
        if not property_type_support[ property_type ]:
          missing_property_types.append( property_type )

      if not property_type_support[ property_type ]:
        continue

      start: dict[ str, object ] = property_range[ 'start' ]
      end: dict[ str, object ] = property_range[ 'end' ]
      options: dict[ str, object ] = {
        'end_row': int( end[ 'line_num' ] ) - 1,
        'end_col': int( end[ 'column_num' ] ) - 1,
        'hl_group': property_type,
        'priority': _NEOVIM_HIGHLIGHT_PRIORITY,
      }
      rendered_extmark_ids.append( vimsupport.GetIntValue(
        f'nvim_buf_set_extmark( { buffer_number }, '
        f'                      { namespace_id }, '
        f'                      { int( start[ "line_num" ] ) - 1 }, '
        f'                      { int( start[ "column_num" ] ) - 1 }, '
        f'                      { json.dumps( options ) } )'
      ) )
      rendered_highlights.add( highlight_key )

    return missing_property_types


  def Render(
      self,
      buffer_number: int,
      highlights: list[ SemanticHighlight ],
      preserve_existing: bool ) -> list[ str ]:
    next_namespace_index: int = 1 - self._active_namespace_index
    current_namespace_id: int = self._namespace_ids[
      self._active_namespace_index
    ]
    next_namespace_id: int = self._namespace_ids[ next_namespace_index ]
    target_namespace_id: int = (
      current_namespace_id
      if preserve_existing
      else next_namespace_id
    )
    rendered_highlights: set[ SemanticHighlightKey ] = set()
    rendered_extmark_ids: list[ int ] = []

    try:
      missing_property_types: list[ str ] = self._RenderHighlights(
        buffer_number,
        target_namespace_id,
        highlights,
        preserve_existing,
        rendered_highlights,
        rendered_extmark_ids
      )
    except Exception:
      if preserve_existing:
        for extmark_id in rendered_extmark_ids:
          self._DeleteExtmark(
            buffer_number,
            target_namespace_id,
            extmark_id
          )
      else:
        self._ClearNamespace( buffer_number, target_namespace_id )
      raise

    if preserve_existing:
      self._rendered_highlights.update( rendered_highlights )
    else:
      self._ClearNamespace( buffer_number, current_namespace_id )
      self._active_namespace_index = next_namespace_index
      self._rendered_highlights = rendered_highlights

    return missing_property_types


def CreateSemanticHighlightingRenderer(
    namespace: str,
    highlight_groups: dict[ str, str ] ) -> SemanticHighlightingRenderer:
  if vimsupport.VimIsNeovim():
    return NeovimSemanticHighlightingRenderer(
      namespace,
      highlight_groups
    )

  return VimSemanticHighlightingRenderer( highlight_groups )
