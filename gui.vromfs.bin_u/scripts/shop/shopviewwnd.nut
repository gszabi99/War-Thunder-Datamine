local { addPromoAction } = require("scripts/promo/promoActions.nut")

class ::gui_handlers.ShopViewWnd extends ::gui_handlers.ShopMenuHandler
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/shop/shopCheckResearch"
  sceneNavBlkName = "gui/shop/shopNav.blk"

  needHighlight = false

  static function open(params)
  {
    ::handlersManager.loadHandler(::gui_handlers.ShopViewWnd, params)
  }

  function getSceneTplView() { return {hasMaxWindowSize = ::is_small_screen} }

  function initScreen()
  {
    base.initScreen()

    if(!::is_small_screen)
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

local function openShopViewWndFromPromo(params) {
  local unitName = params?[0] ?? ""
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return

  local country = unit.shopCountry
  local showUnitInShop = @() ::gui_handlers.ShopViewWnd.open({
    curAirName = unitName
    forceUnitType = unit?.unitType
    needHighlight = unitName != ""
  })

  local acceptCallback = ::Callback( function() {
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
