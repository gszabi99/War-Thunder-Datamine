//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { floor } = require("math")

let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { cutPrefix, toUpper } = require("%sqstd/string.nut")
let { getUnitCountry } = require("%scripts/unit/unitInfo.nut")

gui_handlers.VehicleRequireFeatureWindow <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  featureLockAction = CheckFeatureLockAction.BUY
  purchaseAvailable = true
  needFullUpdate = false
  unit = null
  purchases = []

  function initScreen() {
    this.purchases = ::OnlineShopModel.getAllFeaturePurchases(this.unit.reqFeature)
    let view = {
      headerText = this.getWndHeaderText()
      windowImage = this.getWndImage()
      mainText = this.createMainText()
      entitlements = this.createEntitlementsView(this.purchases)
      showOkButton = !this.getPurchaseAvailable()
      showEntitlementsTable = this.getPurchaseAvailable()
    }
    let data = handyman.renderCached("%gui/vehicleRequireFeatureWindow.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)

    let timerObj = this.getObj("vehicle_require_feature_timer")
    if (checkObj(timerObj))
      timerObj.setUserData(this)

    let tblObj = this.getObj("items_list")
    if (tblObj?.isValid() ?? false) {
      tblObj.setValue(this.purchases.len() > 0 ? 0 : -1)
      ::move_mouse_on_child_by_value(tblObj)
    }
  }

  function getPurchaseAvailable() {
    return this.purchaseAvailable && (this.purchases.len() != 0)
  }

  function createMainText() {
    local locPrefix = "shop/featureLock/"
    if (this.unit)
      if (this.unit.unitType == unitTypes.TANK)
        locPrefix += "USATanks/" //here is usual tanks texts
      else
        locPrefix += this.unit.unitType.name + "/"

    local text = ""
    if (this.featureLockAction == CheckFeatureLockAction.BUY)
      text += loc(locPrefix + "warning/buy")
    else // CheckFeatureLockAction.RESEARCH
      text += loc(locPrefix + "warning/research")
    let mainLocParams = {
      specialPackPart = this.getPurchaseAvailable()
        ? loc(locPrefix + "warning/specialPackPart")
        : ""
    }
    text += " " + loc(locPrefix + "warning/main", mainLocParams)
    if (this.getPurchaseAvailable())
      text += "\n" + colorize("userlogColoredText", loc(locPrefix + "advise"))
    return text
  }

  function getWndImage() {
    local res = "#ui/images/usa_tanks_locked?P1"
    let clearedCountry = cutPrefix(getUnitCountry(this.unit), "country_")
    if (clearedCountry)
      res = "#ui/images/" + clearedCountry + "_" + this.unit.unitType.tag + "_locked?P1"
    return res
  }

  function getWndHeaderText() {
    if (!this.unit)
      return ""

    let country = getUnitCountry(this.unit)
    let locTag = toUpper(cutPrefix(country, "country_", ""), 1)
                   + this.unit.unitType.name
    return format("#shop/featureLock/%s/header", locTag)
  }

  function onRowBuy(obj) {
    if (! ::OnlineShopModel.getPurchaseData(obj.entitlementId).openBrowser())
      showInfoMsgBox(loc("msgbox/notAvailbleYet"))
  }

  function createEntitlementsView(purchasesList) {
    let view = []
    foreach (i, purchase in purchasesList) {
      let entitlementItem = getEntitlementConfig(purchase.sourceEntitlement)
      let entitlementPrice = this.getEntitlementPrice(entitlementItem)
      view.append({
        rowEven = i % 2 == 1
        externalLink = true
        entitlementName = getEntitlementName(entitlementItem)
        entitlementCost = entitlementPrice
        entitlementCostShow = entitlementPrice != ""
        entitlementId = purchase.sourceEntitlement
        discountShow = this.getDiscountValue(entitlementItem) != 0 && entitlementPrice != ""
        discountText = this.getDiscountText(entitlementItem)
      })
    }
    return view
  }

  function onTimerUpdate(_obj, _dt) {
    if (!::is_app_active() || ::steam_is_overlay_active() || ::is_builtin_browser_active())
      this.needFullUpdate = true
    else if (this.needFullUpdate && ::is_online_available()) {
      this.needFullUpdate = false
      this.taskId = ::update_entitlements_limited()
      if (this.taskId < 0)
        return
      ::set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox(loc("charServer/checking"))
      this.afterSlotOp = function() {
        if (!::isUnitFeatureLocked(this.unit))
          this.goBack()
      }.bindenv(this)
    }
  }

  function getEntitlementPrice(entitlementItem) {
    let priceText = loc("price/" + entitlementItem.name, "")
    // Empty string is valid and means we won't show price at all.
    if (priceText == "")
      return ""
    local basePrice
    try {
      basePrice = priceText.tofloat()
    }
    catch (err) {
      return this.formatPrice("0")
    }
    let realPrice = (100 - this.getDiscountValue(entitlementItem)) * basePrice / 100
    let roundedPrice = floor(100 * realPrice) / 100
    return this.formatPrice(roundedPrice.tostring())
  }

  function formatPrice(priceText) {
    return format(loc("price/common"), priceText)
  }

  function getDiscountText(entitlementItem) {
    let value = this.getDiscountValue(entitlementItem)
    if (value == 0)
      return ""
    return value.tostring() + "%"
  }

  function getDiscountValue(entitlementItem) {
    return getTblValue("goldDiscount", entitlementItem, 0)
  }

  function onEventModalWndDestroy(_params) {
    if (this.isSceneActiveNoModals())
      ::move_mouse_on_child_by_value(this.getObj("items_list"))
  }
}
