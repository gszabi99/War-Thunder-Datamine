//-file:plus-string
from "%scripts/dagui_library.nut" import *
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
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { addTask } = require("%scripts/tasker.nut")
let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")
bundlesShopInfo.subscribe(@(_val) broadcastEvent("BundlesUpdated")) //cannot subscribe directly to reinitScreen inside init
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")

let payMethodsCfg = [
  //{ id = YU2_PAY_QIWI,        name = "qiwi" }
  //{ id = YU2_PAY_YANDEX,      name = "yandex" }
  { id = YU2_PAY_PAYPAL,      name = "paypal" }
  { id = YU2_PAY_WEBMONEY,    name = "webmoney" }
  { id = YU2_PAY_AMAZON,      name = "amazon" }
  { id = YU2_PAY_GJN,         name = "gjncoins" }
]

const MIN_DISPLAYED_PERCENT_SAVING = 5

gui_handlers.OnlineShopHandler <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chapterModal.blk"
  sceneNavBlkName = "%gui/navOnlineShop.blk"
  useRowVisual = false

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
    let eblk = ::OnlineShopModel.getPriceBlk()

    local first = true
    let numBlocks = eblk.blockCount()
    for (local i = 0; i < numBlocks; i++) {
      let ib = eblk.getBlock(i)
      let name = ib.getBlockName()
      if (this.chapter == null && isInArray(ib?.chapter, this.skipChapters))
        continue
      if (this.chapter != null && ib?.chapter != this.chapter)
        continue
      if (ib?.hideWhenUnbought && !::has_entitlement(name))
        continue

      this.goods[name] <- {
        name = name
      }

      //load data from eBlk
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
      //load done

      if (this.goods[name]?.group && !this.groupCost?[this.goods[name].group])
        this.groupCost[this.goods[name].group] <- getPricePerEntitlement(this.goods[name])

      if (this.useRowVisual) {
        rowsView.append(this.getRowView(this.goods[name], isGold, (idx % 2 == 0) ? "yes" : "no"))
        if (this.goods[name]?.chapterImage)
          this.chImages[this.goods[name].chapter] <- this.goods[name].chapterImage
      }
      else {
        if (this.goods[name]?.chapter) {
          if (this.goods[name].chapter != curChapter) {
            curChapter = this.goods[name].chapter
            let view = {
              itemTag = "chapter_item_unlocked"
              id = curChapter
              itemText = "#charServer/chapter/" + curChapter
            }
            data += handyman.renderCached("%gui/missions/missionBoxItem.tpl", view)
          }
          if (this.goods[name]?.chapterImage)
            this.chImages[this.goods[name].chapter] <- this.goods[name].chapterImage
        }

        let discount = ::g_discount.getEntitlementDiscount(name)
        let view = {
          itemIcon = this.getItemIcon(name)
          id = name
          isSelected = first
          discountText = discount > 0 ? ("-" + discount + "%") : null
        }
        data += handyman.renderCached("%gui/missions/missionBoxItem.tpl", view)
      }
      first = false
      idx++
    }

    // Buy Eagles, Lions, Premium Account.
    if (this.useRowVisual) {
      this.guiScene.setUpdatesEnabled(false, false)

      this.scene.findObject("wnd_update").setUserData(this)
      this.scene.findObject("wnd_title").setValue(loc("charServer/chapter/" + this.chapter))

      let rootObj = this.scene.findObject("wnd_frame")
      rootObj["class"] = "wnd"
      rootObj.width = "@onlineShopWidth + 2@blockInterval"
      rootObj.padByLine = "yes"
      let contentObj = this.scene.findObject("wnd_content")
      contentObj.flow = "vertical"

      data = handyman.renderCached(("%gui/onlineShop/onlineShopWithVisualRow.tpl"), {
        chImages = (this.chapter in this.chImages) ? $"#ui/onlineShop/{this.chImages[this.chapter]}.ddsx" : null
        rows = rowsView
      })
      this.guiScene.replaceContentFromText(contentObj, data, data.len(), this)
      let tblObj = this.scene.findObject("items_list")

      this.guiScene.setUpdatesEnabled(true, true)
      this.guiScene.performDelayed(this, @() ::move_mouse_on_child(tblObj, 0))
    }
    else { // Buy Campaigns & Bonuses.
      this.scene.findObject("chapter_update").setUserData(this)
      this.scene.findObject("chapter_name").setValue(loc("mainmenu/btnOnlineShop"))

      let listObj = this.scene.findObject("items_list")
      this.guiScene.replaceContentFromText(this.scene.findObject("items_list"), data, data.len(), this)

      foreach (name, item in this.goods) {
        let obj = listObj.findObject("txt_" + name)
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

    ::move_mouse_on_child_by_value(this.scene.findObject("items_list"))
    this.onItemSelect()
  }

  function afterModalDestroy() {
    topMenuHandler.value?.updateExpAndBalance.call(topMenuHandler.value)
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
    this.showSceneBtn("btn_buy_online", product != null && !isBoughtEntitlement(product))
    this.scene.findObject("btn_buy_online").setValue(loc("mainmenu/btnBuy") + ((this.priceText == "") ? "" : format(" (%s)", this.priceText)))

    local discountText = ""
    let discount = ::g_discount.getEntitlementDiscount(product.name)
    if (product != null && discount > 0)
      discountText = "-" + discount + "%"
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
        if (!checkObj(this.scene))
          return

        broadcastEvent("EntitlementsUpdatedFromOnlineShop")
        this.reinitScreen()
        this.goForward(null)
      }
    }
  }

  function goForwardIfPurchase() {
    let taskId = ::purchase_entitlement(this.task)
    let taskOptions = {
      showProgressBox = true
    }
    let taskSuccessCallback = Callback(function () {
        this.goForward(this.startFunc)
      }, this)
    addTask(taskId, taskOptions, taskSuccessCallback)
  }

  function onStart() {  //onBuy
    let product = this.goods?[this.task]
    if (product == null || isBoughtEntitlement(product))
      return
    if (product?.onlinePurchase ?? false)
      return this.onOnlinePurchase(this.task)

    let costGold = "goldCost" in product ? ::get_entitlement_cost_gold(product.name) : 0
    let price = Cost(0, costGold)
    let msgText = warningIfGold(
      loc("onlineShop/needMoneyQuestion",
        { purchase = getEntitlementName(product), cost = price.getTextAccordingToBalance() }),
      price)
    let curIdx = this.scene.findObject("items_list").getValue()
    let onCallbackYes = Callback(function() {
      if (::check_balance_msgBox(price))
        this.goForwardIfPurchase()
    }, this)
    let onCallbackNo = Callback(@() ::move_mouse_on_child(this.scene.findObject("items_list"), curIdx), this)
    purchaseConfirmation("purchase_ask", msgText, onCallbackYes, onCallbackNo)
  }

  function onOnlinePurchase(itemId) {
    if (needShowGuestEmailRegistration()) {
      showGuestEmailRegistration()
      return
    }

    let payMethods = ::yuplay2_get_payment_methods()
    if (!payMethods || ::steam_is_running() || !hasFeature("PaymentMethods"))
      return ::OnlineShopModel.doBrowserPurchase(itemId)

    let items = []
    local selItem = null
    foreach (method in payMethodsCfg)
      if (payMethods & method.id) {
        let payMethodId = method.id
        let name = "yuNetwork/payMethod/" + method.name
        items.append({
          name = name
          icon = "!#ui/gameuiskin/payment_" + method.name + ".svg"
          callback = Callback(@() this.onYuplayPurchase(itemId, payMethodId, name), this)
        })
        selItem = selItem || name
      }

    let name = "yuNetwork/payMethod/other"
    items.append({
      name = name
      icon = ""
      callback = Callback(@() ::OnlineShopModel.doBrowserPurchase(itemId), this)
    })
    selItem = selItem || name

    ::gui_modal_payment({ items = items, owner = this, selItem = selItem, cancel_fn = function() {} })
  }

  function onYuplayPurchase(itemId, payMethod, nameLocId) {
    let msgText = loc("onlineShop/needMoneyQuestion/onlinePaymentSystem", {
      purchase = colorize("activeTextColor", getEntitlementName(this.goods[itemId])),
      paymentSystem = colorize("userlogColoredText", loc(nameLocId))
    })
    this.msgBox("yuplay_purchase_ask", msgText,
      [ ["yes", @() this.doYuplayPurchase(itemId, payMethod) ],
        ["no", function() {}]
      ], "yes", { cancel_fn = function() {} })
  }

  function doYuplayPurchase(itemId, payMethod) {
    let guid = bundlesShopInfo.value?[itemId].guid ?? ""
    if (guid == "")
      logerr($"Error: not found guid for {itemId}")

    let response = (guid == "") ? -1 : ::yuplay2_buy_entitlement(guid, payMethod)
    if (response != YU2_OK) {
      let errorText = ::get_yu2_error_text(response)
      this.msgBox("errorMessageBox", errorText, [["ok", function() {}]], "ok")
      log($"yuplay2_buy_entitlement have returned {response} with task = {itemId}, guid = {guid}, payMethod = {payMethod}")
      return
    }

    ::update_entitlements()

    this.msgBox("purchase_done",
      format(loc("userlog/buy_entitlement"), getEntitlementName(this.goods[itemId])),
      [["ok", @() null]], "ok", { cancel_fn = @() null })
  }

  function onApply(_obj) {
    this.onStart()
  }

  function onRowBuy(obj) {
    if (!obj)
      return

    let pObj = obj.getParent()
    if (!pObj || !(pObj?.id in this.goods))
      return
    let id = pObj.id

    let listObj = this.scene.findObject("items_list")
    if (!listObj)
      return
    for (local idx = 0; idx < listObj.childrenCount(); idx++)
      if (listObj.getChild(idx).id == id) {
        listObj.setValue(idx)
        this.onItemSelect()

        this.onStart()
        break
      }
  }

  function updateItemIcon(name) {
    if (this.useRowVisual)
      return

    let obj = this.scene.findObject("items_list").findObject(name)
    let curIcon = this.getItemIcon(name)
    if (curIcon && obj) {
      let medalObj = obj.findObject("medal_icon")
      if (medalObj)
        medalObj["background-image"] = curIcon
    }
  }

  function goForward(_startFunc) {  //no forward from this wnd, only purchase finished.
    if (checkObj(this.scene)) {
      this.onItemSelect()
      this.updateItemIcon(this.task)
      ::update_gamercards()
    }
    broadcastEvent("OnlineShopPurchaseSuccessful", { purchData = this.goods?[this.task] ?? {} })
  }

  function onEventModalWndDestroy(params) {
    base.onEventModalWndDestroy(params)
    if (this.isSceneActiveNoModals())
      ::move_mouse_on_child_by_value(this.getObj("items_list"))
  }

  function onFav() {}
  function onChapterSelect() {}

  function getRowView(item, isGold, even) {
    local amount = getEntitlementAmount(item)
    let additionalAmount = getFirstPurchaseAdditionalAmount(item)
    local amountText = ""
    local savingText = ""
    let discount = ::g_discount.getEntitlementDiscount(item.name)
    let productInfo = bundlesShopInfo.value?[item.name]

    if (additionalAmount > 0)
      savingText = loc("ui/parentheses", { text = loc("charServer/entitlement/firstBuy") })
    else if (productInfo?.discount_mul)
      savingText = format(loc("charServer/entitlement/discount"), (1.0 - productInfo.discount_mul) * 100)
    else if (item?.group && item.group in this.groupCost) {
      let itemPrice = getEntitlementPriceFloat(item)
      let defItemPrice = this.groupCost[item.group]
      if (itemPrice > 0 && defItemPrice && (!isGold || !::steam_is_running())) {
        let calcAmount = amount + additionalAmount
        local saving = (1 - ((itemPrice * (1 - discount * 0.01)) / (calcAmount * defItemPrice))) * 100
        saving = saving.tointeger()
        if (saving >= MIN_DISPLAYED_PERCENT_SAVING)
          savingText = format(loc("charServer/entitlement/discount"), saving)
      }
    }

    let isTimeAmount = item?.httl || item?.ttl
    if (isTimeAmount)
      amount *= 24

    if (isTimeAmount)
      amountText = time.hoursToString(amount, false, false, true)
    else {
      amount = amount.tointeger()

      let originAmount = isGold ? Cost(0, amount) : Cost(amount, 0)
      local addString = ""
      if (additionalAmount > 0) {
        let addAmount = isGold ? Cost(0, additionalAmount) : Cost(additionalAmount, 0)
        addString = loc("ui/parentheses/space", { text = "+" + addAmount.tostring() })
      }

      amountText = originAmount.tostring() + addString
    }

    return {
      externalLink = isGold
      rowName = item.name
      rowEven = even
      amount = amountText
      savingText = savingText
      cost = this.getItemPriceText(item.name)
      discount = discount > 0 ? $"-{discount}%" : null
    }
  }
}

gui_handlers.OnlineShopRowHandler <- class extends gui_handlers.OnlineShopHandler {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"
  sceneNavBlkName = null
  useRowVisual = true

  function updateProductInfo(product, productId) {
    local descText = getEntitlementDescription(product, productId)
    let renewText = getEntitlementTimeText(product)
    if (renewText != "") {
      let realname = ("alias" in product) ? product.alias : productId
      let expire = ::entitlement_expires_in(realname == "PremiumAccount"
        ? ::shop_get_premium_account_ent_name()
        : realname)
      if (expire > 0)
        descText = "".concat(descText,
          colorize("chapterUnlockedColor",
            $"{loc("subscription/activeTime")}{loc("ui/colon")}{time.getExpireText(expire)}"))
    }
    this.scene.findObject("item_desc_text").setValue(descText)
  }

  function reinitScreen(params = {}) {
    base.reinitScreen(params)
    foreach (productId, product in this.goods) {
      this.updateProductInfo(product, productId) //for rows visual the same description for all items
      break //warning disable: -unconditional-terminated-loop
    }
  }
}
