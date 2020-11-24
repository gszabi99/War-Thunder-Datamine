local time = require("scripts/time.nut")
local { topMenuHandler } = require("scripts/mainmenu/topMenuStates.nut")
local { getBundleId } = require("scripts/onlineShop/onlineBundles.nut")
local ent = require("scripts/onlineShop/entitlements.nut")

local payMethodsCfg = [
  { id = ::YU2_PAY_QIWI,        name = "qiwi" }
  { id = ::YU2_PAY_YANDEX,      name = "yandex" }
  { id = ::YU2_PAY_PAYPAL,      name = "paypal" }
  { id = ::YU2_PAY_WEBMONEY,    name = "webmoney" }
  { id = ::YU2_PAY_AMAZON,      name = "amazon" }
  { id = ::YU2_PAY_GJN,         name = "gjncoins" }
]

const MIN_DISPLAYED_PERCENT_SAVING = 5

class ::gui_handlers.OnlineShopHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chapterModal.blk"
  sceneNavBlkName = "gui/navOnlineShop.blk"
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

    ::configs.ENTITLEMENTS_PRICE.checkUpdate(
      ::Callback(function()
      {
        reinitScreen()
      }, this)
      ::Callback(function(result) { reinitScreen() }, this)
      true
    )
  }

  function reinitScreen(params = {})
  {
    if (!::checkObj(scene))
      return goBack()

    setParams(params)

    local blockObj = scene.findObject("chapter_include_block")
    if (::checkObj(blockObj))
      blockObj.show(true)

    goods = {}
    chImages = {}
    bundles = {}
    groupCost = {}

    local data = ""
    local rowsView = []
    local idx = 0
    local isGold = chapter == "eagles"
    local curChapter = ""
    local eblk = ::DataBlock()
    ::get_shop_prices(eblk)

    local first = true
    foreach (name, ib in eblk)
    {
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
        local paramName = ib.getParamName(j)
        if (!(paramName in goods[name]))
          goods[name][paramName] <- ib.getParamValue(j)
      }

      if (ib?.bundle)
        bundles[name] <- ib.bundle % "item"

      foreach(param in ["entitlementGift", "aircraftGift", "showEntAsGift"])
      {
        local arr = []
        local list = ib % param
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
        rowsView.append(getRowView(name, goods[name], isGold, (idx%2 == 0) ? "yes" :"no"))
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
            local view = {
              itemTag = "chapter_item_unlocked"
              id = curChapter
              itemText = "#charServer/chapter/" + curChapter
            }
            data += ::handyman.renderCached("gui/missions/missionBoxItem", view)
          }
          if (goods[name]?.chapterImage)
            chImages[goods[name].chapter] <- goods[name].chapterImage
        }

        local discount = ::g_discount.getEntitlementDiscount(name)
        local view = {
          itemIcon = getItemIcon(name)
          id = name
          isSelected = first
          discountText = discount > 0? ("-" + discount + "%") : null
        }
        data += ::handyman.renderCached("gui/missions/missionBoxItem", view)
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

      local rootObj = scene.findObject("wnd_frame")
      rootObj["class"] = "wnd"
      rootObj.width = "@onlineShopWidth + 2@blockInterval"
      rootObj.padByLine = "yes"
      local contentObj = scene.findObject("wnd_content")
      contentObj.flow = "vertical"

      data = ::handyman.renderCached(("gui/onlineShop/onlineShopWithVisualRow"), {
        chImages = (chapter in chImages) ? $"#ui/onlineShop/{chImages[chapter]}" : null
        rows = rowsView
      })
      guiScene.replaceContentFromText(contentObj, data, data.len(), this)
      local tblObj = scene.findObject("items_list")

      guiScene.setUpdatesEnabled(true, true)
      guiScene.performDelayed(this, @() ::move_mouse_on_child(tblObj, 0))
    }
    else
    {// Buy Campaigns & Bonuses.
      scene.findObject("chapter_update").setUserData(this)
      scene.findObject("chapter_name").setValue(::loc("mainmenu/btnOnlineShop"))

      local listObj = scene.findObject("items_list")
      guiScene.replaceContentFromText(scene.findObject("items_list"), data, data.len(), this)

      foreach(name, item in goods)
      {
        local obj = listObj.findObject("txt_" + name)
        if (obj)
        {
          local text = ent.getEntitlementName(item)
          local priceText = getItemPriceText(name)
          if (priceText!="")
            text = ::format("(%s) %s", priceText, text)
          obj.setValue(text)
        }
        if (name in bundles)
          updateItemIcon(name)
      }
    }

    local rBlk = ::get_ranks_blk()
    local wBlk = ::get_warpoints_blk()
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
    local value = ent.getEntitlementAmount(item)
    if (value <= 0)
      return 0

    local cost = getPrice(item)
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
    local realname = item?.alias ?? item.name
    return (isBuyOnce(item) && ::has_entitlement(realname))
  }

  function getItemIcon(name)
  {
    if ((name in goods) && isBought(goods[name]))
      return "#ui/gameuiskin#favorite"
    return null
  }

  function onItemSelect()
  {
    local listObj = scene.findObject("items_list")
    local value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return

    local obj = listObj.getChild(value)
    task = obj.id

    local isGoods = task in goods
    local desc = ""
    local paramTbl = {
      bonusRpPercent           = "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(premiumRpMult - 1.0)
      bonusWpPercent           = "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(premiumWpMult - 1.0)
      bonusBattleTimeWpPercent = "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(premiumBattleTimeWpMult - 1.0)
      bonusOtherModesWpPercent = "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(premiumOtherModesWpMult - 1.0)
    }
    if (isGoods && ("useGroupAmount" in goods[task]) && goods[task].useGroupAmount && ("group" in goods[task]))
      paramTbl.amount <- ent.getEntitlementAmount(goods[task]).tointeger()

    local locId = isGoods? ent.getEntitlementLocId(goods[task]) : task
    locId = format(isGoods? "charServer/entitlement/%s/desc":"charServer/chapter/%s/desc", locId)
    desc = ::loc(locId, paramTbl)

    if (isGoods)  //show gifts
    {
      local item = goods[task]
      foreach(giftName in item.entitlementGift)
      {
        local config = ent.getEntitlementConfig(giftName)
        desc+= "\n" + format(::loc("charServer/gift/entitlement"), ent.getEntitlementName(config))
      }
      foreach(airName in item.aircraftGift)
        desc+= "\n" + format(::loc("charServer/gift/aircraft"), ::getUnitName(airName))

      if (("goldIncome" in item) && item.goldIncome && (!("chapter" in item) || item.chapter!="eagles"))
        desc+= "\n" + format(::loc("charServer/gift"), item.goldIncome + ::loc("gold/short/colored"))

      if ("afterGiftsDesc" in item)
        desc+= "\n\n" + ::loc(item.afterGiftsDesc)
    }

    if (isGoods && (("ttl" in goods[task]) || ("httl" in goods[task])))
    {
      local renewText = ent.getEntitlementTimeText(goods[task])
      if (renewText!="")
      {
        local realname = ("alias" in goods[task]) ? goods[task].alias : task
        local expire = entitlement_expires_in(realname == "PremiumAccount"
          ? ::shop_get_premium_account_ent_name()
          : realname)
        if (expire>0)
          desc+= format("\n<color=@chapterUnlockedColor>%s</color>",
                   ::loc("subscription/activeTime") + ::loc("ui/colon") + time.getExpireText(expire)) + "\n"
        if (!useRowVisual)
          desc += "\n"+::loc("subscription/renew") + ::loc("ui/colon") + renewText + "\n"
      }
    }

    local priceText = getItemPriceText(task)
    if (!useRowVisual && priceText!="")
    {
      desc += "\n<B>" + ::loc("ugm/price") + ::loc("ui/colon") + priceText
      if (("group" in goods[task]) && (goods[task].group in groupCost))
      {
        local itemPrice = getPricePerItem(goods[task])
        local defItemPrice = groupCost[goods[task].group]
        if (itemPrice && defItemPrice)
        {
          local discount = ::floor(100.5 - 100.0 * itemPrice / defItemPrice)
          if (discount != 0)
            desc += format(::loc("charServer/entitlement/discount"), discount)
        }
      } else
        if (task in bundles)
        {
          local itemPrice = getPrice(goods[task])
          local bundlePrice = 0
          foreach(name in bundles[task])
            if (name in goods)
              bundlePrice += getPrice(goods[name])
          if (bundlePrice>0)
          {
            local discount = ::floor(100.5 - 100.0 * itemPrice / bundlePrice)
            desc += format(::loc("charServer/entitlement/discount"), discount)
          }
        }
      desc += "</B>"
    }

    if (isGoods && ("onlinePurchase" in goods[task]) && goods[task].onlinePurchase && !isBought(goods[task]))
      desc += (useRowVisual? "\n" : "\n\n") + (::steam_is_running() ? "" : ::loc("charServer/web_purchase"))

    if (isGoods && ::getTblValue("chapter", goods[task]) == "warpoints")
    {
      local days = ::getTblValue(::g_language.getLanguageName(), exchangedWarpointsExpireDays, 0)
      if (days)
      {
        local expireWarning = ::loc("charServer/chapter/warpoints/expireWarning", { days = days })
        desc += (useRowVisual? "\n" : "\n\n") + ::colorize("warningTextColor", expireWarning)
      }
    }

    scene.findObject("item_desc_text").setValue(desc)

    if (!useRowVisual)
    {
      local image = ""
      if (isGoods)
        image = ("image" in goods[task])? "#ui/onlineShop/"+goods[task].image : ""
      else
        image = (task in chImages)? "#ui/onlineShop/"+chImages[task] : ""
      scene.findObject("item_desc_header_img")["background-image"] = image

      priceText = getItemPriceText(task)
      showSceneBtn("btn_buy_online", isGoods && !isBought(goods[task]))
      scene.findObject("btn_buy_online").setValue(::loc("mainmenu/btnBuy") + ((priceText=="")? "" : format(" (%s)", priceText)))

      local discountText = ""
      local discount = ::g_discount.getEntitlementDiscount(goods[task].name)
      if (isGoods && discount > 0)
        discountText = "-" + discount + "%"
      scene.findObject("buy_online-discount").setValue(discountText)
    }
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
    local taskId = ::purchase_entitlement(task)
    local taskOptions = {
      showProgressBox = true
    }
    local taskSuccessCallback = ::Callback(function ()
      {
        goForward(startFunc)
        ::broadcastEvent("PurchaseSuccess")
      }, this)
    ::g_tasker.addTask(taskId, taskOptions, taskSuccessCallback)
  }

  function onStart()  //onBuy
  {
    local product = goods?[task]
    if (product == null || isBought(product))
      return
    if (product?.onlinePurchase ?? false)
      return onOnlinePurchase(task)

    local costGold = "goldCost" in product? ::get_entitlement_cost_gold(product.name) : 0
    local price = ::Cost(0, costGold)
    local msgText = ::warningIfGold(
      ::loc("onlineShop/needMoneyQuestion",
        {purchase = ent.getEntitlementName(product), cost = price.getTextAccordingToBalance()}),
      price)
    local curIdx = scene.findObject("items_list").getValue()
    local onCancel = @() ::move_mouse_on_child(scene.findObject("items_list"), curIdx)
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

  function onOnlinePurchase(purchaseTask)
  {
    local payMethods = yuplay2_get_payment_methods()
    if (!payMethods || ::steam_is_running() || !::has_feature("PaymentMethods"))
      return ::OnlineShopModel.doBrowserPurchase(purchaseTask)

    local items = []
    local selItem = null
    foreach(method in payMethodsCfg)
      if (payMethods & method.id)
      {
        local payMethodId = method.id
        local name = "yuNetwork/payMethod/" + method.name
        items.append({
          name = name
          icon = "!#ui/gameuiskin/payment_" + method.name + ".svg"
          callback = ::Callback(@() onYuplayPurchase(purchaseTask, payMethodId, name), this)
        })
        selItem = selItem || name
      }

    local name = "yuNetwork/payMethod/other"
    items.append({
      name = name
      icon = ""
      callback = ::Callback(@() ::OnlineShopModel.doBrowserPurchase(purchaseTask), this)
    })
    selItem = selItem || name

    ::gui_modal_payment({items = items, owner = this, selItem = selItem, cancel_fn = function() {}})
  }

  function onYuplayPurchase(purchaseTask, payMethod, nameLocId)
  {
    local msgText = ::loc("onlineShop/needMoneyQuestion/onlinePaymentSystem", {
      purchase = ::colorize("activeTextColor", ent.getEntitlementName(goods[purchaseTask])),
      paymentSystem = ::colorize("userlogColoredText", ::loc(nameLocId))
    })
    msgBox("yuplay_purchase_ask", msgText,
      [ ["yes", @() doYuplayPurchase(purchaseTask, payMethod) ],
        ["no", function(){}]
      ], "yes", { cancel_fn = function(){}})
  }

  function doYuplayPurchase(purchaseTask, payMethod)
  {
    local guid = getBundleId(purchaseTask)
    ::dagor.assertf(guid != "", "Error: not found guid for " + purchaseTask)

    local response = (guid=="")? -1 : ::yuplay2_buy_entitlement(guid, payMethod)
    if (response != ::YU2_OK)
    {
      local errorText = ::get_yu2_error_text(response)
      msgBox("errorMessageBox", errorText, [["ok", function(){}]], "ok")
      dagor.debug("yuplay2_buy_entitlement have returned " + response + " with task = " +
        purchaseTask + ", guid = " + guid + ", payMethod = " + payMethod)
      return
    }

    ::update_entitlements()

    msgBox("purchase_done",
      format(::loc("userlog/buy_entitlement"), ent.getEntitlementName(goods[purchaseTask])),
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

    local pObj = obj.getParent()
    if (!pObj || !(pObj?.id in goods))
      return
    local id = pObj.id

    local listObj = scene.findObject("items_list")
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

    local obj = scene.findObject("items_list").findObject(name)
    local curIcon = getItemIcon(name)
    if (curIcon && obj)
    {
      local medalObj = obj.findObject("medal_icon")
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
  function onListItemsFocusChange(obj) {}

  function getRowView(name, item, isGold, even) {
    local amount = ent.getEntitlementAmount(item)
    local additionalAmount = ent.getFirstPurchaseAdditionalAmount(item)
    local amountText = ""
    local savingText = ""
    local discount = ::g_discount.getEntitlementDiscount(item.name)

    if (additionalAmount > 0)
      savingText = ::loc("ui/parentheses", {text = ::loc("charServer/entitlement/firstBuy")})
    else if (item?.group && item.group in groupCost) {
      local itemPrice = getPrice(item)
      local defItemPrice = groupCost[item.group]
      if (itemPrice && defItemPrice && (!isGold || !::steam_is_running())) {
        local calcAmount = amount + additionalAmount
        local saving = (1 - ((itemPrice * (1 - discount*0.01)) / (calcAmount * defItemPrice))) * 100
        saving = saving.tointeger()
        if (saving >= MIN_DISPLAYED_PERCENT_SAVING)
          savingText = ::format(::loc("charServer/entitlement/discount"), saving)
      }
    }

    local isTimeAmount = item?.httl || item?.ttl
    if (isTimeAmount)
      amount *= 24

    if (isTimeAmount)
      amountText = time.hoursToString(amount, false, false, true)
    else {
      amount = amount.tointeger()

      local originAmount = isGold? ::Cost(0, amount) : ::Cost(amount, 0)
      local addString = ""
      if (additionalAmount > 0) {
        local addAmount = isGold? ::Cost(0, additionalAmount) : ::Cost(additionalAmount, 0)
        addString = ::loc("ui/parentheses/space", {text = "+" + addAmount.tostring()})
      }

      amountText = originAmount.tostring() + addString
    }

    return {
      externalLink = isGold
      rowName = name
      rowEven = even
      amount = amountText
      savingText = savingText
      cost = getItemPriceText(name)
      discount = discount > 0 ? $"-{discount}%": null
    }
  }

}

class ::gui_handlers.OnlineShopRowHandler extends ::gui_handlers.OnlineShopHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptyFrame.blk"
  sceneNavBlkName = null
  useRowVisual = true
}
