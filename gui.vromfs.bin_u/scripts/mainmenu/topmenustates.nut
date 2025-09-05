from "%scripts/dagui_library.nut" import *

let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let topMenuHandler = Watched(null)
let topMenuShopActive = mkWatched(persist, "topMenuShopActive", false)
let unitToShowInShop = Watched(null)
let topMenuBorders = isPlatformSony ? [[0.01, 0.99], [0.09, 0.86]] 
  : [[0.01, 0.99], [0.05, 0.86]]

return {
  topMenuBorders = topMenuBorders
  topMenuHandler = topMenuHandler
  topMenuShopActive = topMenuShopActive
  unitToShowInShop
}