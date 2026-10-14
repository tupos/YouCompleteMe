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

from ycm import neovim_support


class NeovimSupportTest( TestCase ):

  @patch( 'ycm.neovim_support.vim.api.exec_lua',
          return_value = [ 101, 102 ] )
  def test_BatchSetExtmarksUsesOneNeovimCall(
      self,
      exec_lua: MagicMock ) -> None:
    extmarks: list[ neovim_support.Extmark ] = [
      ( 1, 2, { 'hl_group': 'Identifier' } ),
      ( 3, 4, { 'virt_text': [ [ ': int', 'YcmInlayHint' ] ] } ),
    ]

    self.assertEqual(
      [ 101, 102 ],
      neovim_support.BatchSetExtmarks( 7, 11, extmarks )
    )

    exec_lua.assert_called_once_with(
      neovim_support._SET_EXTMARKS_LUA,
      [
        7,
        11,
        extmarks,
      ]
    )


  @patch( 'ycm.neovim_support.vim.api.exec_lua' )
  def test_BatchSetExtmarksDoesNotCallNeovimForEmptyBatch(
      self,
      exec_lua: MagicMock ) -> None:
    self.assertEqual( [], neovim_support.BatchSetExtmarks( 7, 11, [] ) )
    exec_lua.assert_not_called()
