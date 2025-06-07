from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { playerUnitName, isUnitAlive } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")

let isAAComplexMenuActive = mkWatched(persist, "isAAComplexMenuActive", false)

let onAAComplexMenuRequest = @(evt) isAAComplexMenuActive.set(evt.show)
let hideAAComplexMenu = @() isAAComplexMenuActive.set(false)

eventbus_subscribe("on_aa_complex_menu_request", onAAComplexMenuRequest)

isInFlight.subscribe(@(v) !v ? hideAAComplexMenu() : null)
playerUnitName.subscribe(@(_) hideAAComplexMenu())
isUnitAlive.subscribe(@(v) !v ? hideAAComplexMenu() : null)

return { isAAComplexMenuActive }
