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

from unittest import TestCase
from unittest.mock import MagicMock, patch

from ycm.tests.test_utils import MockVimModule
MockVimModule()

from ycm import hierarchy_tree


Location = dict[ str, object ]
HierarchyItem = dict[ str, object ]
HierarchyLine = tuple[ dict[ str, object ], int ]


def _Location(
    filepath: str,
    line: int,
    column: int,
    description: str = '' ) -> Location:
  return {
    'filepath': filepath,
    'line_num': line,
    'column_num': column,
    'description': description,
  }


def _Item(
    name: str,
    kind: str,
    locations: list[ Location ],
    root_location: Location | None = None ) -> HierarchyItem:
  item: HierarchyItem = {
    'name': name,
    'kind': kind,
    'locations': locations,
  }
  if root_location is not None:
    item[ 'root_location' ] = root_location
  return item


class HierarchyTreeTest( TestCase ):

  def test_HandlesEncodeNodeAndLocationIndexes( self ) -> None:
    handle: int = hierarchy_tree.make_handle( 12, 34 )

    self.assertEqual( 12, hierarchy_tree.handle_to_index( handle ) )
    self.assertEqual(
      34,
      hierarchy_tree.handle_to_location_index( handle )
    )
    self.assertEqual( 12, hierarchy_tree.handle_to_index( -handle ) )
    self.assertEqual(
      34,
      hierarchy_tree.handle_to_location_index( -handle )
    )


  def test_SetRootNodeFormatsLocation( self ) -> None:
    tree: hierarchy_tree.HierarchyTree = hierarchy_tree.HierarchyTree()
    root: HierarchyItem = _Item(
      'Root',
      'Class',
      [
        _Location(
          '/project/root.cc',
          3,
          7,
          '  first declaration  '
        ),
      ]
    )

    lines: list[ HierarchyLine ] = tree.SetRootNode( [ root ], 'type' )

    self.assertEqual(
      [
        (
          {
            'indent': 0,
            'icon': '+',
            'symbol': 'Root',
            'kind': 'Class',
            'filepath': 'root.cc',
            'line_num': '3',
            'description': 'first declaration',
          },
          hierarchy_tree.make_handle( 0, 0 )
        ),
      ],
      lines
    )


  def test_UpdateHierarchyFormatsParentsChildrenAndLocations( self ) -> None:
    tree: hierarchy_tree.HierarchyTree = hierarchy_tree.HierarchyTree()
    root: HierarchyItem = _Item(
      'Root',
      'Class',
      [ _Location( '/project/root.cc', 3, 7, 'root' ) ]
    )
    parent: HierarchyItem = _Item(
      'Parent',
      'Class',
      [ _Location( '/project/parent.cc', 2, 4, 'parent' ) ]
    )
    child: HierarchyItem = _Item(
      'Child',
      'Method',
      [
        _Location( '/project/child.cc', 10, 5, ' first call ' ),
        _Location( '/other/child.cc', 20, 9, ' second call ' ),
      ]
    )

    tree.SetRootNode( [ root ], 'type' )
    tree.UpdateHierarchy( 0, [ child ], 'down' )
    tree.UpdateHierarchy( 0, [ parent ], 'up' )
    lines: list[ HierarchyLine ] = tree.HierarchyToLines()

    self.assertEqual(
      [
        (
          'Parent',
          2,
          '+',
          'parent.cc',
          '2',
          'parent',
          -hierarchy_tree.make_handle( 1, 0 ),
        ),
        (
          'Root',
          0,
          '-',
          'root.cc',
          '3',
          'root',
          hierarchy_tree.make_handle( 0, 0 ),
        ),
        (
          'Child',
          2,
          '+',
          'child.cc',
          '10',
          'first call',
          hierarchy_tree.make_handle( 1, 0 ),
        ),
        (
          'Child',
          2,
          '+',
          'child.cc',
          '20',
          'second call',
          hierarchy_tree.make_handle( 1, 1 ),
        ),
      ],
      [
        (
          line[ 'symbol' ],
          line[ 'indent' ],
          line[ 'icon' ],
          line[ 'filepath' ],
          line[ 'line_num' ],
          line[ 'description' ],
          handle,
        )
        for line, handle in lines
      ]
    )


  def test_ResolutionStateArgumentsAndRootChanges( self ) -> None:
    for kind, up_direction, down_direction in [
      ( 'type', 'supertypes', 'subtypes' ),
      ( 'call', 'outgoing', 'incoming' ),
    ]:
      with self.subTest( kind = kind ):
        tree: hierarchy_tree.HierarchyTree = hierarchy_tree.HierarchyTree()
        root: HierarchyItem = _Item(
          'Root',
          'Class',
          [ _Location( '/project/root.cc', 3, 7 ) ]
        )
        parent: HierarchyItem = _Item(
          'Parent',
          'Class',
          [ _Location( '/project/parent.cc', 2, 4 ) ]
        )
        child: HierarchyItem = _Item(
          'Child',
          'Class',
          [ _Location( '/project/child.cc', 10, 5 ) ]
        )

        tree.SetRootNode( [ root ], kind )
        self.assertTrue( tree.ShouldResolveItem( 0, 'up' ) )
        self.assertTrue( tree.ShouldResolveItem( 0, 'down' ) )

        tree.UpdateHierarchy( 0, [ child ], 'down' )
        tree.UpdateHierarchy( 0, [ parent ], 'up' )
        child_handle: int = hierarchy_tree.make_handle( 1, 0 )
        parent_handle: int = -hierarchy_tree.make_handle( 1, 0 )

        self.assertFalse( tree.ShouldResolveItem( 0, 'up' ) )
        self.assertFalse( tree.ShouldResolveItem( 0, 'down' ) )
        self.assertTrue(
          tree.ShouldResolveItem( parent_handle, 'up' )
        )
        self.assertTrue(
          tree.ShouldResolveItem( child_handle, 'down' )
        )

        self.assertEqual(
          [
            f'Resolve{ kind.title() }HierarchyItem',
            parent,
            up_direction,
          ],
          tree.ResolveArguments( parent_handle, 'up' )
        )
        self.assertEqual(
          [
            f'Resolve{ kind.title() }HierarchyItem',
            child,
            down_direction,
          ],
          tree.ResolveArguments( child_handle, 'down' )
        )

        tree.UpdateHierarchy( parent_handle, [], 'up' )
        tree.UpdateHierarchy( child_handle, [], 'down' )
        self.assertFalse(
          tree.ShouldResolveItem( parent_handle, 'up' )
        )
        self.assertFalse(
          tree.ShouldResolveItem( child_handle, 'down' )
        )

        self.assertTrue(
          tree.UpdateChangesRoot( parent_handle, 'down' )
        )
        self.assertTrue(
          tree.UpdateChangesRoot( child_handle, 'up' )
        )
        self.assertFalse(
          tree.UpdateChangesRoot( parent_handle, 'up' )
        )
        self.assertFalse(
          tree.UpdateChangesRoot( child_handle, 'down' )
        )


  def test_LocationLookupAndJumpUseHandleDirection( self ) -> None:
    tree: hierarchy_tree.HierarchyTree = hierarchy_tree.HierarchyTree()
    root: HierarchyItem = _Item(
      'Root',
      'Class',
      [ _Location( '/project/root.cc', 3, 7 ) ]
    )
    parent: HierarchyItem = _Item(
      'Parent',
      'Class',
      [ _Location( '/project/parent.cc', 2, 4 ) ]
    )
    child_root_location: Location = _Location(
      '/project/child_definition.cc',
      9,
      4
    )
    child: HierarchyItem = _Item(
      'Child',
      'Method',
      [
        _Location( '/project/child.cc', 10, 5 ),
        _Location( '/other/child.cc', 20, 9 ),
      ],
      child_root_location
    )

    tree.SetRootNode( [ root ], 'type' )
    tree.UpdateHierarchy( 0, [ child ], 'down' )
    tree.UpdateHierarchy( 0, [ parent ], 'up' )
    child_handle: int = hierarchy_tree.make_handle( 1, 1 )
    parent_handle: int = -hierarchy_tree.make_handle( 1, 0 )

    self.assertEqual(
      ( '/project/child_definition.cc', 9, 4 ),
      tree.HandleToRootLocation( child_handle )
    )
    self.assertEqual(
      ( '/project/parent.cc', 2, 4 ),
      tree.HandleToRootLocation( parent_handle )
    )

    jump_to_location: MagicMock
    with patch(
      'ycm.hierarchy_tree.vimsupport.JumpToLocation'
    ) as jump_to_location:
      tree.JumpToItem( child_handle, 'same-buffer' )
      jump_to_location.assert_called_once_with(
        '/other/child.cc',
        20,
        9,
        '',
        'same-buffer'
      )

      jump_to_location.reset_mock()
      tree.JumpToItem( parent_handle, 'split' )
      jump_to_location.assert_called_once_with(
        '/project/parent.cc',
        2,
        4,
        '',
        'split'
      )


  def test_ResetAllowsTreeReuse( self ) -> None:
    tree: hierarchy_tree.HierarchyTree = hierarchy_tree.HierarchyTree()
    initial_root: HierarchyItem = _Item(
      'Initial',
      'Class',
      [ _Location( '/project/initial.cc', 1, 1 ) ]
    )
    replacement_root: HierarchyItem = _Item(
      'Replacement',
      'Function',
      [ _Location( '/project/replacement.cc', 5, 3 ) ]
    )

    tree.SetRootNode( [ initial_root ], 'type' )
    tree.UpdateHierarchy( 0, [], 'down' )
    tree.Reset()

    self.assertEqual( [], tree.SetRootNode( [], 'call' ) )
    lines: list[ HierarchyLine ] = tree.SetRootNode(
      [ replacement_root ],
      'call'
    )
    self.assertEqual(
      [ 'Replacement' ],
      [ line[ 'symbol' ] for line, _handle in lines ]
    )
    self.assertEqual(
      'ResolveCallHierarchyItem',
      tree.ResolveArguments( 0, 'down' )[ 0 ]
    )
