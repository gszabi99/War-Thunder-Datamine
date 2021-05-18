local { getStringWidthPx } = require("scripts/viewUtils/daguiFonts.nut")

class ::gui_handlers.RecentItemsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  scene = null
  defShow = true
  wasShown = false

  sceneBlkName = "gui/empty.blk"
  recentItems = null
  numOtherItems = -1

  function initScreen()
  {
    scene.setUserData(this)
    updateHandler(true)
    updateVisibility()
  }

  function createItemsView(items)
  {
    local view = {
      items = []
    }
    foreach (i, item in items)
    {
      local mainActionData = item.getMainActionData()
      view.items.append(item.getViewData({
        itemIndex = i.tostring()
        ticketBuyWindow = false
        hasButton = false
        onClick = !!mainActionData ? "onItemAction" : null
        interactive = true
        contentIcon = false
        hasTimer = false
        addItemName = false
      }))
    }
    return view
  }

  function updateHandler(checkDefShow = false)
  {
    recentItems = ::g_recent_items.getRecentItems()
    local isVisible = (!checkDefShow || defShow) && recentItems.len() > 0
      && ::ItemsManager.isEnabled() && ::isInMenu()
    ::show_obj(scene, isVisible)
    wasShown = isVisible
    if (!isVisible)
      return

    scene.type = ::g_promo.PROMO_BUTTON_TYPE.RECENT_ITEMS
    numOtherItems = ::g_recent_items.getNumOtherItems()

    local promoView = ::getTblValue(scene.id, ::g_promo.getConfig(), {})
    local otherItemsText = createOtherItemsText(numOtherItems)
    local view = {
      id = ::g_promo.getActionParamsKey(scene.id)
      items = ::handyman.renderCached("gui/items/item", createItemsView(recentItems))
      otherItemsText = otherItemsText
      needAutoScroll = getStringWidthPx(otherItemsText, "fontNormal", guiScene)
        > ::to_pixels("1@arrowButtonWidth") ? "yes" : "no"
      action = ::g_promo.PERFORM_ACTON_NAME
      collapsedAction = ::g_promo.PERFORM_ACTON_NAME
      collapsedText = ::g_promo.getCollapsedText(promoView, scene.id)
      collapsedIcon = ::g_promo.getCollapsedIcon(promoView, scene.id)
    }
    local blk = ::handyman.renderCached("gui/items/recentItemsHandler", view)
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)
  }

  function onItemAction(obj)
  {
    local itemIndex = ::to_integer_safe(::getTblValue("holderId", obj), -1)
    if (itemIndex == -1 || !(itemIndex in recentItems))
      return

    local params = {
      // Prevents popup from going off-screen.
      align = "left"
      obj = obj
    }

    useItem(recentItems[itemIndex], params)
  }

  function useItem(item, params = null)
  {
    if (!item.hasRecentItemConfirmMessageBox)
      return _doActivateItem(item, params)

    local msgBoxText = ::loc("recentItems/useItem", {
      itemName = item.getName()
    })

    guiScene.performDelayed(this, function()
    {
      if (isValid())
        msgBox("recent_item_confirmation", msgBoxText, [
          ["ok", ::Callback(@() _doActivateItem(item, params), this)
          ], ["cancel", function () {}]], "ok")
    })
  }

  function _doActivateItem(item, params)
  {
    item.doMainAction(function(r) {}, this, params)
  }

  function onEventInventoryUpdate(params)
  {
    //Because doWhenActiveOnce checks visibility end enable status
    //have to call forced update
    if (wasShown)
      doWhenActiveOnce("updateHandler")
    else
      updateHandler()
  }

  function createOtherItemsText(numItems)
  {
    local text = ::loc("recentItems/otherItems")
    if (numItems > 0)
      text += ::loc("ui/parentheses/space", {text = numItems})
    return text
  }

  function performAction(obj) { ::g_promo.performAction(this, obj) }
  function performActionCollapsed(obj)
  {
    local buttonObj = obj.getParent()
    performAction(buttonObj.findObject(::g_promo.getActionParamsKey(buttonObj.id)))
  }
  function onToggleItem(obj) { ::g_promo.toggleItem(obj) }

  function updateVisibility()
  {
    local isVisible = !::handlersManager.findHandlerClassInScene(::gui_handlers.EveryDayLoginAward)
      && !::handlersManager.findHandlerClassInScene(::gui_handlers.trophyRewardWnd)
      && ::g_recent_items.getRecentItems().len()
    ::show_obj(scene, isVisible)
  }

  onEventActiveHandlersChanged = @(p) updateVisibility()
}
