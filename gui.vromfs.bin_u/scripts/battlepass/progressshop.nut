local { maxSeasonLvl, hasBattlePass, battlePassShopConfig, season } = require("scripts/battlePass/seasonState.nut")
local { refreshUserstatUnlocks, isUserstatMissingData
} = require("scripts/userstat/userstat.nut")
local globalCallbacks = require("sqDagui/globalCallbacks/globalCallbacks.nut")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")

local seasonShopConfig = ::Computed(@() {
  purchaseWndItems = battlePassShopConfig.value ?? []
  seasonId = season.value
})

local BattlePassShopWnd = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptyFrame.blk"

  goods = null

  hasBuyImprovedBattlePass = false

  function initScreen() {
    if (seasonShopConfig.value.purchaseWndItems.len() == 0)
      return goBack()

    updateWindow()
  }

  function updateWindow() {
    scene.findObject("wnd_title").setValue(::loc("battlePass"))
    local rootObj = scene.findObject("wnd_frame")
    rootObj["class"] = "wnd"
    rootObj.width = "@onlineShopWidth + 2@blockInterval"
    rootObj.padByLine = "yes"
    local contentObj = rootObj.findObject("wnd_content")
    contentObj.flow = "vertical"

    rootObj.setValue(stashBhvValueConfig([{
      watch = seasonShopConfig
      updateFunc = ::Callback(@(obj, shopConfig) updateContent(shopConfig), this)
    }]))
  }

  function updateContent(shopConfig) {
    goods = []
    foreach (idx, config in shopConfig.purchaseWndItems) {
      local { battlePassUnlock = "", additionalTrophy = [] } = config
      local passUnlock = ::g_unlocks.getUnlockById(battlePassUnlock)
      local additionalTrophyItems = additionalTrophy.map(@(itemId) ::ItemsManager.findItemById(
        ::to_integer_safe(itemId, itemId, false)))

      local goodsConfig = getGoodsConfig({
        additionalTrophyItems = getSortedAdditionalTrophyItems(additionalTrophyItems)
        battlePassUnlock = passUnlock
        hasBattlePassUnlock = battlePassUnlock != ""
        rowIdx = idx
        seasonId = shopConfig.seasonId
      })

      goods.append(goodsConfig)
    }

    updateRowsView()
  }

  function actualizeGoodsConfig() {
    goods = goods.map((@(g) getGoodsConfig(g)).bindenv(this))
  }

  function updateRowsView() {
    local hasBuyImprovedPass = hasBuyImprovedBattlePass
    local rowsView = goods
      .filter(@(g) !g.cost.isZero() && (!g.hasBattlePassUnlock || g.battlePassUnlock != null))
      .map(function(g, idx) {
        local isRealyBought = g.isBought && (!hasBuyImprovedPass || g.isImprovedBattlePass)
        return {
          rowName = g.rowIdx
          rowEven = (idx%2 == 0) ? "yes" :"no"
          amount = g.name
          savingText = g.valueText
          cost = $"{isRealyBought ? ::loc("check_mark/green") : ""} {g.cost.tostring()}"
          isDisabled = g.isDisabled
        }
      })
    guiScene.setUpdatesEnabled(false, false)

    local contentObj = scene.findObject("wnd_content")
    local data = ::handyman.renderCached(("gui/onlineShop/onlineShopWithVisualRow"), {
      chImages = "#ui/onlineShop/battle_pass_header"
      descText = ::loc("battlePass/buy/desc", { count = maxSeasonLvl.value })
      rows = rowsView
    })
    guiScene.replaceContentFromText(contentObj, data, data.len(), this)
    guiScene.setUpdatesEnabled(true, true)

    local valueToSelect = rowsView.findindex(@(r) !r.isDisabled) ?? -1
    local tblObj = scene.findObject("items_list")
    guiScene.performDelayed(this, @() ::move_mouse_on_child(tblObj, valueToSelect))
  }

  isGoodsBought = @(goodsConfig) goodsConfig.hasBattlePassUnlock
    && (hasBattlePass.value || ::is_unlocked_scripted(-1, goodsConfig.battlePassUnlock?.id))

  function buyGood(goodsConfig) {
    local { additionalTrophyItem, battlePassUnlock, rowIdx } = goodsConfig
    ::dagor.debug($"Buy Battle Pass goods. goodsIdx: {rowIdx}")
    if (battlePassUnlock != null)
      g_unlocks.buyUnlock(battlePassUnlock, function() {
        refreshUserstatUnlocks()
        ::broadcastEvent("BattlePassPurchased")
      })
    if (additionalTrophyItem != null) {
      local cost = additionalTrophyItem.getCost()
      additionalTrophyItem._buy(@(res) null, { cost = cost.wp, costGold = cost.gold })
    }
  }

  function disableBattlePassRows() { //disable battle pass buy button
    local listObj = scene.findObject("items_list")
    if (!listObj?.isValid())
      return
    foreach (idx, goodsConfig in goods) {
      local obj = listObj.findObject(idx.tostring())
      if (obj?.isValid())
        obj.enable = goodsConfig.hasBattlePassUnlock ? "no" : "yes"
    }
  }

  function onBuy(curGoodsIdx) {
    local goodsConfig = goods?[curGoodsIdx]
    if (goodsConfig == null || isGoodsBought(goodsConfig))
      return

    local msgText = ::warningIfGold(
      ::loc("onlineShop/needMoneyQuestion", {
          purchase = $"{goodsConfig.name} {goodsConfig.valueText}",
          cost = goodsConfig.cost.getTextAccordingToBalance()}),
      goodsConfig.cost)
    local onCancel = @() ::move_mouse_on_child(scene.findObject("items_list"), curGoodsIdx)
    msgBox("purchase_ask", msgText,
      [
        ["yes", function() {
          if (::check_balance_msgBox(goodsConfig.cost)) {
            buyGood(goodsConfig)
            if (goodsConfig.hasBattlePassUnlock)
              disableBattlePassRows()
          }
        }],
        ["no", onCancel ]
      ], "yes", { cancel_fn = onCancel }
    )
  }

  function onRowBuy(obj) {
    local value = scene.findObject("items_list").getValue()
    if (value in goods)
      onBuy(value)
  }

  function onEventModalWndDestroy(params) {
    if (isSceneActiveNoModals())
      ::move_mouse_on_child_by_value(getObj("items_list"))
  }

  function getGoodsConfig(goodsConfig) {
    local name = ""
    local valueText = ""
    local isBought = false
    local isDisabled = false
    local cost = ::Cost()
    local { additionalTrophyItems, battlePassUnlock, seasonId } = goodsConfig
    local additionalTrophyItem = getAdditionalTrophyItemForBuy(additionalTrophyItems)
    local isBattlePassConfig = battlePassUnlock != null
    if (isBattlePassConfig)
      additionalTrophyItem = additionalTrophyItem ?? additionalTrophyItems?[0]
    local hasAdditionalTrophyItem = additionalTrophyItem != null
    if (hasAdditionalTrophyItem) {
      local topPrize = additionalTrophyItem.getTopPrize()
      name = ::PrizesView.getPrizeTypeName(topPrize, false)
      valueText = ::PrizesView.getPrizeText(topPrize, false)
      cost = cost + additionalTrophyItem.getCost()
    }
    local isImprovedBattlePass = isBattlePassConfig && hasAdditionalTrophyItem
    if (battlePassUnlock != null) {
      local prizeLocId = isImprovedBattlePass ? "battlePass/improvedBattlePassName" : "battlePass/name"
      name = ::loc(prizeLocId, { name = ::loc($"battlePass/seasonName/{seasonId}") })
      isBought = isGoodsBought(goodsConfig)
      isDisabled = isBought
      if (hasAdditionalTrophyItem) {
        isBought = isBought && !additionalTrophyItem.canBuyTrophyByLimit() //trophy of improved battle pass is already buy
        valueText = ::loc("ui/parentheses", { text = valueText })
      }
      cost = cost + ::get_unlock_cost(battlePassUnlock.id)
    }
    if (isImprovedBattlePass)
      hasBuyImprovedBattlePass = isBought

    return goodsConfig.__merge({
      name
      valueText
      isBought
      cost
      additionalTrophyItem
      isImprovedBattlePass
      isDisabled
    })
  }

  getSortedAdditionalTrophyItems = @(additionalTrophyItems)
    additionalTrophyItems.sort(@(a, b) (a?.getCost() ?? 0) <=> (b?.getCost() ?? 0))

  getAdditionalTrophyItemForBuy = @(additionalTrophyItems) (additionalTrophyItems
    .filter(@(item) item?.isCanBuy() && item?.canBuyTrophyByLimit()))?[0]

  function onEventProfileUpdated(p) {
    actualizeGoodsConfig()
    updateRowsView()
  }
}

::gui_handlers.BattlePassShopWnd <- BattlePassShopWnd

local function openBattlePassShopWnd() {
  if (isUserstatMissingData.value) {
    ::showInfoMsgBox(::loc("userstat/missingDataMsg"), "userstat_missing_data_msgbox")
    return
  }

  ::handlersManager.loadHandler(BattlePassShopWnd)
}


globalCallbacks.addTypes({
  openBattlePassShopWnd = {
    onCb = @(obj, params) openBattlePassShopWnd()
  }
})

return {
  openBattlePassShopWnd
}
