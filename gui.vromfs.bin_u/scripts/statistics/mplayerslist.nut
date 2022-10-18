let { updateNameMapping } = require("%scripts/user/nameMapping.nut")

local function getMplayersList(team = ::GET_MPLAYERS_LIST) {
  local list = ::get_mplayers_list(team, true)
  foreach (player in list)
    if (player?.realName && player.realName != "")
      updateNameMapping(player.realName, player.name)

  return list
}


return {
  getMplayersList
}