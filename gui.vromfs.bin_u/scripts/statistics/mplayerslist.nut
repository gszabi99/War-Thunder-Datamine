from "%scripts/user/nameMapping.nut" import updateNameMapping
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/utils_sa.nut" import get_mplayer_color
from "%scripts/contacts/contactsInfo.nut" import getPlayerFullName
from "mission" import get_mplayers_list, GET_MPLAYERS_LIST
from "%scripts/dagui_library.nut" import *

function getMplayersList(team = GET_MPLAYERS_LIST) {
  local list = get_mplayers_list(team, true)
  foreach (player in list) {
    let { realName = "", name } = player
    if (realName != "")
      updateNameMapping(realName, name != realName ? name : null)
  }
  return list
}

function buildMplayerName(player, colored = true, withClanTag = true, withUnit = false, unitNameLoc = "") {
  if (!player)
    return ""

  local unitName = ""
  if (withUnit) {
    if (unitNameLoc == "") {
      let unitId = player.aircraftName
      if (unitId != "")
        unitNameLoc = loc($"{unitId}_1")
    }
    if (unitNameLoc != "")
      unitName = loc("ui/parentheses", { text = unitNameLoc })
  }

  let clanTag = withClanTag && !player?.isBot ? player.clanTag : ""
  let name = getPlayerFullName(player?.isBot ? player.name : getPlayerName(player.name),
                                              clanTag,
                                              unitName)

  return colored ? colorize(get_mplayer_color(player), name) : name
}

return freeze({
  getMplayersList
  buildMplayerName
})