from "%rGui/globals/ui_library.nut" import *

let extWatched = require("%rGui/globals/extWatched.nut")
let { send } = require("eventbus")

let isChatPlaceVisible = extWatched("isChatPlaceVisible", false)
let isOrderStatusVisible = extWatched("isOrderStatusVisible", false)

send("updateHudPartVisible", {})

return {
  isChatPlaceVisible
  isOrderStatusVisible
}
