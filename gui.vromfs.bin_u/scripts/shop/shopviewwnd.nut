from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/shop/shop.nut" import ShopMenuHandler
from "%scripts/promo/promoActions.nut" import addPromoAction
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child_by_value
from "%appGlobals/clientState/touchScreen.nut" import isSmallScreen
from "%scripts/user/playerCountry.nut" import switchProfileCountry, profileCountrySq
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/queue/queueManager.nut" import checkQueueAndStart
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

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

return freeze({ ShopViewWnd })
