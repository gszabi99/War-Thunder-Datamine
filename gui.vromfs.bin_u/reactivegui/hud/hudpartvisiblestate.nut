from "%rGui/globals/ui_library.nut" import *

let extWatched = require("%rGui/globals/extWatched.nut")

let isChatPlaceVisible = extWatched("isChatPlaceVisible", false)
let isVisualWeaponSelectorVisible = extWatched("isVisualWeaponSelectorVisible", false)
let isOrderStatusVisible = extWatched("isOrderStatusVisible", false)

return {
  isChatPlaceVisible
  isOrderStatusVisible
  isVisualWeaponSelectorVisible
}
