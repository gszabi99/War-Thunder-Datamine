local { maxSeasonLvl, hasBattlePass, battlePassShopConfig } = require("scripts/battlePass/seasonState.nut")
local { refreshUserstatUnlocks } = require("scripts/userstat/userstat.nut")
local globalCallbacks = require("sqDagui/globalCallbacks/globalCallbacks.nut")

local BattlePassShopWnd = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptyFrame.blk"

  goods = null

  function initScreen() {
    if (battlePassShopConfig.value == null)
      return

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

    updateContent()
    updateRowsView()
  }

  function updateContent() {
    goods = []
    foreach (idx, config in (battlePassShopConfig.value ?? [])) {
      local { battlePassUnlock = "", additionalTrophy = [] } = config
      local passUnlock = ::g_unlocks.getUnlockById(battlePassUnlock)
      local additionalTrophyItems = additionalTrophy.map(@(itemId) ::ItemsManager.findItemById(
        ::to_integer_safe(itemId, itemId, false)))

      local goodsConfig = getGoodsConfig({
        additionalTrophyItems = getSortedAdditionalTrophyItems(additionalTrophyItems)
        battlePassUnlock = passUnlock
        hasBattlePassUnlock = battlePassUnlock != ""
        rowIdx = idx
      })

      goods.append(goodsConfig)
    }
  }

  function actualizeGoodsConfig() {
    goods = goods.map((@(g) getGoodsConfig(g)).bindenv(this))
  }

  function updateRowsView() {
    local rowsView = goods
      .filter(@(g) !g.cost.isZero() && (!g.hasBattlePassUnlock || g.battlePassUnlock != null))
      .map(@(g, idx) {
        rowName = g.rowIdx
        rowEven = (idx%2 == 0) ? "yes" :"no"
        amount = g.name
        savingText = g.valueText
        cost = $"{g.isBought ? ::loc("check_mark/green") : ""} {g.cost.tostring()}"
        isDisabled = g.isBought
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
    local cost = ::Cost()
    local { additionalTrophyItems, battlePassUnlock } = goodsConfig
    local additionalTrophyItem = getAdditionalTrophyItemForBuy(additionalTrophyItems)
    if (additionalTrophyItem != null) {
      local topPrize = additionalTrophyItem.getTopPrize()
      name = ::PrizesView.getPrizeTypeName(topPrize, false)
      valueText = ::PrizesView.getPrizeText(topPrize, false)
      cost = cost + additionalTrophyItem.getCost()
    }
    if (battlePassUnlock != null) {
      name = ::loc("battlePass")
      isBought = isGoodsBought(goodsConfig)
      cost = cost + ::get_unlock_cost(battlePassUnlock.id)
    }

    return goodsConfig.__update({
      name = name
      valueText = valueText
      isBought = isBought
      cost = cost
      additionalTrophyItem = additionalTrophyItem
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

local openBattlePassShopWnd = @() ::handlersManager.loadHandler(BattlePassShopWnd)

globalCallbacks.addTypes({
  openBattlePassShopWnd = {
    onCb = @(obj, params) openBattlePassShopWnd()
  }
})

return {
  openBattlePassShopWnd
}
