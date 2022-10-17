let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")

::gui_handlers.ShopViewWnd <- class extends ::gui_handlers.ShopMenuHandler
{
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopCheckResearch"
  sceneNavBlkName = "%gui/shop/shopNav.blk"

  needHighlight = false

  static function open(params)
  {
    ::handlersManager.loadHandler(::gui_handlers.ShopViewWnd, params)
  }

  function getSceneTplView() { return {hasMaxWindowSize = isSmallScreen} }

  function initScreen()
  {
    base.initScreen()

    if(!isSmallScreen)
      createSlotbar(
        {
          showNewSlot = true,
          showEmptySlot = true,
          showTopPanel = false
        },
        "slotbar_place")
  }

  function fillAircraftsList(curName = "")
  {
    base.fillAircraftsList(needHighlight ? curAirName : curName)

    if (!needHighlight)
      return

    needHighlight = false

    if (::show_console_buttons)
      ::move_mouse_on_child_by_value(scene.findObject("shop_items_list"))
    else
      highlightUnitsInTree([curAirName])
  }

  function onCloseShop()
  {
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

  let acceptCallback = ::Callback( function() {
    ::switch_profile_country(country)
    showUnitInShop() }, this)
  if (country != ::get_profile_country_sq())
    ::queues.checkAndStart(
      acceptCallback,
      null,
      "isCanModifyCrew")
  else
    showUnitInShop()
}

addPromoAction("show_unit", @(handler, params, obj) openShopViewWndFromPromo(params))
