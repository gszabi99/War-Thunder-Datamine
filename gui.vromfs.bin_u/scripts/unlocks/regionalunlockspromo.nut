from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { acceptRegionalUnlock, regionalPromos
} = require("%scripts/unlocks/regionalUnlocks.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getPromoVisibilityById } = require("%scripts/promo/promo.nut")
let promoSeenList = require("%scripts/seen/seenList.nut").get(SEEN.REGIONAL_PROMO)

let class RegionalUnlocksPromoWnd extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/unlocks/regionalUnlocksPromoWnd.blk"

  curPage = 0

  function initScreen() {
    this.updatePage()
  }

  function updatePage() {
    let { name, image, desc = "", imageRatio = 0.75 } = regionalPromos.value[this.curPage]
    this.scene.findObject("promo_name").setValue(name)
    this.scene.findObject("promo_desc").setValue(desc)

    let imgObj = this.scene.findObject("promo_image")
    imgObj["background-image"] = image
    imgObj["height"] = $"{imageRatio}w"

    let lastPage = regionalPromos.value.len() - 1
    let paginatorPlace = this.scene.findObject("paginator_place")
    ::generatePaginator(paginatorPlace, this, this.curPage, lastPage, null, true)
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
    acceptRegionalUnlock(regionalPromos.value[this.curPage].id, Callback(this.onAcceptResult, this))
    this.showTaskProgressBox(null, null, 15)
  }

  function onEventUpdateRegionalPromo(_) {
    this.destroyProgressBox()

    if (regionalPromos.value.len() == 0) {
      this.goBack()
      return
    }

    this.curPage = clamp(this.curPage, 0, regionalPromos.value.len() - 1)
    this.updatePage()
  }
}

gui_handlers.RegionalUnlocksPromoWnd <- RegionalUnlocksPromoWnd

addPromoAction("regional_unlocks", @(_handler, _params, _obj)
  handlersManager.loadHandler(RegionalUnlocksPromoWnd))

promoSeenList.setListGetter(@() regionalPromos.value.map(@(p) p.id))

const PROMO_ID = "regional_unlocks_button"

addPromoButtonConfig({
  promoButtonId = PROMO_ID
  getText = @() loc("mainmenu/newObjectiveAvailable")
  updateByEvents = ["UpdateRegionalPromo"]
  getCustomSeenId = @() "regional_unlocks"
  function updateFunctionInHandler() {
    let show = (regionalPromos.value.len() > 0) && getPromoVisibilityById(PROMO_ID)
    showObjById(PROMO_ID, show, this.scene)
  }
})

regionalPromos.subscribe(function(_) {
  promoSeenList.onListChanged()
  broadcastEvent("UpdateRegionalPromo")
})
