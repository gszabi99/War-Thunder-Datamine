local { addPromoAction } = require("scripts/promo/promoActions.nut")
local { addPromoButtonConfig } = require("scripts/promo/promoButtonsConfig.nut")
local { getTextWithCrossplayIcon, needShowCrossPlayInfo } = require("scripts/social/crossplay.nut")

local function getWorldWarPromoText(isWwEnabled = null) {
  local text = ::loc("mainmenu/btnWorldwar")
  if (!::is_worldwar_enabled())
    return text

  if ((isWwEnabled ?? ::g_world_war.canJoinWorldwarBattle()))
  {
    local operationText = ::g_world_war.getPlayedOperationText(false)
    if (operationText !=null)
      text = operationText
  }

  text = getTextWithCrossplayIcon(needShowCrossPlayInfo(), text)
  return "{0} {1}".subst(::loc("icon/worldWar"), text)
}

addPromoAction("world_war", @(handler, params, obj) ::g_world_war.openMainWnd(params?[0] == "openMainMenu"))

local promoButtonId = "world_war_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  getText = getWorldWarPromoText
  collapsedIcon = ::loc("icon/worldWar")
  needUpdateByTimer = true
  updateFunctionInHandler = function() {
    local id = promoButtonId
    local isWwEnabled = ::g_world_war.canJoinWorldwarBattle()
    local isVisible = ::g_promo.getShowAllPromoBlocks()
      || (isWwEnabled && ::g_world_war.isWWSeasonActiveShort())

    local buttonObj = ::showBtn(id, isVisible, scene)
    if (!isVisible || !::checkObj(buttonObj))
      return

    ::g_promo.setButtonText(buttonObj, id, getWorldWarPromoText(isWwEnabled))

    if (!::g_promo.isCollapsed(id))
      return

    if (::g_world_war.hasNewNearestAvailableMapToBattle())
      ::g_promo.toggleItem(buttonObj.findObject(id + "_toggle"))
  }
  updateByEvents = ["WWLoadOperation", "WWStopWorldWar",
    "WWShortGlobalStatusChanged", "CrossPlayOptionChanged"]
})
