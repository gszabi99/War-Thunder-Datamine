from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { queues } = require("%scripts/queue/queueManager.nut")

gui_handlers.ShopViewWnd <- class (gui_handlers.ShopMenuHandler) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopCheckResearch.tpl"
  sceneNavBlkName = "%gui/shop/shopNav.blk"

  needHighlight = false

  static function open(params) {
    handlersManager.loadHandler(gui_handlers.ShopViewWnd, params)
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

    if (showConsoleButtons.value)
      move_mouse_on_child_by_value(this.scene.findObject("shop_items_list"))
    else
      this.highlightUnitsInTree([this.curAirName])
  }

  function goBack() {
    gui_handlers.BaseGuiHandlerWT.goBack.call(this)
  }
}

function openShopViewWndFromPromo(params) {
  let unitName = params?[0] ?? ""
  let unit = getAircraftByName(unitName)
  if (!unit)
    return

  let country = unit.shopCountry
  let showUnitInShop = @() gui_handlers.ShopViewWnd.open({
    curAirName = unitName
    forceUnitType = unit?.unitType
    needHighlight = unitName != ""
  })

  let acceptCallback = Callback(function() {
    switchProfileCountry(country)
    showUnitInShop() }, this)
  if (country != profileCountrySq.value)
    queues.checkAndStart(
      acceptCallback,
      null,
      "isCanModifyCrew")
  else
    showUnitInShop()
}

addPromoAction("show_unit", @(_handler, params, _obj) openShopViewWndFromPromo(params))
