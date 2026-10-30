import "DataBlock" as DataBlock
from "%scripts/tasker.nut" import charRequestJson
from "%scripts/wishlist/wishlistHandler.nut" import openWishlist
from "%scripts/dagui_library.nut" import *

function onTryOpenFriendWishlistSuccess(data) {
  let { isEnabledForFriends = true, units = null, userId = "" } = data
  if(!isEnabledForFriends) {
    showInfoMsgBox(colorize("activeTextColor", loc("wishlist/enabledForFriends")))
    return
  }

  openWishlist({ friendUid = userId, friendUnits = units })
}

function tryOpenFriendWishlist(uid) {
  let requestBlk = DataBlock()
  requestBlk.setStr("userid", uid)
  charRequestJson("ano_get_wishlist_json", requestBlk, { showErrorMessageBox = true }, onTryOpenFriendWishlistSuccess)
}

return freeze({
  tryOpenFriendWishlist
})
