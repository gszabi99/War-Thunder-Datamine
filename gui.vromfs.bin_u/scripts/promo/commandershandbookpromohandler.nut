from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/promo/promo.nut" import getPromoVisibilityById, togglePromoItem, PERFORM_PROMO_ACTION_NAME, performPromoAction, getPromoActionParamsKey
from "%scripts/promo/promoActions.nut" import addPromoAction
from "%scripts/promo/promoButtonsConfig.nut" import addPromoButtonConfig
from "%scripts/unlocks/unlocksState.nut" import getUnlockNameText
from "%scripts/unlocks/unlocksModule.nut" import isUnlockOpened
from "%scripts/unlocks/commandersHandbookState.nut" import getCurrentCmhGroup, getCmhGroupUnlocks, getActiveCmhUnlock, getCmhChapterCompletedTotal, getCmhUnlockProgressData, hasCmhUnclaimedReward
from "%scripts/unlocks/commandersHandbookWnd.nut" import openCommandersHandbookWnd
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let CommandersHandbookPromoHandler = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/empty.blk"

  static function open(params) {
    handlersManager.loadHandler(get_gui_handler("CommandersHandbookPromoHandler"), params)
  }

  function initScreen() {
    this.updateHandler()
  }

  function updateHandler() {
    let group = getCurrentCmhGroup()
    let activeBlk = group != null ? getActiveCmhUnlock(group) : null
    if (activeBlk == null) {
      this.guiScene.replaceContentFromText(this.scene, "", 0, this)
      return
    }

    let { completed, total } = getCmhChapterCompletedTotal()
    let progress = getCmhUnlockProgressData(activeBlk)
    let name = getUnlockNameText(-1, activeBlk.id)
    let view = {
      action = PERFORM_PROMO_ACTION_NAME
      performActionId = getPromoActionParamsKey(this.scene.id)
      statusText = $"{completed}/{total}"
      unlockName = isUnlockOpened(activeBlk.id) ? name : "".concat(loc("unlocks/next"), ": ", name)
      unlockDesc = $"#{activeBlk.id}/desc"
      needProgressBar = progress.hasProgress
      progressCurValue = progress.curVal
      progressMaxValue = progress.maxVal
      hasUnclaimed = hasCmhUnclaimedReward()
    }
    let data = handyman.renderCached("%gui/promo/promoCommandersHandbook.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
  }

  performAction = @(obj) performPromoAction(this, obj)
  function performActionCollapsed(obj) {
    let buttonObj = obj.getParent()
    this.performAction(buttonObj.findObject(getPromoActionParamsKey(buttonObj.id)))
  }

  onToggleItem = togglePromoItem

  onEventCurrentGameModeIdChanged = @(_p) this.updateHandler()
  onEventUnlocksCacheInvalidate   = @(_p) this.updateHandler()
}
register_gui_handler("CommandersHandbookPromoHandler", CommandersHandbookPromoHandler)

addPromoAction("commanders_handbook", @(_handler, _params, _obj)
  openCommandersHandbookWnd({ openGroup = getCurrentCmhGroup() }))

const PROMO_BUTTON_ID = "commanders_handbook_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = PROMO_BUTTON_ID
  buttonType = "battleTask"
  updateByEvents = ["CurrentGameModeIdChanged", "UnlocksCacheInvalidate"]
  updateFunctionInHandler = function() {
    let id = PROMO_BUTTON_ID
    let group = getCurrentCmhGroup()
    let isVisible = group != null && getCmhGroupUnlocks(group).len() > 0
      && getPromoVisibilityById(id)
    let buttonObj = showObjById(id, isVisible, this.scene)
    if (!isVisible || !buttonObj?.isValid())
      return

    CommandersHandbookPromoHandler.open({ scene = buttonObj })
  }
})
