local { getEntitlementConfig, getEntitlementName } = require("scripts/onlineShop/entitlements.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

class ::gui_handlers.VehicleRequireFeatureWindow extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  featureLockAction = CheckFeatureLockAction.BUY
  purchaseAvailable = true
  needFullUpdate = false
  unit = null
  purchases = []

  function initScreen()
  {
    purchases = ::OnlineShopModel.getAllFeaturePurchases(unit.reqFeature)
    local view = {
      headerText = getWndHeaderText()
      windowImage = getWndImage()
      mainText = createMainText()
      entitlements = createEntitlementsView(purchases)
      showOkButton = !getPurchaseAvailable()
      showEntitlementsTable = getPurchaseAvailable()
    }
    local data = ::handyman.renderCached("gui/vehicleRequireFeatureWindow", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)

    local timerObj = getObj("vehicle_require_feature_timer")
    if (::checkObj(timerObj)) timerObj.setUserData(this)

    local tblObj = getObj("items_list")
    tblObj.setValue(purchases.len() > 0 ? 0 : -1)
    ::move_mouse_on_child_by_value(tblObj)
  }

  function getPurchaseAvailable()
  {
    return purchaseAvailable && (purchases.len() != 0)
  }

  function createMainText()
  {
    local locPrefix = "shop/featureLock/"
    if (unit)
      if (unit.unitType == unitTypes.TANK)
        locPrefix += "USATanks/" //here is usual tanks texts
      else
        locPrefix += unit.unitType.name + "/"

    local text = ""
    if (featureLockAction == CheckFeatureLockAction.BUY)
      text += ::loc(locPrefix + "warning/buy")
    else // CheckFeatureLockAction.RESEARCH
      text += ::loc(locPrefix + "warning/research")
    local mainLocParams = {
      specialPackPart = getPurchaseAvailable()
        ? ::loc(locPrefix + "warning/specialPackPart")
        : ""
    }
    text += " " + ::loc(locPrefix + "warning/main", mainLocParams)
    if (getPurchaseAvailable())
      text += "\n" + ::colorize("userlogColoredText", ::loc(locPrefix + "advise"))
    return text
  }

  function getWndImage()
  {
    local res = "#ui/images/usa_tanks_locked.jpg?P1"
    local clearedCountry = ::g_string.cutPrefix(::getUnitCountry(unit), "country_")
    if (clearedCountry)
      res = "#ui/images/" + clearedCountry + "_" + unit.unitType.tag + "_locked.jpg?P1"
    return res
  }

  function getWndHeaderText()
  {
    if (!unit)
      return ""

    local country = ::getUnitCountry(unit)
    local locTag = ::g_string.toUpper(::g_string.cutPrefix(country, "country_", ""), 1)
                   + unit.unitType.name
    return format("#shop/featureLock/%s/header", locTag)
  }

  function onRowBuy(obj)
  {
    if( ! ::OnlineShopModel.getPurchaseData(obj.entitlementId).openBrowser())
      ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))
  }

  function createEntitlementsView(purchasesList)
  {
    local view = []
    foreach (i, purchase in purchasesList)
    {
      local entitlementItem = getEntitlementConfig(purchase.sourceEntitlement)
      local entitlementPrice = getEntitlementPrice(entitlementItem)
      view.append({
        rowEven = i % 2 == 1
        externalLink = true
        entitlementName = getEntitlementName(entitlementItem)
        entitlementCost = entitlementPrice
        entitlementCostShow = entitlementPrice != ""
        entitlementId = purchase.sourceEntitlement
        discountShow = getDiscountValue(entitlementItem) != 0 && entitlementPrice != ""
        discountText = getDiscountText(entitlementItem)
      })
    }
    return view
  }

  function onTimerUpdate(obj, dt)
  {
    if (!::is_app_active() || ::steam_is_overlay_active() || ::is_builtin_browser_active())
      needFullUpdate = true
    else if (needFullUpdate && ::is_online_available())
    {
      needFullUpdate = false
      taskId = ::update_entitlements_limited()
      if (taskId < 0)
        return
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox(::loc("charServer/checking"))
      afterSlotOp = function()
      {
        if (!::isUnitFeatureLocked(this.unit))
          this.goBack()
      }.bindenv(this)
    }
  }

  function getEntitlementPrice(entitlementItem)
  {
    local priceText = ::loc("price/" + entitlementItem.name, "")
    // Empty string is valid and means we won't show price at all.
    if (priceText == "")
      return ""
    local basePrice
    try
    {
      basePrice = priceText.tofloat()
    }
    catch (err)
    {
      return formatPrice("0")
    }
    local realPrice = (100 - getDiscountValue(entitlementItem)) * basePrice / 100
    local roundedPrice = ::floor(100 * realPrice) / 100
    return formatPrice(roundedPrice.tostring())
  }

  function formatPrice(priceText)
  {
    return format(::loc("price/common"), priceText)
  }

  function getDiscountText(entitlementItem)
  {
    local value = getDiscountValue(entitlementItem)
    if (value == 0)
      return ""
    return value.tostring() + "%"
  }

  function getDiscountValue(entitlementItem)
  {
    return ::getTblValue("goldDiscount", entitlementItem, 0)
  }

  function onEventModalWndDestroy(params)
  {
    if (isSceneActiveNoModals())
      ::move_mouse_on_child_by_value(getObj("items_list"))
  }
}
