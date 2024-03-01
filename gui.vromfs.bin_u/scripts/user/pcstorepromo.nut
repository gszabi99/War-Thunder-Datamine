from "%scripts/dagui_library.nut" import *

function showPcStorePromo() {
  ::showUnlockWnd({
    name = loc("pc_store_promo/title")
    desc = loc("pc_store_promo/desc")
    descAlign = "left"
    popupImage = "#ui/images/pc_store_promo"
    ratioHeight = 0.56
  })
}

return {
  showPcStorePromo
}