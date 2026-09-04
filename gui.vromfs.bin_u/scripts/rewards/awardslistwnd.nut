from "dagor.workcycle" import deferOnce
from "%scripts/dagui_library.nut" import *
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%sqStdLibs/helpers/u.nut" import isString, isEmpty
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/unlocks/unlocksState.nut" import buildConditionsConfig, getUnlockNameText
from "%scripts/unlocks/unlocksViewModule.nut" import doPreviewUnlockPrize, fillUnlockProgressBar, fillUnlockDescription, fillUnlockImage, fillReward, fillUnlockTitle, fillUnlockPurchaseButton, fillUnlockManualOpenButton, updateLockStatus, updateUnseenIcon, buildUnlockDesc, fillUnlockConditions, fillUnlockStages
from "%scripts/unlocks/favoriteUnlocks.nut" import isUnlockFav, canAddFavorite, toggleUnlockFavButton, initUnlockFavInContainer
from "%scripts/unlocks/unlocksModule.nut" import getUnlockCost, findUnusableUnitForManualUnlock
from "%scripts/unlocks/unlocksAction.nut" import openUnlockManually, buyUnlock
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById
from "%scripts/purchase/purchaseConfirmationHandler.nut" import purchaseConfirmation
from "%scripts/items/trophyRewardList.nut" import openTrophyRewardsList
from "%scripts/viewUtils/objectTextUpdate.nut" import warningIfGold
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/unit/unitInfo.nut" import getUnitName

let openUnlockUnitListWnd = require("%scripts/unlocks/unlockUnitListWnd.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

class AwardsListWnd (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/rewards/awardsListWnd.blk"
  isPageFilling = false
  titleText = ""
  unlocksList = null

  function initScreen() {
    this.updateUnlocksList()
    this.scene.findObject("title_text").setValue(this.titleText)
  }

  getUnlockBlockId = @(unlockId) $"{unlockId}_block"

  function updateUnlocksList() {
    this.isPageFilling = true
    let unlocksList = this.unlocksList
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

    let text = warningIfGold(
      loc("onlineShop/needMoneyQuestion", { purchase = colorize("unlockHeaderColor",
        getUnlockNameText(-1, unlockId)),
        cost = cost.getTextAccordingToBalance()
      }), cost)
    let callbackYes = @() buyUnlock(unlockId,
      Callback(@() this.updateUnlockBlock(unlockId), this))
    purchaseConfirmation({ id = "question_buy_unlock", text, callbackYes }, cost)
  }

  function unlockToFavorites(obj) {
    if (toggleUnlockFavButton(obj))
      this.updateFavoritesCheckboxesInList()
  }

  function updateFavoritesCheckboxesInList() {
    if (this.isPageFilling)
      return

    let canAddFav = canAddFavorite()
    foreach (unlock in this.unlocksList) {
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
}

register_gui_handler("AwardsListWnd", AwardsListWnd)

function openAwardsListWnd(titleText, unlocksList) {
  handlersManager.loadHandler(AwardsListWnd, { titleText, unlocksList })
}

return {
  openAwardsListWnd
}
