from "%scripts/promo/promo.nut" import setPromoButtonText, isPromoCollapsed, togglePromoItem, getShowAllPromoBlocks
from "%scripts/promo/promoActions.nut" import addPromoAction
from "%scripts/promo/promoButtonsConfig.nut" import addPromoButtonConfig
from "%scripts/social/crossplay.nut" import getTextWithCrossplayIcon, needShowCrossPlayInfo
from "%scripts/worldWar/worldWarGlobalStates.nut" import isWorldWarEnabled, canJoinWorldwarBattle
from "%scripts/worldWar/worldWarUtils.nut" import openMainWnd, hasNewNearestAvailableMapToBattle
from "%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut" import isWWSeasonActive
from "%scripts/worldWar/operations/model/wwOperationView.nut" import getPlayedOperationText
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%globalScripts/clientState/initialState.nut" import shouldDisableMenu
from "%scripts/dagui_library.nut" import *

function getWorldWarPromoText(isWwEnabled = null) {
  local text = loc("mainmenu/btnWorldwar")
  if (!isWorldWarEnabled())
    return text

  if ((isWwEnabled ?? canJoinWorldwarBattle())) {
    let operationText = getPlayedOperationText(false)
    if (operationText != "")
      text = operationText
  }

  text = getTextWithCrossplayIcon(needShowCrossPlayInfo(), text)
  return "{0} {1}".subst(loc("icon/worldWar"), text)
}

addPromoAction("world_war", @(_handler, params, _obj) openMainWnd(params?[0] == "openMainMenu"))

const promoButtonId = "world_war_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  getText = getWorldWarPromoText
  collapsedIconLocKey = "icon/worldWar"
  needUpdateByTimer = true
  updateFunctionInHandler = function() {
    const id = promoButtonId
    let isWwEnabled = canJoinWorldwarBattle()
    let isVisible = getShowAllPromoBlocks()
      || (isWwEnabled && isWWSeasonActive())

    let buttonObj = showObjById(id, isVisible, this.scene)
    if (!isVisible || !checkObj(buttonObj))
      return

    setPromoButtonText(buttonObj, id, getWorldWarPromoText(isWwEnabled))

    if ((!shouldDisableMenu && !isProfileReceived.get()) || !isPromoCollapsed(id))
      return

    if (hasNewNearestAvailableMapToBattle())
      togglePromoItem(buttonObj.findObject($"{id}_toggle"))
  }
  updateByEvents = ["WWLoadOperation", "WWStopWorldWar",
    "WWGlobalStatusChanged", "CrossPlayOptionChanged"]
})
