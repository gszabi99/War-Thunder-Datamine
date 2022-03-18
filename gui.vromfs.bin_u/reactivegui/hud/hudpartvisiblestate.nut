let extWatched = require("reactiveGui/globals/extWatched.nut")

let isChatPlaceVisible = extWatched("isChatPlaceVisible", @() ::cross_call.isChatPlaceVisible())

let isOrderStatusVisible = extWatched("isOrderStatusVisible", @() ::cross_call.isOrderStatusVisible())

return {
  isChatPlaceVisible
  isOrderStatusVisible
}
