local extWatched = require("reactiveGui/globals/extWatched.nut")

local isChatPlaceVisible = extWatched("isChatPlaceVisible", @() ::cross_call.isChatPlaceVisible())

local isOrderStatusVisible = extWatched("isOrderStatusVisible", @() ::cross_call.isOrderStatusVisible())

return {
  isChatPlaceVisible
  isOrderStatusVisible
}
