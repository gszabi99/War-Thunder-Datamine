from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/promo/promoActions.nut" import addPromoAction
from "%scripts/promo/promoButtonsConfig.nut" import addPromoButtonConfig
from "%scripts/unlocks/regionalUnlocks.nut" import acceptRegionalUnlock, regionalPromos
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/promo/promo.nut" import getPromoVisibilityById
from "%scripts/viewUtils/paginator.nut" import generatePaginator
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let promoSeenList = require("%scripts/seen/seenList.nut").get(SEEN.REGIONAL_PROMO)

class RegionalUnlocksPromoWnd (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/unlocks/regionalUnlocksPromoWnd.blk"

  curPage = 0

  function initScreen() {
    this.updatePage()
  }

  function updatePage() {
    let { name, image, desc = "", imageRatio = 0.75 } = regionalPromos.get()[this.curPage]
    this.scene.findObject("promo_name").setValue(name)
    this.scene.findObject("promo_desc").setValue(desc)

    let imgObj = this.scene.findObject("promo_image")
    imgObj["background-image"] = image
    imgObj["height"] = $"{imageRatio}w"

    let lastPage = regionalPromos.get().len() - 1
    let paginatorPlace = this.scene.findObject("paginator_place")
    generatePaginator(paginatorPlace, this, this.curPage, lastPage, null, true)
  }

  function goToPage(obj) {
    this.curPage = obj.to_page.tointeger()
    this.updatePage()
  }

  function onAcceptResult(result) {
    this.destroyProgressBox()

    if (result?.error != null)
      this.msgBox("activation_error", loc("mainmenu/regionalUnlockActivationError"), [["ok"]], "ok")
  }

  function onAcceptClick() {
    acceptRegionalUnlock(regionalPromos.get()[this.curPage].id, Callback(this.onAcceptResult, this))
    this.showTaskProgressBox(null, null, 15)
  }

  function onEventUpdateRegionalPromo(_) {
    this.destroyProgressBox()

    if (regionalPromos.get().len() == 0) {
      this.goBack()
      return
    }

    this.curPage = clamp(this.curPage, 0, regionalPromos.get().len() - 1)
    this.updatePage()
  }
}

register_gui_handler("RegionalUnlocksPromoWnd", RegionalUnlocksPromoWnd)

addPromoAction("regional_unlocks", @(_handler, _params, _obj)
  handlersManager.loadHandler(RegionalUnlocksPromoWnd))

promoSeenList.setListGetter(@() regionalPromos.get().map(@(p) p.id))

const PROMO_ID = "regional_unlocks_button"

addPromoButtonConfig({
  promoButtonId = PROMO_ID
  getText = @() loc("mainmenu/newObjectiveAvailable")
  updateByEvents = ["UpdateRegionalPromo"]
  getCustomSeenId = @() "regional_unlocks"
  function updateFunctionInHandler() {
    let show = (regionalPromos.get().len() > 0) && getPromoVisibilityById(PROMO_ID)
    showObjById(PROMO_ID, show, this.scene)
  }
})

regionalPromos.subscribe(function(_) {
  promoSeenList.onListChanged()
  broadcastEvent("UpdateRegionalPromo")
})
