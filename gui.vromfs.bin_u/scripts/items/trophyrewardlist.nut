from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let itemInfoHandler = require("%scripts/items/itemInfoHandler.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { register_command } = require("console")
let { convertBlk } = require("%sqstd/datablock.nut")
let { getTrophyRewardType, isRewardItem } = require("%scripts/items/trophyReward.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { getPrizeFullDescriptonView, getPrizesStacksView, prizesStackLevel } = require("%scripts/items/prizesView.nut")
let { isDataBlock } = require("%sqStdLibs/helpers/u.nut")

gui_handlers.trophyRewardsList <- class (gui_handlers.BaseGuiHandlerWT) {
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

    let reward_config = this.rewardsArray[val]
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

function openTrophyRewardsList(params = {}) {
  let rewardsArray = params?.rewardsArray
  if (!params?.trophy && (!rewardsArray || !rewardsArray.len()))
    return

  handlersManager.loadHandler(gui_handlers.trophyRewardsList, params)
}

function debug_trophy_rewards_list(id = "shop_test_multiple_types_reward") {
  let trophy = findItemById(id)
  openTrophyRewardsList({ trophy })
}

register_command(debug_trophy_rewards_list, "debug.trophy_rewards_list")

return {
  openTrophyRewardsList
}