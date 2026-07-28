from "%scripts/dagui_library.nut" import *
from "hudState" import is_hud_visible

let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")

let isHudVisible = Watched(is_hud_visible())
let isMenuVisible = mkWatched(persist, "isMenuVisible", true)
let needShowHud = Computed(function() {
  if (!isInBattleState.get())
    return isMenuVisible.get()

  return isHudVisible.get() || isAAComplexMenuActive.get()
})

function onShowHud(show) {
  handlersManager.getActiveBaseHandler()?.onShowHud(show, true)
  broadcastEvent("ShowHud", { show })
}

needShowHud.subscribe(onShowHud)

eventbus_subscribe("on_show_hud", function on_show_hud(payload) {
  let {show = true} = payload
  isHudVisible.set(show)
})

eventbus_subscribe("on_show_menu_ui", function on_show_hud(payload) {
  let { show = true } = payload
  isMenuVisible.set(show)
})

return {
  needShowHud
}
