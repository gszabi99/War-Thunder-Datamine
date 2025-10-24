from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isString, isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES } = require("%scripts/options/optionsExtNames.nut")
let { set_option, create_options_container } = require("%scripts/options/optionsExt.nut")
let { calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { getNightBattlesUnlocks } = require("%scripts/unlocks/personalUnlocks.nut")
let { getUnlockNameText, doPreviewUnlockPrize, fillUnlockProgressBar, fillUnlockDescription,
  fillUnlockImage, fillReward, fillUnlockTitle, fillUnlockPurchaseButton, fillUnlockManualOpenButton,
  updateLockStatus, updateUnseenIcon, buildUnlockDesc, buildConditionsConfig, fillUnlockConditions,
  fillUnlockStages } = require("%scripts/unlocks/unlocksViewModule.nut")
let openUnlockUnitListWnd = require("%scripts/unlocks/unlockUnitListWnd.nut")
let { isUnlockFav, canAddFavorite, toggleUnlockFavButton, initUnlockFavInContainer } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { getUnlockCost, findUnusableUnitForManualUnlock } = require("%scripts/unlocks/unlocksModule.nut")
let { openUnlockManually, buyUnlock } = require("%scripts/unlocks/unlocksAction.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { deferOnce } = require("dagor.workcycle")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { openTrophyRewardsList } = require("%scripts/items/trophyRewardList.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { hasNightGameModes } = require("%scripts/events/eventInfo.nut")
let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")
let { markSeenNightBattle } = require("%scripts/events/nightBattlesStates.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { getCurrentGameMode, getGameModeById
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

const MIN_MRANK_FOR_NIGHT_BATTLES = 27

let optionItems = [[USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES, "switchbox"]]

let class NightBattlesOptionsWnd (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/events/gameModeOptionsWnd.tpl"
  wndOptionsMode = OPTIONS_MODE_GAMEPLAY

  curEvent = null
  optionsContainer = null
  isPageFilling = false
  callbackOnClose = null

  function getSceneTplView() {
    let container = create_options_container("optionslist", optionItems,
      true, 0.5, false, { containerCb = "onChangeOptionValue" })
    this.optionsContainer = container.descr
    return {
      titleText = loc("ui/colon").concat(events.getEventNameText(this.curEvent), loc("night_battles"))
      descText = loc("night_battles/desc", {
        optionName = loc("options/can_queue_to_night_battles")
        minMRankForNightBattles = format("%.1f",
          calcBattleRatingFromRank(this.curEvent?.minMRankForNightBattles ?? MIN_MRANK_FOR_NIGHT_BATTLES))
      })
      optionsContainer = container.tbl
      hasUnlocksList = true
    }
  }

  function initScreen() {
    this.updateUnlocksList()
    this.scene.findObject("optionslist").setMouseCursorOnObject()
    markSeenNightBattle()
  }

  function getOptionById(id) {
    foreach (option in this.optionsContainer.data)
      if (option?.id == id)
        return option
    return null
  }

  function onChangeOptionValue(obj) {
    let option = this.getOptionById(obj?.id)
    if (!option)
      return

    set_option(option.type, obj.getValue(), option)
  }

  getUnlockBlockId = @(unlockId) $"{unlockId}_block"

  function updateUnlocksList() {
    this.isPageFilling = true
    let unlocksList = getNightBattlesUnlocks()
    let unlocksCount = unlocksList.len()
    let unlocksListObj =  this.scene.findObject("unlocks_list")
    let blockCount = unlocksListObj.childrenCount()

    this.guiScene.setUpdatesEnabled(false, false)

    if (blockCount < unlocksCount)
      this.guiScene.createMultiElementsByObject(unlocksListObj, "%gui/profile/unlockItem.blk",
        "expandable", unlocksCount - blockCount, this)

    let lastIdx = unlocksListObj.childrenCount() - 1
    for (local uIdx = 0; uIdx <= lastIdx; uIdx++) {
      let unlockObj = unlocksListObj.getChild(uIdx)
      let unlock = unlocksList?[uIdx]
      let hasUnlock = unlock != null
      unlockObj.show(hasUnlock)
      unlockObj.enable(hasUnlock)
      if (!hasUnlock)
        continue

      let unlockId = unlock?.id ?? ""
      unlockObj.id = this.getUnlockBlockId(unlockId)
      unlockObj.holderId = unlockId
      this.fillUnlockInfo(unlock, unlockObj)
    }

    this.guiScene.setUpdatesEnabled(true, true)

    if (unlocksList.len() > 0)
      unlocksListObj.setValue(0)
    this.isPageFilling = false
  }

  function fillUnlockInfo(unlockBlk, unlockObj) {
    let itemData = buildConditionsConfig(unlockBlk)
    buildUnlockDesc (itemData)
    fillUnlockConditions(itemData, unlockObj, this)
    fillUnlockProgressBar(itemData, unlockObj)
    fillUnlockDescription(itemData, unlockObj)
    fillUnlockImage(itemData, unlockObj)
    fillReward(itemData, unlockObj)
    fillUnlockStages(itemData, unlockObj, this)
    fillUnlockTitle(itemData, unlockObj)
    initUnlockFavInContainer(itemData.id, unlockObj)
    fillUnlockPurchaseButton(itemData, unlockObj)
    fillUnlockManualOpenButton(itemData, unlockObj)
    updateLockStatus(itemData, unlockObj)
    updateUnseenIcon(itemData, unlockObj)
  }

  function updateUnlockBlock(unlockData) {
    local unlock = unlockData
    if (isString(unlockData))
      unlock = getUnlockById(unlockData)

    let unlockObj = this.scene.findObject(this.getUnlockBlockId(unlock.id))
    if (unlockObj?.isValid() ?? false)
      this.fillUnlockInfo(unlock, unlockObj)
  }

  function onPrizePreview(obj) {
    this.previewUnlockId = obj.unlockId
    let unlockCfg = buildConditionsConfig(getUnlockById(obj.unlockId))
    deferOnce(@() doPreviewUnlockPrize(unlockCfg))
  }

  function showUnlockPrizes(obj) {
    let trophy = findItemById(obj.trophyId)
    openTrophyRewardsList({ trophy })
  }

  function showUnlockUnits(obj) {
    openUnlockUnitListWnd(obj.unlockId, Callback(@(unit) this.showUnitInShop(unit), this))
  }

  function showUnitInShop(unitName) {
    if (!unitName)
      return

    broadcastEvent("ShowUnitInShop", { unitName })
    this.goBack()
  }

  function onManualOpenUnlock(obj) {
    let unlockId = obj?.unlockId ?? ""
    if (unlockId == "")
      return

    let unit = findUnusableUnitForManualUnlock(unlockId)
    if (unit) {
      this.msgBox("cantClaimReward", loc("msgbox/cantClaimManualUnlockPrize",
        { unitname = getUnitName(unit)}), [["ok"]], "ok")
      return
    }

    let onSuccess = Callback(@() this.updateUnlockBlock(unlockId), this)
    openUnlockManually(unlockId, onSuccess)
  }

  function onBuyUnlock(obj) {
    let unlockId = obj?.unlockId
    if (isEmpty(unlockId))
      return

    let cost = getUnlockCost(unlockId)

    let title = warningIfGold(
      loc("onlineShop/needMoneyQuestion", { purchase = colorize("unlockHeaderColor",
        getUnlockNameText(-1, unlockId)),
        cost = cost.getTextAccordingToBalance()
      }), cost)
    purchaseConfirmation("question_buy_unlock", title, @() buyUnlock(unlockId,
      Callback(@() this.updateUnlockBlock(unlockId), this)))
  }

  function unlockToFavorites(obj) {
    if (toggleUnlockFavButton(obj))
      this.updateFavoritesCheckboxesInList()
  }

  function updateFavoritesCheckboxesInList() {
    if (this.isPageFilling)
      return

    let canAddFav = canAddFavorite()
    foreach (unlock in getNightBattlesUnlocks()) {
      let unlockId = unlock.id
      let unlockObj = this.scene.findObject(this.getUnlockBlockId(unlockId))
      if (!(unlockObj?.isValid() ?? false))
        continue

      let cbObj = unlockObj.findObject("checkbox_favorites")
      if (cbObj?.isValid() ?? false)
        cbObj.inactiveColor = (canAddFav || isUnlockFav(unlockId)) ? "no" : "yes"
    }
  }

  function unlockToFavoritesByActivateItem(obj) {
    let childrenCount = obj.childrenCount()
    let index = obj.getValue()
    if (index < 0 || index >= childrenCount)
      return

    let checkBoxObj = obj.getChild(index).findObject("checkbox_favorites")
    if (!checkBoxObj?.isValid())
      return

    this.unlockToFavorites(checkBoxObj)
  }

  function goBack() {
    if (this.callbackOnClose)
      this.callbackOnClose()
    base.goBack()
  }
}

gui_handlers.NightBattlesOptionsWnd <- NightBattlesOptionsWnd

function openNightBattles(modeId = null, params = null) {
  let { callbackOnClose = null } = params
  let curEvent = modeId != null
    ? getGameModeById(modeId)?.getEvent()
    : getCurrentGameMode()?.getEvent()
  if (hasNightGameModes(curEvent))
    checkSquadUnreadyAndDo(@() handlersManager.loadHandler(NightBattlesOptionsWnd, { curEvent, callbackOnClose }))
}

return openNightBattles
