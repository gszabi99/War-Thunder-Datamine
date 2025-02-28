from "%scripts/dagui_library.nut" import *
from "hudState" import is_hud_visible

let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let isHudVisible = Watched(is_hud_visible())

eventbus_subscribe("on_show_hud", function on_show_hud(payload) {
  let {show = true} = payload
  isHudVisible(show)
  handlersManager.getActiveBaseHandler()?.onShowHud(show, true)
  broadcastEvent("ShowHud", { show = show })
})

return {
  isHudVisible
}
