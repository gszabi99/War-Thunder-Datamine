from "%sqstd/platform.nut" import isSony
from "%scripts/dagui_library.nut" import *

let topMenuHandler = mkWatchedClearedOnReload(null)
let topMenuShopActive = mkHardPersistWatched("mainmenu.topMenuStates")("topMenuShopActive", false)
let unitToShowInShop = Watched(null)
let topMenuBorders = isSony ? [[0.01, 0.99], [0.09, 0.86]] 
  : [[0.01, 0.99], [0.05, 0.86]]

return {
  topMenuBorders = topMenuBorders
  topMenuHandler = topMenuHandler
  topMenuShopActive = topMenuShopActive
  unitToShowInShop
}