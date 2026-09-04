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
_NEOVIM_HIGHLIGHT_PRIORITY: int = 125


def SemanticHighlightingSupported() -> bool:
  if vimsupport.VimIsNeovim():
    return vimsupport.GetBoolValue( "has( 'nvim-0.5' )" )
  return True


class SemanticHighlightingRenderer( Protocol ):

  def Initialise( self ) -> bool:
    ...


  def Render(
      self,
      buffer_number: int,
      highlights: list[ SemanticHighlight ] ) -> list[ str ]:
    ...


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


  def Render(
      self,
      buffer_number: int,
      highlights: list[ SemanticHighlight ] ) -> list[ str ]:
    previous_property_id = self._property_id
    self._property_id = _NextTextPropertyID()
    missing_property_types: list[ str ] = []
    missing_property_type_set: set[ str ] = set()

    for property_type, property_range in highlights:
      if property_type in missing_property_type_set:
        continue

      try:
        vimsupport.AddTextPropertyForRange(
          buffer_number,
          self._property_id,
          property_type,
          property_range
        )
      except vim.error as error:
        if 'E971:' not in str( error ):
          raise
        missing_property_types.append( property_type )
        missing_property_type_set.add( property_type )

    vimsupport.ClearTextProperties(
      buffer_number,
      prop_id = previous_property_id
    )
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


  def Render(
      self,
      buffer_number: int,
      highlights: list[ SemanticHighlight ] ) -> list[ str ]:
    next_namespace_index: int = 1 - self._active_namespace_index
    current_namespace_id: int = self._namespace_ids[
      self._active_namespace_index
    ]
    next_namespace_id: int = self._namespace_ids[ next_namespace_index ]
    property_type_support: dict[ str, bool ] = {}
    missing_property_types: list[ str ] = []

    try:
      for property_type, property_range in highlights:
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
        vim.eval(
          f'nvim_buf_set_extmark( { buffer_number }, '
          f'                      { next_namespace_id }, '
          f'                      { int( start[ "line_num" ] ) - 1 }, '
          f'                      { int( start[ "column_num" ] ) - 1 }, '
          f'                      { json.dumps( options ) } )'
        )
    except Exception:
      # Discard a partially rendered snapshot without disturbing the current
      # one.
      self._ClearNamespace( buffer_number, next_namespace_id )
      raise

    self._ClearNamespace( buffer_number, current_namespace_id )
    self._active_namespace_index = next_namespace_index
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
