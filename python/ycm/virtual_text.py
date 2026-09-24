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

from ycmd.utils import ToBytes
from ycm import vimsupport


VirtualTextChunk = tuple[ str, str ]
VirtualTextDecoration = tuple[
  int,
  int,
  tuple[ VirtualTextChunk, ... ],
]


def VirtualTextSupported() -> bool:
  return vimsupport.EditorFeatureSupported( 'virtual_text' )


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


  def RenderAtEndOfLine(
      self,
      buffer_number: int,
      line_number: int,
      chunks: list[ VirtualTextChunk ] ) -> None:
    ...


class VirtualTextSnapshotRenderer( Protocol ):

  def Initialise( self ) -> bool:
    ...


  def Clear( self, buffer_number: int ) -> None:
    ...


  def Render(
      self,
      buffer_number: int,
      decorations: list[ VirtualTextDecoration ],
      preserve_existing: bool ) -> None:
    ...


class VimVirtualTextRenderer:

  def __init__(
      self,
      highlight_groups: dict[ str, str ],
      property_type_suffix: str = '' ) -> None:
    self._highlight_groups: dict[ str, str ] = highlight_groups
    self._property_types: dict[ str, str ] = {
      property_type: f'{ property_type }{ property_type_suffix }'
      for property_type in highlight_groups
    }


  def Initialise( self ) -> bool:
    if not vimsupport.EditorFeatureSupported( 'virtual_text' ):
      return False

    property_types: list[ str ] = vimsupport.GetTextPropertyTypes()

    for property_type, default_highlight_group in (
        self._highlight_groups.items() ):
      rendered_property_type: str = self._property_types[ property_type ]
      if rendered_property_type in property_types:
        continue

      highlight_group: str = default_highlight_group
      if (
        rendered_property_type != property_type and
        property_type in property_types
      ):
        property_type_properties: dict[ str, object ] = vim.eval(
          f"prop_type_get( '{ vimsupport.EscapeForVim( property_type ) }' )"
        )
        highlight_group = str(
          property_type_properties.get( 'highlight', highlight_group )
        )

      if not vimsupport.GetIntValue(
          f"hlexists( '{ vimsupport.EscapeForVim( highlight_group ) }' )" ):
        continue

      vimsupport.AddTextPropertyType(
        rendered_property_type,
        highlight = highlight_group,
        start_incl = 1
      )

    return True


  def Clear( self, buffer_number: int ) -> None:
    vimsupport.ClearTextProperties(
      buffer_number,
      prop_types = list( self._property_types.values() )
    )


  def Render(
      self,
      buffer_number: int,
      line_number: int,
      column_number: int,
      chunks: list[ VirtualTextChunk ] ) -> None:
    self._Render(
      buffer_number,
      line_number,
      column_number,
      chunks,
      {}
    )


  def RenderAtEndOfLine(
      self,
      buffer_number: int,
      line_number: int,
      chunks: list[ VirtualTextChunk ] ) -> None:
    self._Render(
      buffer_number,
      line_number,
      0,
      chunks,
      {
        'text_align': 'after',
        'text_wrap': 'wrap',
      }
    )


  def _Render(
      self,
      buffer_number: int,
      line_number: int,
      column_number: int,
      chunks: list[ VirtualTextChunk ],
      options: dict[ str, object ] ) -> None:
    property_range: dict[ str, dict[ str, object ] ] = {
      'start': {
        'line_num': line_number,
        'column_num': column_number,
      }
    }

    for text, property_type in chunks:
      properties: dict[ str, object ] = dict( options )
      properties[ 'text' ] = text
      vimsupport.AddTextPropertyForRange(
        buffer_number,
        None,
        self._property_types.get(
          property_type,
          property_type
        ),
        property_range,
        properties
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
    if not vimsupport.EditorFeatureSupported( 'virtual_text' ):
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
    self._Render(
      buffer_number,
      line_number - 1,
      column_number - 1,
      chunks,
      'inline'
    )


  def RenderAtEndOfLine(
      self,
      buffer_number: int,
      line_number: int,
      chunks: list[ VirtualTextChunk ] ) -> None:
    line: bytes | str = vim.buffers[ buffer_number ][ line_number - 1 ]
    self._Render(
      buffer_number,
      line_number - 1,
      len( ToBytes( line ) ),
      chunks,
      'inline'
    )


  def _Render(
      self,
      buffer_number: int,
      line_index: int,
      column_index: int,
      chunks: list[ VirtualTextChunk ],
      position: str ) -> None:
    options: dict[ str, object ] = {
      'virt_text': chunks,
      'virt_text_pos': position,
    }
    vim.eval(
      f'nvim_buf_set_extmark( { buffer_number }, '
      f'                      { self._namespace_id }, '
      f'                      { line_index }, '
      f'                      { column_index }, '
      f'                      { json.dumps( options ) } )'
    )


class DoubleBufferedVirtualTextRenderer:

  def __init__(
      self,
      renderers: tuple[ VirtualTextRenderer, VirtualTextRenderer ] ) -> None:
    self._renderers: tuple[
      VirtualTextRenderer,
      VirtualTextRenderer,
    ] = renderers
    self._active_renderer_index: int = 0
    self._rendered_decoration_counts: dict[
      VirtualTextDecoration,
      int,
    ] = {}


  def Initialise( self ) -> bool:
    return all( renderer.Initialise() for renderer in self._renderers )


  def Clear( self, buffer_number: int ) -> None:
    for renderer in self._renderers:
      renderer.Clear( buffer_number )
    self._rendered_decoration_counts.clear()


  def _RenderCompleteSnapshot(
      self,
      renderer: VirtualTextRenderer,
      buffer_number: int,
      decorations: list[ VirtualTextDecoration ]
  ) -> dict[ VirtualTextDecoration, int ]:
    decoration_counts: dict[ VirtualTextDecoration, int ] = {}
    for line_number, column_number, chunks in decorations:
      decoration: VirtualTextDecoration = (
        line_number,
        column_number,
        chunks,
      )
      renderer.Render(
        buffer_number,
        line_number,
        column_number,
        list( chunks )
      )
      decoration_counts[ decoration ] = (
        decoration_counts.get( decoration, 0 ) + 1
      )
    return decoration_counts


  def _RenderPreviouslyUnseen(
      self,
      renderer: VirtualTextRenderer,
      buffer_number: int,
      decorations: list[ VirtualTextDecoration ] ) -> None:
    response_counts: dict[ VirtualTextDecoration, int ] = {}
    for line_number, column_number, chunks in decorations:
      decoration: VirtualTextDecoration = (
        line_number,
        column_number,
        chunks,
      )
      response_counts[ decoration ] = response_counts.get( decoration, 0 ) + 1
      if (
        response_counts[ decoration ] <=
        self._rendered_decoration_counts.get( decoration, 0 )
      ):
        continue

      renderer.Render(
        buffer_number,
        line_number,
        column_number,
        list( chunks )
      )
      self._rendered_decoration_counts[ decoration ] = (
        response_counts[ decoration ]
      )


  def Render(
      self,
      buffer_number: int,
      decorations: list[ VirtualTextDecoration ],
      preserve_existing: bool ) -> None:
    current_renderer: VirtualTextRenderer = self._renderers[
      self._active_renderer_index
    ]
    if preserve_existing:
      self._RenderPreviouslyUnseen(
        current_renderer,
        buffer_number,
        decorations
      )
      return

    next_renderer_index: int = 1 - self._active_renderer_index
    next_renderer: VirtualTextRenderer = self._renderers[
      next_renderer_index
    ]
    next_renderer.Clear( buffer_number )
    try:
      decoration_counts = self._RenderCompleteSnapshot(
        next_renderer,
        buffer_number,
        decorations
      )
    except Exception:
      next_renderer.Clear( buffer_number )
      raise

    current_renderer.Clear( buffer_number )
    self._active_renderer_index = next_renderer_index
    self._rendered_decoration_counts = decoration_counts


def CreateVirtualTextRenderer(
    namespace: str,
    highlight_groups: dict[ str, str ] ) -> VirtualTextRenderer:
  if vimsupport.VimIsNeovim():
    return NeovimVirtualTextRenderer( namespace, highlight_groups )

  return VimVirtualTextRenderer( highlight_groups )


def CreateVirtualTextSnapshotRenderer(
    namespace: str,
    highlight_groups: dict[ str, str ] ) -> VirtualTextSnapshotRenderer:
  if vimsupport.VimIsNeovim():
    renderers: tuple[ VirtualTextRenderer, VirtualTextRenderer ] = (
      NeovimVirtualTextRenderer(
        f'{ namespace }_0',
        highlight_groups
      ),
      NeovimVirtualTextRenderer(
        f'{ namespace }_1',
        highlight_groups
      ),
    )
  else:
    renderers = (
      VimVirtualTextRenderer( highlight_groups, '_0' ),
      VimVirtualTextRenderer( highlight_groups, '_1' ),
    )

  return DoubleBufferedVirtualTextRenderer( renderers )
