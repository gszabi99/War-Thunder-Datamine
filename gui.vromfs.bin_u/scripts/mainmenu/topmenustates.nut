let { isPlatformSony } = require("scripts/clientState/platform.nut")

let topMenuHandler = ::Watched(null)
let topMenuShopActive = persist("topMenuShopActive", @() ::Watched(false))

let topMenuBorders = isPlatformSony ? [[0.01, 0.99], [0.09, 0.86]] //[x1,x2], [y1, y2] *rootSize - border for chat and contacts
  : [[0.01, 0.99], [0.05, 0.86]]

return {
  topMenuBorders = topMenuBorders
  topMenuHandler = topMenuHandler
  topMenuShopActive = topMenuShopActive
}