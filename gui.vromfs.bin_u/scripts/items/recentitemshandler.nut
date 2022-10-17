from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { updateExpireAlarmIcon } = require("%scripts/items/itemVisual.nut")

::gui_handlers.RecentItemsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  scene = null
  defShow = true
  wasShown = false

  sceneBlkName = "%gui/empty.blk"
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
    let view = {
      items = []
    }
    foreach (i, item in items)
    {
      let mainActionData = item.getMainActionData()
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
  function onTimer(obj, dt)
  {
    foreach (idx, item in recentItems)
      updateExpireAlarmIcon(item, scene.findObject($"shop_item_cont_{idx}"))
  }
  function updateHandler(checkDefShow = false)
  {
    recentItems = ::g_recent_items.getRecentItems()
    let isVisible = (!checkDefShow || defShow) && recentItems.len() > 0
      && ::ItemsManager.isEnabled() && ::isInMenu()
    ::show_obj(scene, isVisible)
    wasShown = isVisible
    if (!isVisible)
      return

    scene.type = "recentItems"
    numOtherItems = ::g_recent_items.getNumOtherItems()

    let promoView = getTblValue(scene.id, ::g_promo.getConfig(), {})
    let otherItemsText = createOtherItemsText(numOtherItems)
    let view = {
      id = ::g_promo.getActionParamsKey(scene.id)
      items = ::handyman.renderCached("%gui/items/item", createItemsView(recentItems))
      otherItemsText = otherItemsText
      needAutoScroll = getStringWidthPx(otherItemsText, "fontNormal", guiScene)
        > to_pixels("1@arrowButtonWidth") ? "yes" : "no"
      action = ::g_promo.PERFORM_ACTON_NAME
      collapsedAction = ::g_promo.PERFORM_ACTON_NAME
      collapsedText = ::g_promo.getCollapsedText(promoView, scene.id)
      collapsedIcon = ::g_promo.getCollapsedIcon(promoView, scene.id)
    }
    let blk = ::handyman.renderCached("%gui/items/recentItemsHandler", view)
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)
    scene.findObject("update_timer").setUserData(this)
  }

  function onItemAction(obj)
  {
    let itemIndex = ::to_integer_safe(getTblValue("holderId", obj), -1)
    if (itemIndex == -1 || !(itemIndex in recentItems))
      return

    let params = {
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

    let msgBoxText = loc("recentItems/useItem", {
      itemName = item.getName()
    })

    guiScene.performDelayed(this, function()
    {
      if (isValid())
        this.msgBox("recent_item_confirmation", msgBoxText, [
          ["ok", Callback(@() _doActivateItem(item, params), this)
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
    local text = loc("recentItems/otherItems")
    if (numItems > 0)
      text += loc("ui/parentheses/space", {text = numItems})
    return text
  }

  function performAction(obj) { ::g_promo.performAction(this, obj) }
  function performActionCollapsed(obj)
  {
    let buttonObj = obj.getParent()
    performAction(buttonObj.findObject(::g_promo.getActionParamsKey(buttonObj.id)))
  }
  function onToggleItem(obj) { ::g_promo.toggleItem(obj) }

  function updateVisibility()
  {
    let isVisible = !::handlersManager.findHandlerClassInScene(::gui_handlers.EveryDayLoginAward)
      && !::handlersManager.findHandlerClassInScene(::gui_handlers.trophyRewardWnd)
      && ::g_recent_items.getRecentItems().len()
    ::show_obj(scene, isVisible)
  }

  onEventActiveHandlersChanged = @(p) updateVisibility()
}

let promoButtonId = "recent_items_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  updateFunctionInHandler = function() {
    let id = promoButtonId
    let show = isShowAllCheckBoxEnabled() || ::g_promo.getVisibilityById(id)
    let handlerWeak = ::g_recent_items.createHandler(this, scene.findObject(id), show)
    owner.registerSubHandler(handlerWeak)
  }
})
