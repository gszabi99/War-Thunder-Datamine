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