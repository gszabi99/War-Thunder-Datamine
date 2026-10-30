from "%scripts/unit/unitsData.nut" import getAllUnits
from "%scripts/social/crossplay.nut" import isCrossPlayEnabled
from "%sqstd/platform.nut" import isSony
from "%scripts/user/balance.nut" import hasMultiplayerRestritionByBalance
from "%scripts/user/xboxFeatures.nut" import isMultiplayerPrivilegeAvailable
from "%scripts/worldWar/worldWarCfgState.nut" import getWwSetting
from "%globalScripts/loc_helpers.nut" import locByVendor
from "%scripts/dagui_library.nut" import *

let isWorldWarEnabled = @() hasFeature("WorldWar")
  && (!isSony || isCrossPlayEnabled())

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
      ? locByVendor("xbox/actionNotAvailableCrossNetworkPlay")
      : locByVendor("xbox/crossPlayRequired")

  let rankText = colorize("@unlockHeaderColor",
    get_roman_numeral(getWwSetting("minCraftRank", 0)))
  return loc("worldWar/playCondition", { rank = rankText })
}

function getCantPlayWorldwarReasonText() {
  return !canPlayWorldwar() ? getPlayWorldwarConditionText(true) : ""
}

return freeze({
  isWorldWarEnabled
  canPlayWorldwar
  getPlayWorldwarConditionText
  getCantPlayWorldwarReasonText
  canJoinWorldwarBattle
})
