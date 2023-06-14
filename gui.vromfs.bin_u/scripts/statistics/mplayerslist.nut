//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { updateNameMapping } = require("%scripts/user/nameMapping.nut")
let { get_mplayers_list } = require("mission")

local function getMplayersList(team = GET_MPLAYERS_LIST) {
  local list = get_mplayers_list(team, true)
  foreach (player in list)
    if (player?.realName && player.realName != "")
      updateNameMapping(player.realName, player.name)
  return list
}

return {
  getMplayersList
}