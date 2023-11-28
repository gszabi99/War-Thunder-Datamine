//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { show_obj } = require("%sqDagui/daguiUtil.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { updateExpireAlarmIcon } = require("%scripts/items/itemVisual.nut")
let { getPromoConfig, getPromoCollapsedText, getPromoCollapsedIcon, getPromoVisibilityById,
  togglePromoItem, PERFORM_PROMO_ACTION_NAME, performPromoAction, getPromoActionParamsKey
} = require("%scripts/promo/promo.nut")

gui_handlers.RecentItemsHandler <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM

  scene = null
  defShow = true
  wasShown = false

  sceneBlkName = "%gui/empty.blk"
  recentItems = null
  numOtherItems = -1

  function initScreen() {
    this.scene.setUserData(this)
    this.updateHandler(true)
    this.updateVisibility()
  }

  function createItemsView(items) {
    let view = {
      items = []
    }
    foreach (i, item in items) {
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
  function onTimer(_obj, _dt) {
    foreach (idx, item in this.recentItems)
      updateExpireAlarmIcon(item, this.scene.findObject($"shop_item_cont_{idx}"))
  }
  function updateHandler(checkDefShow = false) {
    this.recentItems = ::g_recent_items.getRecentItems()
    let isVisible = (!checkDefShow || this.defShow) && this.recentItems.len() > 0
      && ::ItemsManager.isEnabled() && isInMenu()
    show_obj(this.scene, isVisible)
    this.wasShown = isVisible
    if (!isVisible)
      return

    this.scene.type = "recentItems"
    this.numOtherItems = ::g_recent_items.getNumOtherItems()

    let promoView = getTblValue(this.scene.id, getPromoConfig(), {})
    let otherItemsText = this.createOtherItemsText(this.numOtherItems)
    let view = {
      id = getPromoActionParamsKey(this.scene.id)
      items = handyman.renderCached("%gui/items/item.tpl", this.createItemsView(this.recentItems))
      otherItemsText = otherItemsText
      needAutoScroll = getStringWidthPx(otherItemsText, "fontNormal", this.guiScene)
        > to_pixels("1@arrowButtonWidth") ? "yes" : "no"
      action = PERFORM_PROMO_ACTION_NAME
      collapsedAction = PERFORM_PROMO_ACTION_NAME
      collapsedText = getPromoCollapsedText(promoView, this.scene.id)
      collapsedIcon = getPromoCollapsedIcon(promoView, this.scene.id)
    }
    let blk = handyman.renderCached("%gui/items/recentItemsHandler.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, blk, blk.len(), this)
    this.scene.findObject("update_timer").setUserData(this)
  }

  function onItemAction(obj) {
    let itemIndex = to_integer_safe(getTblValue("holderId", obj), -1)
    if (itemIndex == -1 || !(itemIndex in this.recentItems))
      return

    let params = {
      // Prevents popup from going off-screen.
      align = "left"
      obj = obj
    }

    this.useItem(this.recentItems[itemIndex], params)
  }

  function useItem(item, params = null) {
    if (!item.hasRecentItemConfirmMessageBox)
      return this._doActivateItem(item, params)

    let msgBoxText = loc("recentItems/useItem", {
      itemName = item.getName()
    })

    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.msgBox("recent_item_confirmation", msgBoxText, [
          ["ok", Callback(@() this._doActivateItem(item, params), this)
          ], ["cancel", function () {}]], "ok")
    })
  }

  function _doActivateItem(item, params) {
    item.doMainAction(function(_r) {}, this, params)
  }

  function onEventInventoryUpdate(_params) {
    //Because doWhenActiveOnce checks visibility end enable status
    //have to call forced update
    if (this.wasShown)
      this.doWhenActiveOnce("updateHandler")
    else
      this.updateHandler()
  }

  function createOtherItemsText(numItems) {
    local text = loc("recentItems/otherItems")
    if (numItems > 0)
      text += loc("ui/parentheses/space", { text = numItems })
    return text
  }

  function performAction(obj) { performPromoAction(this, obj) }
  function performActionCollapsed(obj) {
    let buttonObj = obj.getParent()
    this.performAction(buttonObj.findObject(getPromoActionParamsKey(buttonObj.id)))
  }
  function onToggleItem(obj) { togglePromoItem(obj) }

  function updateVisibility() {
    let isVisible = !handlersManager.findHandlerClassInScene(gui_handlers.EveryDayLoginAward)
      && !handlersManager.findHandlerClassInScene(gui_handlers.trophyRewardWnd)
      && ::g_recent_items.getRecentItems().len()
    show_obj(this.scene, isVisible)
  }

  onEventActiveHandlersChanged = @(_p) this.updateVisibility()
}

let promoButtonId = "recent_items_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  updateFunctionInHandler = function() {
    let id = promoButtonId
    let show = this.isShowAllCheckBoxEnabled() || getPromoVisibilityById(id)
    let handlerWeak = ::g_recent_items.createHandler(this, this.scene.findObject(id), show)
    this.owner.registerSubHandler(handlerWeak)
  }
})
