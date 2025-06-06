from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { setAllowedControlsMask } = require("controlsMask")
let { playerUnitName, isUnitAlive } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")

function updateAAComplexMenuMask(isMenuActive) {
  let controllMask = isMenuActive
    ? CtrlsInGui.CTRL_IN_AA_COMPLEX_MENU
      | CtrlsInGui.CTRL_ALLOW_FULL
    : CtrlsInGui.CTRL_ALLOW_FULL
  setAllowedControlsMask(controllMask)
}

let isAAComplexMenuActive = mkWatched(persist, "isAAComplexMenuActive", false)
isAAComplexMenuActive.subscribe(updateAAComplexMenuMask)
updateAAComplexMenuMask(isAAComplexMenuActive.get())

let onAAComplexMenuRequest = @(evt) isAAComplexMenuActive.set(evt.show)
let hideAAComplexMenu = @() isAAComplexMenuActive.set(false)

eventbus_subscribe("on_aa_complex_menu_request", onAAComplexMenuRequest)

isInFlight.subscribe(@(v) !v ? hideAAComplexMenu() : null)
playerUnitName.subscribe(@(_) hideAAComplexMenu())
isUnitAlive.subscribe(@(v) !v ? hideAAComplexMenu() : null)

return { isAAComplexMenuActive }
