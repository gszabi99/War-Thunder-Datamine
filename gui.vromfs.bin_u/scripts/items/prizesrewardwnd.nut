//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let class PrizesRewardWnd extends ::gui_handlers.trophyRewardWnd {
  wndType = handlerType.MODAL

  chestDefaultImg = "every_day_award_trophy_big"
  rewardListLocId = "mainmenu/rewardsList"

  getTitle = @() loc("unlocks/entitlement")

  prepareParams = @() this.shrinkedConfigsArray = this.configsArray

  isRouletteStarted = @() false

  function openChest() {
    if (this.opened)
      return false

    this.opened = true
    this.updateWnd()
    return true
  }

  function getIconData() {
    if (!this.opened)
      return ::LayersIcon.getIconData(this.chestDefaultImg)

    return "".concat(::LayersIcon.getIconData($"{this.chestDefaultImg}_opened"),
      this.getRewardImage())
  }

  function checkSkipAnim() {
    if (this.animFinished)
      return true

    let animObj = this.scene.findObject("open_chest_animation")
    if (checkObj(animObj))
      animObj.animation = "hide"
    this.animFinished = true

    this.openChest()
    return false
  }

  notifyTrophyVisible = @() null
  updateRewardPostscript = @() null
}

::gui_handlers.PrizesRewardWnd <- PrizesRewardWnd

return @(params) ::handlersManager.loadHandler(PrizesRewardWnd, params)
