let { format } = require("string")
let time = require("%scripts/time.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { getEntitlementDescription, getPricePerEntitlement, getEntitlementTimeText,
  isBoughtEntitlement, getEntitlementName, getEntitlementPriceFloat,
  getEntitlementAmount, getFirstPurchaseAdditionalAmount,
  getEntitlementPrice } = require("%scripts/onlineShop/entitlements.nut")

let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")
bundlesShopInfo.subscribe(@(val) ::broadcastEvent("BundlesUpdated")) //cannot subscribe directly to reinitScreen inside init

let payMethodsCfg = [
  /*
  { id = ::YU2_PAY_QIWI,        name = "qiwi" }
  { id = ::YU2_PAY_YANDEX,      name = "yandex" }
  */
  { id = ::YU2_PAY_PAYPAL,      name = "paypal" }
  { id = ::YU2_PAY_WEBMONEY,    name = "webmoney" }
  { id = ::YU2_PAY_AMAZON,      name = "amazon" }
  { id = ::YU2_PAY_GJN,         name = "gjncoins" }
]

const MIN_DISPLAYED_PERCENT_SAVING = 5

::gui_handlers.OnlineShopHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
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

  function initScreen()
  {
    if (!scene)
      return goBack()

    ENTITLEMENTS_PRICE.checkUpdate(
      ::Callback(function()
      {
        reinitScreen()
      }, this)
      ::Callback(function(result) { reinitScreen() }, this)
      true
    )
  }

  function onEventBundlesUpdated(p) {
    reinitScreen()
  }

  function reinitScreen(params = {})
  {
    if (!::checkObj(scene))
      return goBack()

    setParams(params)

    let blockObj = scene.findObject("chapter_include_block")
    if (::checkObj(blockObj))
      blockObj.show(true)

    goods = {}
    chImages = {}
    bundles = {}
    groupCost = {}

    local data = ""
    let rowsView = []
    local idx = 0
    let isGold = chapter == "eagles"
    local curChapter = ""
    let eblk = ::OnlineShopModel.getPriceBlk()

    local first = true
    let numBlocks = eblk.blockCount()
    for (local i = 0; i < numBlocks; i++)
    {
      let ib = eblk.getBlock(i)
      let name = ib.getBlockName()
      if (chapter == null && ::isInArray(ib?.chapter, skipChapters))
        continue
      if (chapter != null && ib?.chapter != chapter)
        continue
      if (ib?.hideWhenUnbought && !::has_entitlement(name))
        continue

      goods[name] <- {
        name = name
      }

      //load data from eBlk
      for (local j = 0; j < ib.paramCount(); j++)
      {
        let paramName = ib.getParamName(j)
        if (!(paramName in goods[name]))
          goods[name][paramName] <- ib.getParamValue(j)
      }

      if (ib?.bundle)
        bundles[name] <- ib.bundle % "item"

      foreach(param in ["entitlementGift", "aircraftGift", "showEntAsGift"])
      {
        let arr = []
        let list = ib % param
        foreach(l in list)
          if (!::isInArray(l, arr))
            arr.append(l)
        goods[name][param] <- arr
      }

      if (goods[name]?.showEntitlementGift)
        goods[name].entitlementGift.extend(goods[name].showEntAsGift)
      else
        goods[name].entitlementGift = goods[name].showEntAsGift
      //load done

      if (goods[name]?.group && !groupCost?[goods[name].group])
        groupCost[goods[name].group] <- getPricePerEntitlement(goods[name])

      if (useRowVisual) {
        rowsView.append(getRowView(goods[name], isGold, (idx%2 == 0) ? "yes" :"no"))
        if (goods[name]?.chapterImage)
          chImages[goods[name].chapter] <- goods[name].chapterImage
      }
      else
      {
        if (goods[name]?.chapter)
        {
          if (goods[name].chapter != curChapter)
          {
            curChapter = goods[name].chapter
            let view = {
              itemTag = "chapter_item_unlocked"
              id = curChapter
              itemText = "#charServer/chapter/" + curChapter
            }
            data += ::handyman.renderCached("%gui/missions/missionBoxItem", view)
          }
          if (goods[name]?.chapterImage)
            chImages[goods[name].chapter] <- goods[name].chapterImage
        }

        let discount = ::g_discount.getEntitlementDiscount(name)
        let view = {
          itemIcon = getItemIcon(name)
          id = name
          isSelected = first
          discountText = discount > 0? ("-" + discount + "%") : null
        }
        data += ::handyman.renderCached("%gui/missions/missionBoxItem", view)
      }
      first = false
      idx++
    }

    // Buy Eagles, Lions, Premium Account.
    if (useRowVisual)
    {
      guiScene.setUpdatesEnabled(false, false)

      scene.findObject("wnd_update").setUserData(this)
      scene.findObject("wnd_title").setValue(::loc("charServer/chapter/" + chapter))

      let rootObj = scene.findObject("wnd_frame")
      rootObj["class"] = "wnd"
      rootObj.width = "@onlineShopWidth + 2@blockInterval"
      rootObj.padByLine = "yes"
      let contentObj = scene.findObject("wnd_content")
      contentObj.flow = "vertical"

      data = ::handyman.renderCached(("%gui/onlineShop/onlineShopWithVisualRow"), {
        chImages = (chapter in chImages) ? $"#ui/onlineShop/{chImages[chapter]}.ddsx" : null
        rows = rowsView
      })
      guiScene.replaceContentFromText(contentObj, data, data.len(), this)
      let tblObj = scene.findObject("items_list")

      guiScene.setUpdatesEnabled(true, true)
      guiScene.performDelayed(this, @() ::move_mouse_on_child(tblObj, 0))
    }
    else
    {// Buy Campaigns & Bonuses.
      scene.findObject("chapter_update").setUserData(this)
      scene.findObject("chapter_name").setValue(::loc("mainmenu/btnOnlineShop"))

      let listObj = scene.findObject("items_list")
      guiScene.replaceContentFromText(scene.findObject("items_list"), data, data.len(), this)

      foreach(name, item in goods)
      {
        let obj = listObj.findObject("txt_" + name)
        if (obj)
        {
          local text = getEntitlementName(item)
          let priceText = getItemPriceText(name)
          if (priceText!="")
            text = format("(%s) %s", priceText, text)
          obj.setValue(text)
        }
        if (name in bundles)
          updateItemIcon(name)
      }
    }

    ::move_mouse_on_child_by_value(scene.findObject("items_list"))
    onItemSelect()
  }

  function afterModalDestroy() {
    topMenuHandler.value?.updateExpAndBalance.call(topMenuHandler.value)
    popCloseFunc()
  }

  function popCloseFunc()
  {
    if (!afterCloseFunc)
      return
    afterCloseFunc()
    afterCloseFunc = null
  }

  function onDestroy()
  {
    popCloseFunc()
  }

  function getItemPriceText(name)
  {
    if (name in goods)
      return getEntitlementPrice(goods[name])
    return ""
  }

  function getItemIcon(name)
  {
    if ((name in goods) && isBoughtEntitlement(goods[name]))
      return "#ui/gameuiskin#favorite.png"
    return null
  }

  function updateProductInfo(product, productId) {
    scene.findObject("item_desc_text").setValue(getEntitlementDescription(product, productId))

    local image = ""
    if (product != null)
      image = ("image" in product)? $"#ui/onlineShop/{product.image}.ddsx" : ""
    else
      image = (productId in chImages)? $"#ui/onlineShop/{chImages[productId]}.ddsx" : ""
    scene.findObject("item_desc_header_img")["background-image"] = image

    priceText = getItemPriceText(productId)
    this.showSceneBtn("btn_buy_online", product != null && !isBoughtEntitlement(product))
    scene.findObject("btn_buy_online").setValue(::loc("mainmenu/btnBuy") + ((priceText=="")? "" : format(" (%s)", priceText)))

    local discountText = ""
    let discount = ::g_discount.getEntitlementDiscount(product.name)
    if (product != null && discount > 0)
      discountText = "-" + discount + "%"
    scene.findObject("buy_online-discount").setValue(discountText)
  }

  function onItemSelect()
  {
    let listObj = scene.findObject("items_list")
    let value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return

    let obj = listObj.getChild(value)
    task = obj.id
    let product = goods?[task]
    updateProductInfo(product, task)
  }

  function onUpdate(obj, dt)
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
        if (!::checkObj(scene))
          return

        ::broadcastEvent("EntitlementsUpdatedFromOnlineShop")
        reinitScreen()
        goForward(null)
      }
    }
  }

  function goForwardIfPurchase()
  {
    let taskId = ::purchase_entitlement(task)
    let taskOptions = {
      showProgressBox = true
    }
    let taskSuccessCallback = ::Callback(function ()
      {
        goForward(startFunc)
      }, this)
    ::g_tasker.addTask(taskId, taskOptions, taskSuccessCallback)
  }

  function onStart()  //onBuy
  {
    let product = goods?[task]
    if (product == null || isBoughtEntitlement(product))
      return
    if (product?.onlinePurchase ?? false)
      return onOnlinePurchase(task)

    let costGold = "goldCost" in product? ::get_entitlement_cost_gold(product.name) : 0
    let price = ::Cost(0, costGold)
    let msgText = ::warningIfGold(
      ::loc("onlineShop/needMoneyQuestion",
        {purchase = getEntitlementName(product), cost = price.getTextAccordingToBalance()}),
      price)
    let curIdx = scene.findObject("items_list").getValue()
    let onCancel = @() ::move_mouse_on_child(scene.findObject("items_list"), curIdx)
    this.msgBox("purchase_ask", msgText,
      [
        ["yes", function() {
          if (::check_balance_msgBox(price))
            goForwardIfPurchase()
        }],
        ["no", onCancel ]
      ], "yes", { cancel_fn = onCancel }
    )
  }

  function onOnlinePurchase(itemId)
  {
    let payMethods = yuplay2_get_payment_methods()
    if (!payMethods || ::steam_is_running() || !::has_feature("PaymentMethods"))
      return ::OnlineShopModel.doBrowserPurchase(itemId)

    let items = []
    local selItem = null
    foreach(method in payMethodsCfg)
      if (payMethods & method.id)
      {
        let payMethodId = method.id
        let name = "yuNetwork/payMethod/" + method.name
        items.append({
          name = name
          icon = "!#ui/gameuiskin/payment_" + method.name + ".svg"
          callback = ::Callback(@() onYuplayPurchase(itemId, payMethodId, name), this)
        })
        selItem = selItem || name
      }

    let name = "yuNetwork/payMethod/other"
    items.append({
      name = name
      icon = ""
      callback = ::Callback(@() ::OnlineShopModel.doBrowserPurchase(itemId), this)
    })
    selItem = selItem || name

    ::gui_modal_payment({items = items, owner = this, selItem = selItem, cancel_fn = function() {}})
  }

  function onYuplayPurchase(itemId, payMethod, nameLocId)
  {
    let msgText = ::loc("onlineShop/needMoneyQuestion/onlinePaymentSystem", {
      purchase = ::colorize("activeTextColor", getEntitlementName(goods[itemId])),
      paymentSystem = ::colorize("userlogColoredText", ::loc(nameLocId))
    })
    this.msgBox("yuplay_purchase_ask", msgText,
      [ ["yes", @() doYuplayPurchase(itemId, payMethod) ],
        ["no", function(){}]
      ], "yes", { cancel_fn = function(){}})
  }

  function doYuplayPurchase(itemId, payMethod)
  {
    let guid = bundlesShopInfo.value?[itemId].guid ?? ""
    ::dagor.assertf(guid != "", $"Error: not found guid for {itemId}")

    let response = (guid=="")? -1 : ::yuplay2_buy_entitlement(guid, payMethod)
    if (response != ::YU2_OK)
    {
      let errorText = ::get_yu2_error_text(response)
      this.msgBox("errorMessageBox", errorText, [["ok", function(){}]], "ok")
      ::dagor.debug($"yuplay2_buy_entitlement have returned {response} with task = {itemId}, guid = {guid}, payMethod = {payMethod}")
      return
    }

    ::update_entitlements()

    this.msgBox("purchase_done",
      format(::loc("userlog/buy_entitlement"), getEntitlementName(goods[itemId])),
      [["ok", @() null]], "ok", { cancel_fn = @() null})
  }

  function onApply(obj)
  {
    onStart()
  }

  function onRowBuy(obj)
  {
    if (!obj)
      return

    let pObj = obj.getParent()
    if (!pObj || !(pObj?.id in goods))
      return
    let id = pObj.id

    let listObj = scene.findObject("items_list")
    if (!listObj)
      return
    for (local idx = 0; idx < listObj.childrenCount(); idx++)
      if (listObj.getChild(idx).id == id)
      {
        listObj.setValue(idx)
        onItemSelect()

        onStart()
        break
      }
  }

  function updateItemIcon(name)
  {
    if (useRowVisual)
      return

    let obj = scene.findObject("items_list").findObject(name)
    let curIcon = getItemIcon(name)
    if (curIcon && obj)
    {
      let medalObj = obj.findObject("medal_icon")
      if (medalObj)
        medalObj["background-image"] = curIcon
    }
  }

  function goForward(startFunc)  //no forward from this wnd, only purchase finished.
  {
    if (::checkObj(scene))
    {
      onItemSelect()
      updateItemIcon(task)
      ::update_gamercards()
    }
    ::broadcastEvent("OnlineShopPurchaseSuccessful", { purchData = goods?[task] ?? {} })
  }

  function onEventModalWndDestroy(params)
  {
    if (isSceneActiveNoModals())
      ::move_mouse_on_child_by_value(getObj("items_list"))
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
      savingText = ::loc("ui/parentheses", {text = ::loc("charServer/entitlement/firstBuy")})
    else if (productInfo?.discount_mul)
      savingText = format(::loc("charServer/entitlement/discount"), (1.0 - productInfo.discount_mul)*100)
    else if (item?.group && item.group in groupCost) {
      let itemPrice = getEntitlementPriceFloat(item)
      let defItemPrice = groupCost[item.group]
      if (itemPrice > 0 && defItemPrice && (!isGold || !::steam_is_running())) {
        let calcAmount = amount + additionalAmount
        local saving = (1 - ((itemPrice * (1 - discount*0.01)) / (calcAmount * defItemPrice))) * 100
        saving = saving.tointeger()
        if (saving >= MIN_DISPLAYED_PERCENT_SAVING)
          savingText = format(::loc("charServer/entitlement/discount"), saving)
      }
    }

    let isTimeAmount = item?.httl || item?.ttl
    if (isTimeAmount)
      amount *= 24

    if (isTimeAmount)
      amountText = time.hoursToString(amount, false, false, true)
    else {
      amount = amount.tointeger()

      let originAmount = isGold? ::Cost(0, amount) : ::Cost(amount, 0)
      local addString = ""
      if (additionalAmount > 0) {
        let addAmount = isGold? ::Cost(0, additionalAmount) : ::Cost(additionalAmount, 0)
        addString = ::loc("ui/parentheses/space", {text = "+" + addAmount.tostring()})
      }

      amountText = originAmount.tostring() + addString
    }

    return {
      externalLink = isGold
      rowName = item.name
      rowEven = even
      amount = amountText
      savingText = savingText
      cost = getItemPriceText(item.name)
      discount = discount > 0 ? $"-{discount}%": null
    }
  }
}

::gui_handlers.OnlineShopRowHandler <- class extends ::gui_handlers.OnlineShopHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"
  sceneNavBlkName = null
  useRowVisual = true

  function updateProductInfo(product, productId) {
    local descText = getEntitlementDescription(product, productId)
    let renewText = getEntitlementTimeText(product)
    if (renewText != "") {
      let realname = ("alias" in product) ? product.alias : productId
      let expire = entitlement_expires_in(realname == "PremiumAccount"
        ? ::shop_get_premium_account_ent_name()
        : realname)
      if (expire>0)
        descText = "".concat(descText,
          ::colorize("chapterUnlockedColor",
            $"{::loc("subscription/activeTime")}{::loc("ui/colon")}{time.getExpireText(expire)}"))
    }
    scene.findObject("item_desc_text").setValue(descText)
  }

  function reinitScreen(params = {}) {
    base.reinitScreen(params)
    foreach(productId, product in goods) {
      updateProductInfo(product, productId) //for rows visual the same description for all items
      break
    }
  }
}
