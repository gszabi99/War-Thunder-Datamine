from "chard" import getMaxWishListSize, getMaxWishListCommentSize
from "string" import format
from "%scripts/dagui_library.nut" import *

let { getCurrentWishListSize, requestAddToWishlist, isWishlistFull, canAddUnitToWishlist
} = require("%scripts/wishlist/wishlistManager.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCountryFlagForUnitTooltip } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRoleIcon, getFullUnitRoleText, getUnitClassColor } = require("%scripts/unit/unitInfoRoles.nut")

class WishListHandler (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/wishlist/addWish.tpl"
  unit = null
  lastShownHintObj = null

  function getSceneTplView() {
    let fonticon = getUnitRoleIcon(this.unit)
    let typeText = getFullUnitRoleText(this.unit)

    let getEdiffFunc = this?.getCurrentEdiff
    let ediff = getEdiffFunc ? getEdiffFunc.call(this) : getCurrentGameModeEdiff()
    let maxWishListCommentSize = getMaxWishListCommentSize()

    return {
      windowHeader = loc("mainmenu/add_to_wishlist")
      currentCount = getCurrentWishListSize()
      maxCount = getMaxWishListSize()
      unitName = getUnitName(this.unit.name, false)
      unitType = (typeText != "") ? colorize(getUnitClassColor(this.unit),  $"{fonticon} {typeText}") : ""
      unitAgeHeader = $"{loc("shop/age")}{loc("ui/colon")}"
      unitAge = get_roman_numeral(this.unit.rank)
      unitRatingHeader = $"{loc("shop/battle_rating")}{loc("ui/colon")}"
      unitRating = format("%.1f", this.unit.getBattleRating(ediff))
      countryImage = getCountryFlagForUnitTooltip(this.unit.getOperatorCountry())
      unitImage = getUnitTooltipImage(this.unit)
      max_comment_size = $"{maxWishListCommentSize}"
      max_comment_size_req = loc("wishlist/comment_req", { count = maxWishListCommentSize })
    }
  }

  function onFocus(obj) {
    if (!showConsoleButtons.get())
      this.updateHint(obj, true)
  }

  function onHover(obj) {
    if (showConsoleButtons.get())
      this.updateHint(obj, obj.isHovered())
  }

  function updateHint(obj, isShow) {
    let hintObj = obj?.id != null ? this.scene.findObject($"req_{obj.id}") : null
    if (checkObj(this.lastShownHintObj) && (hintObj == null || !this.lastShownHintObj.isEqual(hintObj))) {
      this.lastShownHintObj.show(false)
      this.lastShownHintObj = null
    }
    if (checkObj(hintObj)) {
      hintObj.show(isShow)
      this.lastShownHintObj = hintObj
    }
  }

  function onCancelEdit(obj) {
    if (obj.getValue().len() > 0)
      obj.setValue("")
    else
      this.goBack()
  }

  function onSubmit(_obj) {
    let commentObj = this.scene.findObject("comment")
    requestAddToWishlist(this.unit.name, commentObj.getValue())
    this.goBack()
  }
}

register_gui_handler("WishListHandler", WishListHandler)
let addToWishlist = @(unit) handlersManager.loadHandler(WishListHandler, { unit })

function tryAddToWishlist(unit) {
  if (isWishlistFull())
    return showInfoMsgBox(colorize("activeTextColor", loc("wishlist/wishlist_full")))
  addToWishlist(unit)
}

function updateWishlistButton(parentObj, unit, btnId = "btn_add_to_wishlist") {
  if (unit == null)
    return
  let btnObj = showObjById(btnId, canAddUnitToWishlist(unit), parentObj)
  if (btnObj != null)
    btnObj["status"] = isWishlistFull() ? "red" : ""
}

return {
  addToWishlist
  tryAddToWishlist
  updateWishlistButton
}
