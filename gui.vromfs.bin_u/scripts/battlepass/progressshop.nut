from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { FRP_INITIAL } = require("frp")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child, move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let { maxSeasonLvl, battlePassShopConfig, season } = require("%scripts/battlePass/seasonState.nut")
let { hasBattlePass } = require("%scripts/battlePass/unlocksRewardsState.nut")
let { refreshUserstatUnlocks, isUserstatMissingData
} = require("%scripts/userstat/userstat.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let seenBattlePassShop = require("%scripts/seen/seenList.nut").get(SEEN.BATTLE_PASS_SHOP)
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { itemsShopListVersion, inventoryListVersion } = require("%scripts/items/itemsManager.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getUnlockCost, buyUnlock, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")

const SEEN_OUT_OF_DATE_DAYS = 30

let getSortedAdditionalTrophyItems = @(additionalTrophy) additionalTrophy
  .map(@(itemId) ::ItemsManager.findItemById(to_integer_safe(itemId, itemId, false)))
  .sort(@(a, b) (a?.getCost() ?? 0) <=> (b?.getCost() ?? 0))

let getAdditionalTrophyItemForBuy = @(additionalTrophyItems) (additionalTrophyItems
  .filter(@(item) item?.isCanBuy() && item?.canBuyTrophyByLimit()))?[0]

let canExchangeItem = @(passExchangeItem) (passExchangeItem?.canReceivePrize() ?? false)
  && (passExchangeItem?.hasUsableRecipeOrNotRecipes() ?? false)

let findExchangeItem = @(battlePassUnlockExchangeId) ::ItemsManager.findItemById(
  to_integer_safe(battlePassUnlockExchangeId ?? -1, battlePassUnlockExchangeId ?? -1, false))

//do not update anything in battle or profile not recived, as it can be time consuming and not needed in battle anyway
let canUpdateConfig = Computed(@() isProfileReceived.value && !isInBattleState.value)

let seasonShopConfig = Computed(function(prev) {
  if (prev != FRP_INITIAL && !canUpdateConfig.value)
    return prev
  else if (prev == FRP_INITIAL && !canUpdateConfig.value)
    return {}

  let checkItemsShopListVersion = itemsShopListVersion.value // -declared-never-used
  let checkInventoryListVersion = inventoryListVersion.value // -declared-never-used
  return {
    purchaseWndItems = battlePassShopConfig.value ?? []
    seasonId = season.value
  }
})

let seenBattlePassShopRows = Computed(@() (seasonShopConfig.value?.purchaseWndItems ?? [])
  .map(function(config) {
    let { battlePassUnlock = "", additionalTrophy = [], battlePassUnlockExchangeId = null } = config
    if (battlePassUnlockExchangeId != null && (hasBattlePass.value || !canExchangeItem(findExchangeItem(battlePassUnlockExchangeId))))
      return ""

    let additionalTrophyItems = getSortedAdditionalTrophyItems(additionalTrophy)
    if (battlePassUnlock != "" || battlePassUnlockExchangeId != null)
      return hasBattlePass.value ? ""
        : $"{battlePassUnlockExchangeId ?? battlePassUnlock}_{additionalTrophyItems?[0].id ?? ""}"

    return $"{getAdditionalTrophyItemForBuy(additionalTrophyItems)?.id ?? ""}"
  })
  .filter(@(name) name != "")
)

let markRowsSeen = @() seenBattlePassShop.markSeen(seenBattlePassShopRows.value)

let function onSeenBpShopChanged() {
  seenBattlePassShop.setDaysToUnseen(SEEN_OUT_OF_DATE_DAYS)
  seenBattlePassShop.onListChanged()
}

seenBattlePassShopRows.subscribe(@(_p) onSeenBpShopChanged())

addListenersWithoutEnv({
  ProfileUpdated   = @(_p) onSeenBpShopChanged()
}, ::g_listener_priority.CONFIG_VALIDATION)

seenBattlePassShop.setListGetter(@() seenBattlePassShopRows.value)

local BattlePassShopWnd = class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"

  goods = null

  hasBuyImprovedBattlePass = false

  function initScreen() {
    if ((seasonShopConfig.value?.purchaseWndItems ?? []).len() == 0)
      return this.goBack()

    this.updateWindow()
  }

  function updateWindow() {
    this.scene.findObject("wnd_title").setValue(loc("battlePass"))
    let rootObj = this.scene.findObject("wnd_frame")
    rootObj["class"] = "wnd"
    rootObj.width = "@onlineShopWidth + 2@blockInterval"
    rootObj.padByLine = "yes"
    let contentObj = rootObj.findObject("wnd_content")
    contentObj.flow = "vertical"

    rootObj.setValue(stashBhvValueConfig([{
      watch = seasonShopConfig
      updateFunc = Callback(@(_obj, shopConfig) this.updateContent(shopConfig), this)
    }]))
  }

  function updateContent(shopConfig) {
    this.goods = []
    foreach (idx, config in shopConfig.purchaseWndItems) {
      let { battlePassUnlock = "", additionalTrophy = [], battlePassUnlockExchangeId = null } = config
      let passExchangeItem = findExchangeItem(battlePassUnlockExchangeId)
      if (battlePassUnlockExchangeId != null && (hasBattlePass.value || !canExchangeItem(passExchangeItem)))
        continue

      let passUnlock = getUnlockById(battlePassUnlock)
      let goodsConfig = this.getGoodsConfig({
        additionalTrophyItems = getSortedAdditionalTrophyItems(additionalTrophy)
        battlePassUnlock = passUnlock
        hasBattlePassUnlock = battlePassUnlock != "" || passExchangeItem != null
        passExchangeItem
        rowIdx = idx
        seasonId = shopConfig.seasonId
      })

      this.goods.append(goodsConfig)
    }

    this.updateRowsView()
  }

  function actualizeGoodsConfig() {
    this.goods = this.goods.map((@(g) this.getGoodsConfig(g)).bindenv(this))
  }

  function updateRowsView() {
    let hasBuyImprovedPass = this.hasBuyImprovedBattlePass
    let rowsView = this.goods
      .filter(@(g) g.passExchangeItem?.hasUsableRecipeOrNotRecipes()
        || (!g.cost.isZero() && (!g.hasBattlePassUnlock || g.battlePassUnlock != null)))
      .map(function(g, idx) {
        let isRealyBought = g.isBought && (!hasBuyImprovedPass || g.isImprovedBattlePass)
        return {
          rowName = g.rowIdx
          rowEven = (idx % 2 == 0) ? "yes" : "no"
          amount = $"{g.name} {g.valueText}"
          cost = g.passExchangeItem != null ? null : $"{isRealyBought ? loc("check_mark/green") : ""} {g.cost.tostring()}"
          isDisabled = g.isDisabled
          unseenIcon = g.unseenIcon
          customCostMarkup = g.passExchangeItem?.getDescRecipesMarkup({
            maxRecipes = 1
            needShowItemName = false
            needShowHeader = false
            showCurQuantities = false
            hasHorizontalFlow = true
          })
        }
      })
    this.guiScene.setUpdatesEnabled(false, false)

    let contentObj = this.scene.findObject("wnd_content")
    let data = handyman.renderCached(("%gui/onlineShop/onlineShopWithVisualRow.tpl"), {
      chImages = "#ui/onlineShop/battle_pass_header.ddsx"
      descText = loc("battlePass/buy/desc", { count = maxSeasonLvl.value })
      rows = rowsView
    })
    this.guiScene.replaceContentFromText(contentObj, data, data.len(), this)
    this.guiScene.setUpdatesEnabled(true, true)

    let valueToSelect = rowsView.findindex(@(r) !r.isDisabled) ?? -1
    let tblObj = this.scene.findObject("items_list")
    this.guiScene.performDelayed(this, @() move_mouse_on_child(tblObj, valueToSelect))
  }

  hasOpenedPassUnlock = @(goodsConfig) (goodsConfig.passExchangeItem != null && !canExchangeItem(goodsConfig.passExchangeItem))
    || (goodsConfig.battlePassUnlock?.id != null && isUnlockOpened(goodsConfig.battlePassUnlock.id))

  isGoodsBought = @(goodsConfig) goodsConfig.hasBattlePassUnlock
    && (hasBattlePass.value || this.hasOpenedPassUnlock(goodsConfig))

  function buyGood(goodsConfig) {
    let { additionalTrophyItem, battlePassUnlock, rowIdx } = goodsConfig
    log($"Buy Battle Pass goods. goodsIdx: {rowIdx}")

    let function tryBuyAdditionalTrophy() {
      if (additionalTrophyItem == null)
        return
      let cost = additionalTrophyItem.getCost()
      additionalTrophyItem._buy(@(_res) null, { cost = cost.wp, costGold = cost.gold })
    }

    if (battlePassUnlock != null)
      buyUnlock(battlePassUnlock, function() {
        tryBuyAdditionalTrophy()
        refreshUserstatUnlocks()
        broadcastEvent("BattlePassPurchased")
      })
    else
      tryBuyAdditionalTrophy()
    markRowsSeen()
  }

  function disableBattlePassRows() { //disable battle pass buy button
    let listObj = this.scene.findObject("items_list")
    if (!listObj?.isValid())
      return
    foreach (idx, goodsConfig in this.goods) {
      let obj = listObj.findObject(idx.tostring())
      if (obj?.isValid())
        obj.enable = goodsConfig.hasBattlePassUnlock ? "no" : "yes"
    }
  }

  function onBuy(curGoodsIdx) {
    let goodsConfig = this.goods?[curGoodsIdx]
    if (goodsConfig == null || this.isGoodsBought(goodsConfig))
      return

    let { passExchangeItem } = goodsConfig
    if (passExchangeItem != null) {
      log($"Exchange items to battle Pass goods. goodsIdx: {goodsConfig.rowIdx}")
      passExchangeItem.assemble()
      return
    }

    let msgText = warningIfGold(
      loc("onlineShop/needMoneyQuestion", {
          purchase = $"{goodsConfig.name} {goodsConfig.valueText}",
          cost = goodsConfig.cost.getTextAccordingToBalance() }),
      goodsConfig.cost)
    let callbackYes = Callback(function() {
      if (::check_balance_msgBox(goodsConfig.cost)) {
        this.buyGood(goodsConfig)
        if (goodsConfig.hasBattlePassUnlock)
          this.disableBattlePassRows()
      }
    }, this)
    let onCancel = Callback(@() move_mouse_on_child(this.scene.findObject("items_list"), curGoodsIdx), this)
    purchaseConfirmation("purchase_ask", msgText, callbackYes, onCancel)
  }

  function onRowBuy(_obj) {
    let value = this.scene.findObject("items_list").getValue()
    if (value in this.goods)
      this.onBuy(value)
  }

  function onEventModalWndDestroy(params) {
    base.onEventModalWndDestroy(params)
    if (this.isSceneActiveNoModals())
      move_mouse_on_child_by_value(this.getObj("items_list"))
  }

  function getGoodsConfig(goodsConfig) {
    local name = ""
    local valueText = ""
    local isBought = false
    local isDisabled = false
    local cost = Cost()
    let { additionalTrophyItems, battlePassUnlock, passExchangeItem, seasonId } = goodsConfig
    local additionalTrophyItem = getAdditionalTrophyItemForBuy(additionalTrophyItems)
    local seenRowName = $"{additionalTrophyItem?.id ?? ""}"
    let isBattlePassConfig = battlePassUnlock != null || passExchangeItem != null
    if (isBattlePassConfig)
      additionalTrophyItem = additionalTrophyItem ?? additionalTrophyItems?[0]
    let hasAdditionalTrophyItem = additionalTrophyItem != null
    if (hasAdditionalTrophyItem) {
      let topPrize = additionalTrophyItem.getTopPrize()
      name = ::PrizesView.getPrizeTypeName(topPrize, false)
      valueText = loc("ui/parentheses", { text = ::PrizesView.getPrizeText(topPrize, false) })
      cost = cost + additionalTrophyItem.getCost()
    }
    let isImprovedBattlePass = isBattlePassConfig && hasAdditionalTrophyItem
    if (isBattlePassConfig) {
      let prizeLocId = isImprovedBattlePass ? "battlePass/improvedBattlePassName" : "battlePass/name"
      name = loc(prizeLocId, { name = loc($"battlePass/seasonName/{seasonId}") })
      isBought = this.isGoodsBought(goodsConfig)
      isDisabled = isBought
      if (hasAdditionalTrophyItem)
        isBought = isBought && !additionalTrophyItem.canBuyTrophyByLimit() //trophy of improved battle pass is already buy
      if (battlePassUnlock != null)
        cost = cost + getUnlockCost(battlePassUnlock.id)
      seenRowName = $"{passExchangeItem?.id ?? battlePassUnlock?.id ?? ""}_{additionalTrophyItems?[0].id ?? ""}"
    }
    if (isImprovedBattlePass)
      this.hasBuyImprovedBattlePass = isBought

    return goodsConfig.__merge({
      name
      valueText
      isBought
      cost
      additionalTrophyItem
      isImprovedBattlePass
      isDisabled
      unseenIcon = isDisabled ? null
        :  bhvUnseen.makeConfigStr(SEEN.BATTLE_PASS_SHOP, seenRowName)
    })
  }

  function onEventProfileUpdated(_p) {
    this.actualizeGoodsConfig()
    this.updateRowsView()
  }

  onDestroy = @() markRowsSeen()
}

gui_handlers.BattlePassShopWnd <- BattlePassShopWnd

let function openBattlePassShopWnd() {
  if (isUserstatMissingData.value) {
    showInfoMsgBox(loc("userstat/missingDataMsg"), "userstat_missing_data_msgbox")
    return
  }

  handlersManager.loadHandler(BattlePassShopWnd)
}


globalCallbacks.addTypes({
  openBattlePassShopWnd = {
    onCb = @(_obj, _params) openBattlePassShopWnd()
  }
})

return {
  openBattlePassShopWnd
}
