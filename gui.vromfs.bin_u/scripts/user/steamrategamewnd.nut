//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { openUrl } = require("%scripts/onlineShop/url.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { subscribe } = require("eventbus")
let { format } = require("string")

::gui_handlers.SteamRateGame <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/steamRateGame/steamRateGame.tpl"
  onApplyFunc = null

  getSceneTplView = @() {}
  initScreen = @() null

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

subscribe("steam.overlay_activation", @(p) ::broadcastEvent("SteamOverlayStateChanged", p))

return {
  open = @(onApplyFunc = null) ::handlersManager.loadHandler(::gui_handlers.SteamRateGame,
    { onApplyFunc = onApplyFunc })
}