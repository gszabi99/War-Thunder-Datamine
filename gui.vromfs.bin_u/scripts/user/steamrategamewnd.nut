//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { subscribe } = require("eventbus")
let { format } = require("string")

gui_handlers.SteamRateGame <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/steamRateGame/steamRateGame.tpl"
  onApplyFunc = null
  descLocId = "msgbox/steam/rate_review"
  backgroundImg = null

  getSceneTplView = @() {}

  function initScreen() {
    let textObj= this.scene.findObject("rate_text")
    textObj.setValue(loc(this.descLocId))
    if (this.backgroundImg == null)
      return
    textObj.top = "ph-h-1@frameFooterHeight"

    let obj = this.showSceneBtn("backgroundImg", this.backgroundImg != null)
    obj["background-image"] = this.backgroundImg
  }

  onApply = function() {
    this.onApplyFunc?(true)
    openUrl(format(loc("url/steamstore/item"), ::steam_get_app_id().tostring()))
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

subscribe("steam.overlay_activation", @(p) broadcastEvent("SteamOverlayStateChanged", p))

return {
  open = @(params = {}) handlersManager.loadHandler(gui_handlers.SteamRateGame, params)
}