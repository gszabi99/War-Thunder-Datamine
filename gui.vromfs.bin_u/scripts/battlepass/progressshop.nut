local { maxSeasonLvl, hasBattlePass, battlePassShopConfig } = require("scripts/battlePass/seasonState.nut")
local { refreshUserstatUnlocks } = require("scripts/userstat/userstat.nut")

local BattlePassShopWnd = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptyFrame.blk"

  goods = null
  curGoodIdx = null

  function initScreen() {
    if (battlePassShopConfig.value == null)
      return

    updateContent()
  }

  function updateContent() {
    goods = []
    local rowsView = []
    foreach (idx, config in (battlePassShopConfig.value ?? [])) {
      local { battlePassItem = "", additionalTrophy = "" } = config
      local passItem = ::ItemsManager.findItemById(
        ::to_integer_safe(battlePassItem, battlePassItem, false))
      local additionalTrophyItem = ::ItemsManager.findItemById(
        ::to_integer_safe(additionalTrophy, additionalTrophy, false))
      if (passItem == null && additionalTrophyItem == null)
        continue

      local goodsConfig = getGoodsConfig({
        additionalTrophyItem = additionalTrophyItem
        battlePassItem = passItem
      })

      rowsView.append({
        rowName = idx
        rowEven = (idx%2 == 0) ? "yes" :"no"
        amount = goodsConfig.name
        savingText = goodsConfig.valueText
        cost = goodsConfig.cost.tostring()
        isDisabled = goodsConfig.isDisabled
      })
      goods.append(goodsConfig)
    }

    guiScene.setUpdatesEnabled(false, false)
    scene.findObject("wnd_title").setValue(::loc("battlePass"))
    local rootObj = scene.findObject("wnd_frame")
    rootObj["class"] = "wnd"
    rootObj.width = "@onlineShopWidth + 2@blockInterval"
    rootObj.padByLine = "yes"
    local contentObj = rootObj.findObject("wnd_content")
    contentObj.flow = "vertical"

    local data = ::handyman.renderCached(("gui/onlineShop/onlineShopWithVisualRow"), {
      chImages = "#ui/onlineShop/battle_pass_header"
      descText = ::loc("battlePass/buy/desc", { count = maxSeasonLvl.value })
      rows = rowsView
    })
    guiScene.replaceContentFromText(contentObj, data, data.len(), this)
    local tblObj = scene.findObject("items_list")
    tblObj.setValue(rowsView.findindex(@(r) !r.isDisabled) ?? -1)

    guiScene.setUpdatesEnabled(true, true)
    guiScene.performDelayed(this, @() ::move_mouse_on_child_by_value(tblObj))

    ::move_mouse_on_child_by_value(scene.findObject("items_list"))
    onItemSelect()
  }

  hasBattlePassItem = @(goodsConfig) goodsConfig.battlePassItem != null

  isBought = @(goodsConfig) hasBattlePassItem(goodsConfig)
    && (hasBattlePass.value
      || ::ItemsManager.getInventoryItemById(goodsConfig.battlePassItem.id) != null)

  function buyGood(goodsConfig) {
    local { additionalTrophyItem, battlePassItem } = goodsConfig
    if (battlePassItem != null) {
      local cost = battlePassItem.getCost()
      battlePassItem._buy(function(res) {
        refreshUserstatUnlocks()
        ::broadcastEvent("BattlePassPurchased")
      }, { cost = cost.wp, costGold = cost.gold })
    }
    if (additionalTrophyItem != null) {
      local cost = additionalTrophyItem.getCost()
      additionalTrophyItem._buy(@(res) null, { cost = cost.wp, costGold = cost.gold })
    }
  }

  function disableBattlePassRows() { //disable battle pass buy button
    local listObj = scene.findObject("items_list")
    foreach (idx, goodsConfig in goods)
      listObj.findObject(idx.tostring()).enable =
        hasBattlePassItem(goodsConfig) ? "no" : "yes"
  }

  function onBuy() {
    local goodsConfig = goods?[curGoodIdx]
    if (goodsConfig == null || isBought(goodsConfig))
      return

    local msgText = ::warningIfGold(
      ::loc("onlineShop/needMoneyQuestion", {
          purchase = $"{goodsConfig.name} {goodsConfig.valueText}",
          cost = goodsConfig.cost.getTextAccordingToBalance()}),
      goodsConfig.cost)
    msgBox("purchase_ask", msgText,
      [
        ["yes", function() {
          if (::check_balance_msgBox(goodsConfig.cost)) {
            buyGood(goodsConfig)
            if (hasBattlePassItem(goodsConfig))
              disableBattlePassRows()
          }
        }],
        ["no", @() null ]
      ], "yes", { cancel_fn = @() null }
    )
  }

  function onItemSelect() {
    local listObj = scene.findObject("items_list")
    local value = ::get_obj_valid_index(listObj)
    if (value < 0)
      return

    curGoodIdx = value
  }

  function onRowBuy(obj) {
    local pObj = obj.getParent()
    if (!::check_obj(pObj))
      return

    local idx = pObj?.id.tointeger()
    if (!(idx in goods))
      return

    scene.findObject("items_list").setValue(idx)
    onItemSelect()
    onBuy()
  }

  function onEventModalWndDestroy(params) {
    if (isSceneActiveNoModals())
      ::move_mouse_on_child_by_value(getObj("items_list"))
  }

  function getGoodsConfig(goodsConfig) {
    local name = ""
    local valueText = ""
    local isDisabled = false
    local { additionalTrophyItem, battlePassItem } = goodsConfig
    if (additionalTrophyItem != null) {
      local topPrize = additionalTrophyItem.getTopPrize()
      name = ::PrizesView.getPrizeTypeName(topPrize, false)
      valueText = ::PrizesView.getPrizeText(topPrize, false)
    }
    if (battlePassItem != null) {
      name = ::loc("battlePass")
      isDisabled = hasBattlePass.value
    }

    return goodsConfig.__update({
      name = name
      valueText = valueText
      isDisabled = isDisabled
      cost = (battlePassItem?.getCost() ?? ::Cost())
        + (additionalTrophyItem?.getCost() ?? ::Cost())
    })
  }
}

::gui_handlers.BattlePassShopWnd <- BattlePassShopWnd

return {
  openBattlePassShopWnd = @() ::handlersManager.loadHandler(BattlePassShopWnd)
}
