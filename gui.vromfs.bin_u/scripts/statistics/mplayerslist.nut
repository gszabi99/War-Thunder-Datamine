//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { updateNameMapping } = require("%scripts/user/nameMapping.nut")

local function getMplayersList(team = GET_MPLAYERS_LIST) {
  local list = ::get_mplayers_list(team, true)
  foreach (player in list)
    if (player?.realName && player.realName != "")
      updateNameMapping(player.realName, player.name)

  return list
}


return {
  getMplayersList
}