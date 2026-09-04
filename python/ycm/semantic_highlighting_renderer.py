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

from typing import Protocol

import vim

from ycm import vimsupport


SemanticRange = dict[ str, dict[ str, object ] ]
SemanticHighlight = tuple[ str, SemanticRange ]


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


def CreateSemanticHighlightingRenderer(
    highlight_groups: dict[ str, str ] ) -> SemanticHighlightingRenderer:
  return VimSemanticHighlightingRenderer( highlight_groups )
