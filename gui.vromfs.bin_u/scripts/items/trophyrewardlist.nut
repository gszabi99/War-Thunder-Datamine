import "%scripts/items/itemInfoHandler.nut" as itemInfoHandler
import "%scripts/items/listPopupWnd/trophyRewardListByCategory.nut" as trophyRewardListByCategory
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child_by_value
from "%scripts/items/trophyReward.nut" import getTrophyRewardType, isRewardItem
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/items/itemsManager.nut" import getItemOrRecipeBundleById
from "%scripts/items/prizesView.nut" import getPrizeFullDescriptonView, getPrizesStacksView, prizesStackLevel
from "%sqStdLibs/helpers/u.nut" import isDataBlock
from "console" import register_command
from "%sqstd/datablock.nut" import convertBlk
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let trophyRewardsList = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/items/trophyRewardsList.tpl"
  sceneBlkName = null
  rewardsArray = []
  titleLocId = "mainmenu/rewardsList"
  trophy = null
  infoHandler = null
  childNumToReward = null

  function initScreen() {
    let listObj = this.scene.findObject("items_list")
    if (!checkObj(listObj))
      return this.goBack()

    this.infoHandler = itemInfoHandler(this.scene.findObject("item_info"))

    let titleObj = this.scene.findObject("title")
    if (checkObj(titleObj))
      titleObj.setValue(loc(this.titleLocId))

    this.fillList(listObj)
    let firstRewardIndex = this.getNextRewardListIndex(0)
    if (firstRewardIndex >= 0)
      listObj.setValue(firstRewardIndex)
    move_mouse_on_child_by_value(listObj)
  }

  function getSceneTplView() {
    return {
      hasProbabilityInfo = this.trophy?.needProbabilityInfoBtn() ?? false
      listWidth = this.trophy?.needShowTextChances() ? "450@sf/@pf" : "400@sf/@pf"
    }
  }

  function fillList(listObj) {
    if (this.trophy) {
      this.updateTrophyItemsList(listObj)
      return
    }
    let data = this.getRewardsListView()
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    this.updateListIndexTable(listObj)
  }

  function updateTrophyItemsList(listObj) {
    let isPreferMarkup = this.trophy.isPreferMarkupDescInTooltip
    this.rewardsArray = []
    let prizesList = this.trophy.getContent()
    let mainPrizes = prizesList.filter(@(prize) !prize?.availableIfAllPrizesReceived)
    let additionalPrizes = prizesList.filter(@(prize) !!prize?.availableIfAllPrizesReceived)

    foreach (prize in mainPrizes)
      this.rewardsArray.append(isDataBlock(prize) ? convertBlk(prize) : {})
    foreach (prize in additionalPrizes)
      this.rewardsArray.append(isDataBlock(prize) ? convertBlk(prize) : {})

    let longDescMarkup = (isPreferMarkup && this.trophy?.getLongDescriptionMarkup)
      ? this.trophy.getLongDescriptionMarkup({
          shopDesc = !(this.trophy?.showDescInRewardWndOnly() ?? false)
          stackLevel = prizesStackLevel.NOT_STACKED
          showTooltip = false
        })
      : ""
    listObj.getScene().replaceContentFromText(listObj, longDescMarkup, longDescMarkup.len(), this)
    this.updateListIndexTable(listObj)
  }

  function getRewardsListView() {
    return getPrizesStacksView(this.rewardsArray, @(_a) "", { receivedPrizes = false, showTooltip = false })
  }

  function updateItemInfo(obj) {
    let val = this.getRewardByChildIndex(obj.getValue())
    if (val < 0)
      return

    let reward_config = clone this.rewardsArray[val]
    let rewardType = getTrophyRewardType(reward_config)
    let isItem = isRewardItem(rewardType)
    this.infoHandler?.setHandlerVisible(isItem)
    let prizeInfo = showObjById("prize_info", !isItem, this.scene)
    if (isItem) {
      if (!this.infoHandler)
        return

      let item = findItemById(reward_config[rewardType])
      this.infoHandler.updateHandlerData(item, true, true, reward_config)
      return
    }

    if (rewardType == "resource" || rewardType == "resourceType")
      reward_config.sizeParams <- { w = "0.6@chestRewardWidth" }
    let trophyDesc = getPrizeFullDescriptonView(reward_config)
    this.guiScene.replaceContentFromText(prizeInfo, trophyDesc, trophyDesc.len(), this)
  }

  function updateListIndexTable(listObj) {
    this.childNumToReward = []
    let len = listObj.childrenCount()
    local rewardNum = -1
    for (local i = 0; i < len; i++) {
      let child = listObj.getChild(i)
      if (child?.text != null) {
        this.childNumToReward.append(-1)
        continue
      }
      rewardNum++
      this.childNumToReward.append(rewardNum)
    }
  }

  function getNextRewardListIndex(index) {
    while (index < this.childNumToReward.len()) {
      if (this.childNumToReward[index] != -1)
        return index
      index++
    }
    return -1
  }

  function getRewardByChildIndex(index) {
    while (index < this.childNumToReward.len()) {
      if (this.childNumToReward[index] != -1)
        return this.childNumToReward[index]
      index++
    }
    return -1
  }

  function onEventItemsShopUpdate(_p) {
    let listObj = this.scene.findObject("items_list")
    if (!checkObj(listObj))
      return
    this.fillList(listObj)
    if (listObj.childrenCount() > 0 && listObj.getValue() < 0)
      listObj.setValue(0)
    move_mouse_on_child_by_value(listObj)
  }

  function onProbabilityInfoBtn(_obj) {
    this.trophy?.openProbabilityInfo()
  }
}
register_gui_handler("trophyRewardsList", trophyRewardsList)

function openTrophyRewardsList(params = {}) {
  let rewardsArray = params?.rewardsArray
  if (!params?.trophy && (!rewardsArray || !rewardsArray.len()))
    return

  handlersManager.loadHandler(trophyRewardsList, params)
}

function openUnlockPrizesList(trophyId) {
  let trophy = getItemOrRecipeBundleById(to_integer_safe(trophyId, trophyId, false))
  let iType = trophy?.iType ?? 0
  let isChest = iType == itemType.CHEST || iType == itemType.RECIPES_BUNDLE
  if (isChest && trophy.getDropChanceType() != CHANCE_VIEW_TYPE.NONE)
    trophyRewardListByCategory({ chestItem = trophy })
  else
    openTrophyRewardsList({ trophy })
}

function debug_trophy_rewards_list(id = "shop_test_multiple_types_reward") {
  let trophy = findItemById(id)
  openTrophyRewardsList({ trophy })
}

register_command(debug_trophy_rewards_list, "debug.trophy_rewards_list")

return freeze({
  openTrophyRewardsList
  openUnlockPrizesList
})