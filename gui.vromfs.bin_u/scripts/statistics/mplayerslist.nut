from "%scripts/dagui_library.nut" import *

let { updateNameMapping } = require("%scripts/user/nameMapping.nut")
let { get_mplayers_list, GET_MPLAYERS_LIST } = require("mission")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { get_mplayer_color } = require("%scripts/utils_sa.nut")
let { getPlayerFullName } = require("%scripts/contacts/contactsInfo.nut")

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

return {
  getMplayersList
  buildMplayerName
}