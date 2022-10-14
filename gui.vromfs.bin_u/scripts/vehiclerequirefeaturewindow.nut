from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")

::gui_handlers.VehicleRequireFeatureWindow <- class extends ::gui_handlers.BaseGuiHandlerWT
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
    let view = {
      headerText = getWndHeaderText()
      windowImage = getWndImage()
      mainText = createMainText()
      entitlements = createEntitlementsView(purchases)
      showOkButton = !getPurchaseAvailable()
      showEntitlementsTable = getPurchaseAvailable()
    }
    let data = ::handyman.renderCached("%gui/vehicleRequireFeatureWindow", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)

    let timerObj = getObj("vehicle_require_feature_timer")
    if (checkObj(timerObj)) timerObj.setUserData(this)

    let tblObj = getObj("items_list")
    if (tblObj?.isValid() ?? false) {
      tblObj.setValue(purchases.len() > 0 ? 0 : -1)
      ::move_mouse_on_child_by_value(tblObj)
    }
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
      text += loc(locPrefix + "warning/buy")
    else // CheckFeatureLockAction.RESEARCH
      text += loc(locPrefix + "warning/research")
    let mainLocParams = {
      specialPackPart = getPurchaseAvailable()
        ? loc(locPrefix + "warning/specialPackPart")
        : ""
    }
    text += " " + loc(locPrefix + "warning/main", mainLocParams)
    if (getPurchaseAvailable())
      text += "\n" + colorize("userlogColoredText", loc(locPrefix + "advise"))
    return text
  }

  function getWndImage()
  {
    local res = "#ui/images/usa_tanks_locked.jpg?P1"
    let clearedCountry = ::g_string.cutPrefix(::getUnitCountry(unit), "country_")
    if (clearedCountry)
      res = "#ui/images/" + clearedCountry + "_" + unit.unitType.tag + "_locked.jpg?P1"
    return res
  }

  function getWndHeaderText()
  {
    if (!unit)
      return ""

    let country = ::getUnitCountry(unit)
    let locTag = ::g_string.toUpper(::g_string.cutPrefix(country, "country_", ""), 1)
                   + unit.unitType.name
    return format("#shop/featureLock/%s/header", locTag)
  }

  function onRowBuy(obj)
  {
    if( ! ::OnlineShopModel.getPurchaseData(obj.entitlementId).openBrowser())
      ::showInfoMsgBox(loc("msgbox/notAvailbleYet"))
  }

  function createEntitlementsView(purchasesList)
  {
    let view = []
    foreach (i, purchase in purchasesList)
    {
      let entitlementItem = getEntitlementConfig(purchase.sourceEntitlement)
      let entitlementPrice = getEntitlementPrice(entitlementItem)
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
      showTaskProgressBox(loc("charServer/checking"))
      afterSlotOp = function()
      {
        if (!::isUnitFeatureLocked(this.unit))
          this.goBack()
      }.bindenv(this)
    }
  }

  function getEntitlementPrice(entitlementItem)
  {
    let priceText = loc("price/" + entitlementItem.name, "")
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
    let realPrice = (100 - getDiscountValue(entitlementItem)) * basePrice / 100
    let roundedPrice = ::floor(100 * realPrice) / 100
    return formatPrice(roundedPrice.tostring())
  }

  function formatPrice(priceText)
  {
    return format(loc("price/common"), priceText)
  }

  function getDiscountText(entitlementItem)
  {
    let value = getDiscountValue(entitlementItem)
    if (value == 0)
      return ""
    return value.tostring() + "%"
  }

  function getDiscountValue(entitlementItem)
  {
    return getTblValue("goldDiscount", entitlementItem, 0)
  }

  function onEventModalWndDestroy(params)
  {
    if (isSceneActiveNoModals())
      ::move_mouse_on_child_by_value(getObj("items_list"))
  }
}
