from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { eventbus_subscribe } = require("eventbus")
let { format } = require("string")
let { steam_get_app_id } = require("steam")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")

gui_handlers.SteamRateGame <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/steamRateGame/steamRateGame.tpl"
  onApplyFunc = null
  descLocId = "msgbox/steam/rate_review"
  backgroundImg = null
  backgroundImgRatio = 1

  function getSceneTplView() {
    let closeBtnText = loc("msgbox/btn_later")
    let writeReviewBtnText = loc("btn_share_impressions")
    let maxTextWidth = max(getStringWidthPx(closeBtnText, "fontBigBold"),
      getStringWidthPx(writeReviewBtnText, "fontBigBold"))
    return {
      backgroundImg = this.backgroundImg
      backgroundImgRatio = this.backgroundImgRatio
      descText = loc(this.descLocId)
      closeBtnText
      writeReviewBtnText
      btnWidth = $"{maxTextWidth} + 2*3@blockInterval"
      widthCoeff = (1.0*screen_width()/screen_height() * this.backgroundImgRatio > 1) ? 1 : 3
    }
  }

  function initScreen() {}

  onApply = function() {
    this.onApplyFunc?(true)
    openUrl(format(loc("url/steamstore/item"), steam_get_app_id().tostring()))
  }
  onEventDestroyEmbeddedBrowser = @(_p) base.goBack()
  onEventSteamOverlayStateChanged = function(p) {
    if (!p.active)
      base.goBack()
  }

  goBack = function() {
    this.onApplyFunc?(false)
    base.goBack()
  }
}

eventbus_subscribe("steam.overlay_activation", @(p) broadcastEvent("SteamOverlayStateChanged", p))

return {
  open = @(params = {}) handlersManager.loadHandler(gui_handlers.SteamRateGame, params)
}