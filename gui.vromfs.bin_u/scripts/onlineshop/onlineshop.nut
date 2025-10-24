from "%scripts/dagui_natives.nut" import is_online_available, get_entitlement_cost_gold, entitlement_expires_in, purchase_entitlement, set_char_cb, has_entitlement
from "%scripts/dagui_library.nut" import *
from "app" import isAppActive
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let time = require("%scripts/time.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { getEntitlementDescription, getPricePerEntitlement, getEntitlementTimeText,
  isBoughtEntitlement, getEntitlementName, getEntitlementPriceFloat,
  getEntitlementAmount, getFirstPurchaseAdditionalAmount,
  getEntitlementPrice } = require("%scripts/onlineShop/entitlements.nut")
let { getShopPriceBlk } = require("%scripts/onlineShop/onlineShopState.nut")
let { move_mouse_on_child, move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { addTask } = require("%scripts/tasker.nut")
let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")
bundlesShopInfo.subscribe(@(_val) broadcastEvent("BundlesUpdated")) 
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { steam_is_overlay_active } = require("steam")
let { is_builtin_browser_active } = require("%scripts/onlineShop/browserWndHelpers.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")
let { getRemainingPremiumTime } = require("%scripts/user/premium.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { getEntitlementDiscount } = require("%scripts/discounts/discountsState.nut")
let { onOnlinePurchase } = require("%scripts/onlineShop/onlinePurchase.nut")
let { isStringInteger } = require("%sqstd/string.nut")

const MIN_DISPLAYED_PERCENT_SAVING = 5

function buildDigitsImagesView(numStr, imgSrcTemplate) {
  let res = []
  local needSpace = false

  for (local i = 0; i < numStr.len(); i++) {
    let ch = numStr.slice(i, i + 1)
    if (!isStringInteger(ch)) {
      if (ch == " " || ch == ",")
        needSpace = true
      continue
    }

    res.append({
      src = format(imgSrcTemplate, ch)
      ratio =  ch == "1" ? 41.0/150 : 76.0/150
      needSpace
    })
    needSpace = false
  }

  return res
}

gui_handlers.OnlineShopHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chapterModal.blk"
  sceneNavBlkName = "%gui/navOnlineShop.blk"

  owner = null
  afterCloseFunc = null

  chapter = null
  skipChapters = ["hidden", "premium", "eagles", "warpoints"]

  goods = null
  chImages = null
  bundles = null
  groupCost = null
  task = ""
  needFullUpdate = false

  
  isIngameCurrency = false

  function initScreen() {
    if (!this.scene)
      return this.goBack()

    ENTITLEMENTS_PRICE.checkUpdate(
      Callback(function() {
        this.reinitScreen()
      }, this)
      Callback(function(_result) { this.reinitScreen() }, this)
      true
    )
  }

  function onEventBundlesUpdated(_p) {
    this.reinitScreen()
  }

  function reinitScreen(params = {}) {
    if (!checkObj(this.scene))
      return this.goBack()

    this.setParams(params)

    let blockObj = this.scene.findObject("chapter_include_block")
    if (checkObj(blockObj))
      blockObj.show(true)

    this.goods = {}
    this.chImages = {}
    this.bundles = {}
    this.groupCost = {}

    local data = ""
    let rowsView = []
    local idx = 0
    let isGold = this.chapter == "eagles"
    local curChapter = ""
    let eblk = getShopPriceBlk()

    local first = true
    let numBlocks = eblk.blockCount()
    for (local i = 0; i < numBlocks; i++) {
      let ib = eblk.getBlock(i)
      let name = ib.getBlockName()
      if (this.chapter == null && isInArray(ib?.chapter, this.skipChapters))
        continue
      if (this.chapter != null && ib?.chapter != this.chapter)
        continue
      if (ib?.hideWhenUnbought && !has_entitlement(name))
        continue

      this.goods[name] <- {
        name = name
      }

      
      for (local j = 0; j < ib.paramCount(); j++) {
        let paramName = ib.getParamName(j)
        if (!(paramName in this.goods[name]))
          this.goods[name][paramName] <- ib.getParamValue(j)
      }

      if (ib?.bundle)
        this.bundles[name] <- ib.bundle % "item"

      foreach (param in ["entitlementGift", "aircraftGift", "showEntAsGift"]) {
        let arr = []
        let list = ib % param
        foreach (l in list)
          if (!isInArray(l, arr))
            arr.append(l)
        this.goods[name][param] <- arr
      }

      if (this.goods[name]?.showEntitlementGift)
        this.goods[name].entitlementGift.extend(this.goods[name].showEntAsGift)
      else
        this.goods[name].entitlementGift = this.goods[name].showEntAsGift
      

      if (!isGold && this.goods[name]?.group && !this.groupCost?[this.goods[name].group])
        this.groupCost[this.goods[name].group] <- getPricePerEntitlement(this.goods[name])

      if (this.isIngameCurrency) {
        rowsView.append(this.getIngameCurrencyItemView(this.goods[name], idx))
      }
      else {
        if (this.goods[name]?.chapter) {
          if (this.goods[name].chapter != curChapter) {
            curChapter = this.goods[name].chapter
            let view = {
              itemTag = "chapter_item_unlocked"
              id = curChapter
              itemText = $"#charServer/chapter/{curChapter}"
            }
            data = "".concat(data, handyman.renderCached("%gui/missions/missionBoxItem.tpl", view))
          }
          if (this.goods[name]?.chapterImage)
            this.chImages[this.goods[name].chapter] <- this.goods[name].chapterImage
        }

        let discount = getEntitlementDiscount(name)
        let view = {
          itemIcon = this.getItemIcon(name)
          id = name
          isSelected = first
          discountText = discount > 0 ? ($"-{discount}%") : null
        }
        data = "".concat(data, handyman.renderCached("%gui/missions/missionBoxItem.tpl", view))
      }
      first = false
      idx++
    }

    
    if (this.isIngameCurrency) {
      this.guiScene.setUpdatesEnabled(false, false)

      this.scene.findObject("wnd_update").setUserData(this)

      let itemsListObj = this.scene.findObject("items_list")
      let currency = this.chapter == "eagles" ? "eagles" : "lions"
      let itemHeaderImg = $"!ui/images/ingame_currency_shop/{currency}/item_header_bg.avif"
      data = handyman.renderCached(("%gui/onlineShop/ingameCurrencyShopItem.tpl"), {
        items = rowsView
        itemHeaderImg
      })
      this.guiScene.replaceContentFromText(itemsListObj, data, data.len(), this)
      this.guiScene.setUpdatesEnabled(true, true)
      this.guiScene.performDelayed(this, @() move_mouse_on_child(itemsListObj, 0))
    }
    else { 
      this.scene.findObject("chapter_update").setUserData(this)
      this.scene.findObject("chapter_name").setValue(loc("mainmenu/btnOnlineShop"))

      let listObj = this.scene.findObject("items_list")
      this.guiScene.replaceContentFromText(this.scene.findObject("items_list"), data, data.len(), this)

      foreach (name, item in this.goods) {
        let obj = listObj.findObject($"txt_{name}")
        if (obj) {
          local text = getEntitlementName(item)
          let priceText = this.getItemPriceText(name)
          if (priceText != "")
            text = format("(%s) %s", priceText, text)
          obj.setValue(text)
        }
        if (name in this.bundles)
          this.updateItemIcon(name)
      }
    }

    move_mouse_on_child_by_value(this.scene.findObject("items_list"))
    this.onItemSelect()
  }

  function afterModalDestroy() {
    topMenuHandler.get()?.updateExpAndBalance.call(topMenuHandler.get())
    this.popCloseFunc()
  }

  function popCloseFunc() {
    if (!this.afterCloseFunc)
      return
    this.afterCloseFunc()
    this.afterCloseFunc = null
  }

  function onDestroy() {
    this.popCloseFunc()
  }

  function getItemPriceText(name) {
    if (name in this.goods)
      return getEntitlementPrice(this.goods[name])
    return ""
  }

  function getItemIcon(name) {
    if ((name in this.goods) && isBoughtEntitlement(this.goods[name]))
      return "#ui/gameuiskin#favorite"
    return null
  }

  function updateProductInfo(product, productId) {
    this.scene.findObject("item_desc_text").setValue(getEntitlementDescription(product, productId))

    local image = ""
    if (product != null)
      image = ("image" in product) ? $"#ui/onlineShop/{product.image}.ddsx" : ""
    else
      image = (productId in this.chImages) ? $"#ui/onlineShop/{this.chImages[productId]}.ddsx" : ""
    this.scene.findObject("item_desc_header_img")["background-image"] = image

    this.priceText = this.getItemPriceText(productId)
    showObjById("btn_buy_online", product != null && !isBoughtEntitlement(product), this.scene)
    this.scene.findObject("btn_buy_online").setValue("".concat(loc("mainmenu/btnBuy"), (this.priceText == "") ? "" : format(" (%s)", this.priceText)))

    local discountText = ""
    let discount = getEntitlementDiscount(product.name)
    if (product != null && discount > 0)
      discountText = $"-{discount}%"
    this.scene.findObject("buy_online-discount").setValue(discountText)
  }

  function onItemSelect() {
    let listObj = this.scene.findObject("items_list")
    let value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return

    let obj = listObj.getChild(value)
    this.task = obj.id
    let product = this.goods?[this.task]
    this.updateProductInfo(product, this.task)
  }

  function onUpdate(_obj, _dt) {
    if (!isAppActive() || steam_is_overlay_active() || is_builtin_browser_active())
      this.needFullUpdate = true
    else if (this.needFullUpdate && is_online_available()) {
      this.needFullUpdate = false
      this.taskId = updateEntitlementsLimited()
      if (this.taskId < 0)
        return

      set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox(loc("charServer/checking"))
      this.afterSlotOp = function() {
        if (!checkObj(this.scene))
          return

        broadcastEvent("EntitlementsUpdatedFromOnlineShop")
        this.reinitScreen()
        this.goForward(null)
      }
    }
  }

  function goForwardIfPurchase(curIdx) {
    let taskId = purchase_entitlement(this.task)
    let taskOptions = {
      showProgressBox = true
    }
    let taskSuccessCallback = Callback(function () {
        this.goForward(this.startFunc)
        move_mouse_on_child(this.scene.findObject("items_list"), curIdx)
      }, this)
    addTask(taskId, taskOptions, taskSuccessCallback)
  }

  function onStart() {  
    let product = this.goods?[this.task]
    if (product == null || isBoughtEntitlement(product))
      return
    if (product?.onlinePurchase ?? false)
      return onOnlinePurchase(product)

    let costGold = "goldCost" in product ? get_entitlement_cost_gold(product.name) : 0
    let price = Cost(0, costGold)
    let msgText = warningIfGold(
      loc("onlineShop/needMoneyQuestion",
        { purchase = getEntitlementName(product), cost = price.getTextAccordingToBalance() }),
      price)
    let curIdx = this.scene.findObject("items_list").getValue()
    let onCallbackYes = Callback(function() {
      if (checkBalanceMsgBox(price))
        this.goForwardIfPurchase(curIdx)
    }, this)
    let onCallbackNo = Callback(@() move_mouse_on_child(this.scene.findObject("items_list"), curIdx), this)
    purchaseConfirmation("purchase_ask", msgText, onCallbackYes, onCallbackNo)
  }

  function onApply(_obj) {
    this.onStart()
  }

  function updateItemIcon(name) {
    if (this.isIngameCurrency)
      return

    let obj = this.scene.findObject("items_list").findObject(name)
    let curIcon = this.getItemIcon(name)
    if (curIcon && obj) {
      let medalObj = obj.findObject("medal_icon")
      if (medalObj)
        medalObj["background-image"] = curIcon
    }
  }

  function goForward(_startFunc) {  
    if (checkObj(this.scene)) {
      this.onItemSelect()
      this.updateItemIcon(this.task)
      updateGamercards()
    }
    broadcastEvent("OnlineShopPurchaseSuccessful", { purchData = this.goods?[this.task] ?? {} })
  }

  function onEventModalWndDestroy(params) {
    base.onEventModalWndDestroy(params)
    if (this.isSceneActiveNoModals())
      move_mouse_on_child_by_value(this.getObj("items_list"))
  }

  function onFav() {}
  function onChapterSelect() {}

  function getIngameCurrencyItemView(item, idx) {
    local amount = getEntitlementAmount(item)
    let additionalAmount = getFirstPurchaseAdditionalAmount(item)
    local savingText = ""
    let discount = getEntitlementDiscount(item.name)
    let productInfo = bundlesShopInfo.get()?[item.name]

    if (additionalAmount > 0)
      savingText = loc("ui/parentheses", { text = loc("charServer/entitlement/firstBuy") })
    else if (productInfo?.discount_mul)
      savingText = loc("charServer/entitlement/discount/short", {
        savings = (1.0 - productInfo.discount_mul) * 100
      })
    else if (item?.group && item.group in this.groupCost) {
      let itemPrice = getEntitlementPriceFloat(item)
      let defItemPrice = this.groupCost[item.group]
      if (itemPrice > 0 && defItemPrice > 0) {
        let calcAmount = amount + additionalAmount
        local saving = (1 - ((itemPrice * (1 - discount * 0.01)) / (calcAmount * defItemPrice))) * 100
        saving = saving.tointeger()
        if (saving >= MIN_DISPLAYED_PERCENT_SAVING)
          savingText = loc("charServer/entitlement/discount/short", { savings = saving })
      }
    }

    amount = amount.tointeger()

    let isGold = this.chapter == "eagles"
    let originAmount = isGold ? Cost(0, amount) : Cost(amount, 0)
    local addString = ""
    if (additionalAmount > 0) {
      let addAmount = isGold ? Cost(0, additionalAmount) : Cost(additionalAmount, 0)
      addString = loc("ui/parentheses/space", { text = $"+{addAmount}" })
    }

    let amountFormattedStr = originAmount.toStringWithParams({
      isColored = false
      needCheckBalance = false
      needIcon = false
    })

    let currency = isGold ? "eagles" : "lions"
    let amountText = "".concat(amountFormattedStr, " ", loc($"currency/{currency}/plural",
      { num = amount }), addString)
    let imgSrcTemplate = this.chapter == "eagles"
      ? "!ui/images/premium/digit_%s.avif"
      : "!ui/images/ingame_currency_shop/lions/silver_digit_%s.avif"

    return {
      id = item.name
      itemIcon = $"!ui/images/ingame_currency_shop/{currency}/item_icon_{idx}.avif"
      externalLink = isGold
      amount = amountText
      savingText = savingText
      cost = this.getItemPriceText(item.name)
      digits = buildDigitsImagesView(amountFormattedStr, imgSrcTemplate)
    }
  }
}

gui_handlers.IngameCurrencyShopHandler <- class (gui_handlers.OnlineShopHandler) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/onlineShop/ingameCurrencyShop.blk"
  sceneNavBlkName = null
  isIngameCurrency = true

  function updateProductInfo(product, productId) {
    let currency = this.chapter == "eagles" ? "eagles" : "lions"
    this.scene.findObject("header_banner")["background-image"]
      = $"!ui/images/ingame_currency_shop/{currency}/header_banner.avif"
    local descText = getEntitlementDescription(product, productId)
    let renewText = getEntitlementTimeText(product)
    if (renewText != "") {
      let realname = ("alias" in product) ? product.alias : productId
      let expire = realname == "PremiumAccount" ? getRemainingPremiumTime()
        : entitlement_expires_in(realname)

      if (expire > 0)
        descText = "".concat(descText,
          colorize("chapterUnlockedColor",
            $"{loc("subscription/activeTime")}{loc("ui/colon")}{time.getExpireText(expire)}"))
    }

    this.scene.findObject("currency_caption").setValue(descText)
  }

  function reinitScreen(params = {}) {
    base.reinitScreen(params)
    foreach (productId, product in this.goods) {
      this.updateProductInfo(product, productId) 
      break 
    }
  }

  function onCurrencyBuy(obj) {
    let { owner } = obj
    let listObj = this.scene.findObject("items_list")
    for (local idx = 0; idx < listObj.childrenCount(); idx++)
      if (listObj.getChild(idx).id == owner) {
        listObj.setValue(idx)
        this.onItemSelect()

        this.onStart()
        break
      }
  }
}
