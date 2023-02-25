//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")

::gui_handlers.ShopViewWnd <- class extends ::gui_handlers.ShopMenuHandler {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopCheckResearch.tpl"
  sceneNavBlkName = "%gui/shop/shopNav.blk"

  needHighlight = false

  static function open(params) {
    ::handlersManager.loadHandler(::gui_handlers.ShopViewWnd, params)
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

    if (::show_console_buttons)
      ::move_mouse_on_child_by_value(this.scene.findObject("shop_items_list"))
    else
      this.highlightUnitsInTree([this.curAirName])
  }

  function onCloseShop() {
    ::gui_handlers.BaseGuiHandlerWT.goBack.call(this)
  }
}

let function openShopViewWndFromPromo(params) {
  let unitName = params?[0] ?? ""
  let unit = ::getAircraftByName(unitName)
  if (!unit)
    return

  let country = unit.shopCountry
  let showUnitInShop = @() ::gui_handlers.ShopViewWnd.open({
    curAirName = unitName
    forceUnitType = unit?.unitType
    needHighlight = unitName != ""
  })

  let acceptCallback = Callback(function() {
    switchProfileCountry(country)
    showUnitInShop() }, this)
  if (country != profileCountrySq.value)
    ::queues.checkAndStart(
      acceptCallback,
      null,
      "isCanModifyCrew")
  else
    showUnitInShop()
}

addPromoAction("show_unit", @(_handler, params, _obj) openShopViewWndFromPromo(params))
