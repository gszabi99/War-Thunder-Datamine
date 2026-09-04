from "%scripts/dagui_library.nut" import *


let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { ShopMenuHandler } = require("%scripts/shop/shop.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value } = require("%scripts/sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")

let ShopViewWnd = class (ShopMenuHandler) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopCheckResearch.tpl"
  sceneNavBlkName = "%gui/shop/shopNav.blk"

  needHighlight = false

  static function open(params) {
    handlersManager.loadHandler(get_gui_handler("ShopViewWnd"), params)
  }

  function getSceneTplView() { return { hasMaxWindowSize = isSmallScreen } }

  function initScreen() {
    base.initScreen()

    if (!isSmallScreen)
      this.createSlotbar(
        {
          showNewSlot = true,
          showEmptySlot = true,
          showTopPanel = false
        },
        "slotbar_place")
  }

  function fillAircraftsList(curName = "") {
    base.fillAircraftsList(this.needHighlight ? this.curAirName : curName)

    if (!this.needHighlight)
      return

    this.needHighlight = false

    if (showConsoleButtons.get())
      move_mouse_on_child_by_value(this.scene.findObject("shop_items_list"))
    else
      this.highlightUnitsInTree([this.curAirName])
  }

  function goBack() {
    BaseGuiHandlerWT.goBack.call(this)
  }
}
register_gui_handler("ShopViewWnd", ShopViewWnd)

function openShopViewWndFromPromo(params) {
  let unitName = params?[0] ?? ""
  let unit = getAircraftByName(unitName)
  if (!unit)
    return

  let country = unit.shopCountry
  let showUnitInShop = @() ShopViewWnd.open({
    curAirName = unitName
    forceUnitType = unit?.unitType
    needHighlight = unitName != ""
  })

  let acceptCallback = Callback(function() {
    switchProfileCountry(country)
    showUnitInShop() }, this)
  if (country != profileCountrySq.get())
    checkQueueAndStart(
      acceptCallback,
      null,
      "isCanModifyCrew")
  else
    showUnitInShop()
}

addPromoAction("show_unit", @(_handler, params, _obj) openShopViewWndFromPromo(params))

return { ShopViewWnd }
