let time = require("%scripts/time.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let ent = require("%scripts/onlineShop/entitlements.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")

let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")
bundlesShopInfo.subscribe(@(val) ::broadcastEvent("BundlesUpdated")) //cannot subscribe directly to reinitScreen inside init

let payMethodsCfg = [
  { id = ::YU2_PAY_QIWI,        name = "qiwi" }
  { id = ::YU2_PAY_YANDEX,      name = "yandex" }
  { id = ::YU2_PAY_PAYPAL,      name = "paypal" }
  { id = ::YU2_PAY_WEBMONEY,    name = "webmoney" }
  { id = ::YU2_PAY_AMAZON,      name = "amazon" }
  { id = ::YU2_PAY_GJN,         name = "gjncoins" }
]

const MIN_DISPLAYED_PERCENT_SAVING = 5

local bonusPercentText = @(v) "+{0}".subst(::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(v - 1.0))

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

  premiumRpMult = 1.0
  premiumWpMult = 1.0
  premiumBattleTimeWpMult = 1.0
  premiumOtherModesWpMult = 1.0

  goods = null
  chImages = null
  bundles = null
  groupCost = null
  task = ""
  needFullUpdate = false

  exchangedWarpointsExpireDays = {
    ["Japanese"] = 180
  }

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
        groupCost[goods[name].group] <- getPricePerItem(goods[name])

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
        chImages = (chapter in chImages) ? $"#ui/onlineShop/{chImages[chapter]}" : null
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
          local text = ent.getEntitlementName(item)
          let priceText = getItemPriceText(name)
          if (priceText!="")
            text = ::format("(%s) %s", priceText, text)
          obj.setValue(text)
        }
        if (name in bundles)
          updateItemIcon(name)
      }
    }

    let rBlk = ::get_ranks_blk()
    let wBlk = ::get_warpoints_blk()
    premiumRpMult = rBlk?.xpMultiplier || 1.0
    premiumWpMult = wBlk?.wpMultiplier || 1.0
    premiumBattleTimeWpMult = premiumWpMult * (wBlk?.battleTimePremMul || 1.0)
    premiumOtherModesWpMult = premiumWpMult

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

  function getPrice(item)
  {
    local cost = -1
    if (item?.onlinePurchase)
    {
      local costText = ""
      if (::steam_is_running())
        costText = ::loc("price/steam/" + item.name, "")
      if (costText == "")
        costText = ::loc("price/" + item.name, "")

      if (costText != "")
        cost = costText.tofloat()
    }
    else if (item?.goldCost)
      cost = item.goldCost

    return cost
  }

  function getPricePerItem(item)
  {
    let value = ent.getEntitlementAmount(item)
    if (value <= 0)
      return 0

    let cost = getPrice(item)
    return cost.tofloat() / value
  }

  function getItemPriceText(name)
  {
    if (name in goods)
      return ent.getEntitlementPrice(goods[name])
    return ""
  }

  function isBuyOnce(item)
  {
    return (item?.chapter
            && (item.chapter == "campaign"
                || item.chapter == "license"
                || item.chapter == "bonuses")
            )
            || item?.hideWhenUnbought
  }

  function isBought(item)
  {
    if (item?.name != null && bundles?[item.name] != null)
    {
      foreach(name in bundles[item.name])
        if (!goods?[name] || !isBought(goods[name]))
          return false
      return true
    }
    let realname = item?.alias ?? item.name
    return (isBuyOnce(item) && ::has_entitlement(realname))
  }

  function getItemIcon(name)
  {
    if ((name in goods) && isBought(goods[name]))
      return "#ui/gameuiskin#favorite"
    return null
  }

  function getDescription(product, productId) {
    if (product == null)
      return ""

    let resArr = []
    let paramTbl = {
      bonusRpPercent           = bonusPercentText(premiumRpMult)
      bonusWpPercent           = bonusPercentText(premiumWpMult)
      bonusBattleTimeWpPercent = bonusPercentText(premiumBattleTimeWpMult)
      bonusOtherModesWpPercent = bonusPercentText(premiumOtherModesWpMult)
    }
    if (product?.useGroupAmount && ("group" in product))
      paramTbl.amount <- ent.getEntitlementAmount(product).tointeger()

    let locId = "charServer/entitlement/{0}/desc".subst(ent.getEntitlementLocId(product))
    resArr.append(::loc(locId, paramTbl))

    foreach(giftName in product.entitlementGift)
    {
      let config = ent.getEntitlementConfig(giftName)
      resArr.append(format(::loc("charServer/gift/entitlement"), ent.getEntitlementName(config)))
    }
    foreach(airName in product.aircraftGift)
      resArr.append(format(::loc("charServer/gift/aircraft"), ::getUnitName(airName)))

    if (product?.goldIncome && product?.chapter!="eagles")
      resArr.append(format(::loc("charServer/gift"), "".concat(product.goldIncome, ::loc("gold/short/colored"))))

    if ("afterGiftsDesc" in product)
      resArr.append("\n{0}".subst(::loc(product.afterGiftsDesc)))

    if (("ttl" in product) || ("httl" in product))
    {
      let renewText = ent.getEntitlementTimeText(product)
      if (renewText!="")
      {
        let realname = ("alias" in product) ? product.alias : productId
        let expire = entitlement_expires_in(realname == "PremiumAccount"
          ? ::shop_get_premium_account_ent_name()
          : realname)
        if (expire>0)
          resArr.append(::colorize("chapterUnlockedColor",
            "".concat(::loc("subscription/activeTime"), ::loc("ui/colon"), time.getExpireText(expire), "\n")))
        if (!useRowVisual)
          resArr.append("".concat(::loc("subscription/renew"), ::loc("ui/colon"), renewText, "\n"))
      }
    }

    let priceText = ent.getEntitlementPrice(product)
    if (!useRowVisual && priceText!="")
    {
      local priceInfo = ""
      if (("group" in product) && (product.group in groupCost))
      {
        let itemPrice = getPricePerItem(product)
        let defItemPrice = groupCost[product.group]
        if (itemPrice && defItemPrice)
        {
          let discount = ::floor(100.5 - 100.0 * itemPrice / defItemPrice)
          if (discount != 0)
            priceInfo = format(::loc("charServer/entitlement/discount"), discount)
        }
      } else
        if (productId in bundles)
        {
          let itemPrice = getPrice(product)
          local bundlePrice = 0
          foreach(name in bundles[productId])
            if (name in goods)
              bundlePrice += getPrice(goods[name])
          if (bundlePrice>0)
          {
            let discount = ::floor(100.5 - 100.0 * itemPrice / bundlePrice)
            priceInfo = format(::loc("charServer/entitlement/discount"), discount)
          }
        }
      resArr.append("".concat("<B>", ::loc("ugm/price"), ::loc("ui/colon"), priceText, priceInfo, "</B>"))
    }

    if (product?.onlinePurchase && !isBought(product) && ::steam_is_running())
      resArr.append(::loc("charServer/web_purchase"))

    if (product?.chapter == "warpoints")
    {
      let days = exchangedWarpointsExpireDays?[::g_language.getLanguageName()] ?? 0
      if (days > 0)
        resArr.append(::colorize("warningTextColor",
          ::loc("charServer/chapter/warpoints/expireWarning", { days = days })))
    }
    return "\n".join(resArr)
  }

  function updateProductInfo(product, productId) {
    scene.findObject("item_desc_text").setValue(getDescription(product, productId))

    local image = ""
    if (product != null)
      image = ("image" in product)? "#ui/onlineShop/"+product.image : ""
    else
      image = (productId in chImages)? "#ui/onlineShop/"+chImages[productId] : ""
    scene.findObject("item_desc_header_img")["background-image"] = image

    priceText = getItemPriceText(productId)
    showSceneBtn("btn_buy_online", product != null && !isBought(product))
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
    if (product == null || isBought(product))
      return
    if (product?.onlinePurchase ?? false)
      return onOnlinePurchase(task)

    let costGold = "goldCost" in product? ::get_entitlement_cost_gold(product.name) : 0
    let price = ::Cost(0, costGold)
    let msgText = ::warningIfGold(
      ::loc("onlineShop/needMoneyQuestion",
        {purchase = ent.getEntitlementName(product), cost = price.getTextAccordingToBalance()}),
      price)
    let curIdx = scene.findObject("items_list").getValue()
    let onCancel = @() ::move_mouse_on_child(scene.findObject("items_list"), curIdx)
    msgBox("purchase_ask", msgText,
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
      purchase = ::colorize("activeTextColor", ent.getEntitlementName(goods[itemId])),
      paymentSystem = ::colorize("userlogColoredText", ::loc(nameLocId))
    })
    msgBox("yuplay_purchase_ask", msgText,
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
      msgBox("errorMessageBox", errorText, [["ok", function(){}]], "ok")
      ::dagor.debug($"yuplay2_buy_entitlement have returned {response} with task = {itemId}, guid = {guid}, payMethod = {payMethod}")
      return
    }

    ::update_entitlements()

    msgBox("purchase_done",
      format(::loc("userlog/buy_entitlement"), ent.getEntitlementName(goods[itemId])),
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
    local amount = ent.getEntitlementAmount(item)
    let additionalAmount = ent.getFirstPurchaseAdditionalAmount(item)
    local amountText = ""
    local savingText = ""
    let discount = ::g_discount.getEntitlementDiscount(item.name)
    let productInfo = bundlesShopInfo.value?[item.name]

    if (additionalAmount > 0)
      savingText = ::loc("ui/parentheses", {text = ::loc("charServer/entitlement/firstBuy")})
    else if (productInfo?.discount_mul)
      savingText = ::format(::loc("charServer/entitlement/discount"), (1.0 - productInfo.discount_mul)*100)
    else if (item?.group && item.group in groupCost) {
      let itemPrice = getPrice(item)
      let defItemPrice = groupCost[item.group]
      if (itemPrice && defItemPrice && (!isGold || !::steam_is_running())) {
        let calcAmount = amount + additionalAmount
        local saving = (1 - ((itemPrice * (1 - discount*0.01)) / (calcAmount * defItemPrice))) * 100
        saving = saving.tointeger()
        if (saving >= MIN_DISPLAYED_PERCENT_SAVING)
          savingText = ::format(::loc("charServer/entitlement/discount"), saving)
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

  updateProductInfo = @(product, productId)
    scene.findObject("item_desc_text").setValue(getDescription(product, productId))

  function reinitScreen(params = {}) {
    base.reinitScreen(params)
    foreach(productId, product in goods) {
      updateProductInfo(product, productId) //for rows visual the same description for all items
      break
    }
  }
}
