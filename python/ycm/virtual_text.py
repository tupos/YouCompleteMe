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


VirtualTextChunk = tuple[ str, str ]


class VirtualTextRenderer( Protocol ):

  def Initialise( self ) -> bool:
    ...


  def Clear( self, buffer_number: int ) -> None:
    ...


  def Render(
      self,
      buffer_number: int,
      line_number: int,
      column_number: int,
      chunks: list[ VirtualTextChunk ] ) -> None:
    ...


class VimVirtualTextRenderer:

  def __init__( self, highlight_groups: dict[ str, str ] ) -> None:
    self._highlight_groups: dict[ str, str ] = highlight_groups


  def Initialise( self ) -> bool:
    if not vimsupport.VimVersionAtLeast( '9.0.214' ):
      return False

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
        start_incl = 1
      )

    return True


  def Clear( self, buffer_number: int ) -> None:
    vimsupport.ClearTextProperties(
      buffer_number,
      prop_types = list( self._highlight_groups )
    )


  def Render(
      self,
      buffer_number: int,
      line_number: int,
      column_number: int,
      chunks: list[ VirtualTextChunk ] ) -> None:
    property_range: dict[ str, dict[ str, object ] ] = {
      'start': {
        'line_num': line_number,
        'column_num': column_number,
      }
    }

    for text, property_type in chunks:
      vimsupport.AddTextPropertyForRange(
        buffer_number,
        None,
        property_type,
        property_range,
        {
          'text': text,
        }
      )


class NeovimVirtualTextRenderer:

  def __init__(
      self,
      namespace: str,
      highlight_groups: dict[ str, str ] ) -> None:
    self._highlight_groups: dict[ str, str ] = highlight_groups
    self._namespace_id: int = vimsupport.GetIntValue(
      f"nvim_create_namespace( '{ vimsupport.EscapeForVim( namespace ) }' )"
    )


  def Initialise( self ) -> bool:
    if not vimsupport.GetBoolValue( "has( 'nvim-0.10' )" ):
      return False

    for highlight_group, default_highlight_group in (
        self._highlight_groups.items() ):
      vim.command(
        f'highlight default link '
        f'{ highlight_group } { default_highlight_group }'
      )

    return True


  def Clear( self, buffer_number: int ) -> None:
    vim.eval(
      f'nvim_buf_clear_namespace( { buffer_number }, '
      f'                          { self._namespace_id }, '
      f'                          0, '
      f'                          -1 )'
    )


  def Render(
      self,
      buffer_number: int,
      line_number: int,
      column_number: int,
      chunks: list[ VirtualTextChunk ] ) -> None:
    options: dict[ str, object ] = {
      'virt_text': chunks,
      'virt_text_pos': 'inline',
    }
    vim.eval(
      f'nvim_buf_set_extmark( { buffer_number }, '
      f'                      { self._namespace_id }, '
      f'                      { line_number - 1 }, '
      f'                      { column_number - 1 }, '
      f'                      { json.dumps( options ) } )'
    )


def CreateVirtualTextRenderer(
    namespace: str,
    highlight_groups: dict[ str, str ] ) -> VirtualTextRenderer:
  if vimsupport.VimIsNeovim():
    return NeovimVirtualTextRenderer( namespace, highlight_groups )

  return VimVirtualTextRenderer( highlight_groups )
