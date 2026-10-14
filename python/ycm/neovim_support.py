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

import vim


Extmark = tuple[ int, int, dict[ str, object ] ]


_SET_EXTMARKS_LUA: str = '''
local buffer_number, namespace_id, extmarks = ...
local extmark_ids = {}
local ok, result = pcall(function()
  for _, extmark in ipairs(extmarks) do
    table.insert(
      extmark_ids,
      vim.api.nvim_buf_set_extmark(
        buffer_number,
        namespace_id,
        extmark[1],
        extmark[2],
        extmark[3]
      )
    )
  end
end)
if not ok then
  for _, extmark_id in ipairs(extmark_ids) do
    vim.api.nvim_buf_del_extmark(
      buffer_number,
      namespace_id,
      extmark_id
    )
  end
  error(result)
end
return extmark_ids
'''


def BatchSetExtmarks(
    buffer_number: int,
    namespace_id: int,
    extmarks: list[ Extmark ] ) -> list[ int ]:
  if not extmarks:
    return []

  extmark_ids: list[ object ] = vim.api.exec_lua(
    _SET_EXTMARKS_LUA,
    [
      buffer_number,
      namespace_id,
      extmarks,
    ]
  )
  return [ int( extmark_id ) for extmark_id in extmark_ids ]
