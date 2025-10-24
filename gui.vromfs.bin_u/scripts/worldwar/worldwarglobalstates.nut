from "%scripts/dagui_library.nut" import *

let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { hasMultiplayerRestritionByBalance } = require("%scripts/user/balance.nut")
let { isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { getWwSetting } = require("%scripts/worldWar/worldWarStates.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")

let isWorldWarEnabled = @() hasFeature("WorldWar")
  && (!isPlatformSony || isCrossPlayEnabled())

function canPlayWorldwar() {
  if (!isMultiplayerPrivilegeAvailable.get()
      || hasMultiplayerRestritionByBalance())
    return false

  if (!isCrossPlayEnabled())
    return false

  let minRankRequired = getWwSetting("minCraftRank", 0)
  let unit = getAllUnits().findvalue(@(unit)
    unit.canUseByPlayer() && unit.rank >= minRankRequired
  )

  return !!unit
}

function canJoinWorldwarBattle() {
  return isWorldWarEnabled() && canPlayWorldwar()
}

function getPlayWorldwarConditionText(fullText = false) {
  if (!isMultiplayerPrivilegeAvailable.get())
    return loc("xbox/noMultiplayer")

  if (!isCrossPlayEnabled())
    return fullText
      ? loc("xbox/actionNotAvailableCrossNetworkPlay")
      : loc("xbox/crossPlayRequired")

  let rankText = colorize("@unlockHeaderColor",
    get_roman_numeral(getWwSetting("minCraftRank", 0)))
  return loc("worldWar/playCondition", { rank = rankText })
}

function getCantPlayWorldwarReasonText() {
  return !canPlayWorldwar() ? getPlayWorldwarConditionText(true) : ""
}

return {
  isWorldWarEnabled
  canPlayWorldwar
  getPlayWorldwarConditionText
  getCantPlayWorldwarReasonText
  canJoinWorldwarBattle
}
