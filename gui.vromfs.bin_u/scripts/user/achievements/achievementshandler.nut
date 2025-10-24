from "%scripts/dagui_natives.nut" import get_unlock_type
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isString } = require("%sqStdLibs/helpers/u.nut")
let { toggleUnlockFavButton, initUnlockFavInContainer } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { deferOnce, defer, setTimeout, clearTimer } = require("dagor.workcycle")
let { utf8ToLower } = require("%sqstd/string.nut")
let { initTree } = require("%scripts/user/skins/decoratorGroupsTree.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { isUnlockVisible, getUnlockCost, canOpenUnlockManually, findUnusableUnitForManualUnlock, canClaimUnlockRewardForUnit, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getUnlockTitle, getUnlockNameText, buildUnlockDesc, fillUnlockManualOpenButton, updateUnseenIcon, updateLockStatus,
  fillUnlockImage, fillUnlockProgressBar, fillUnlockDescription, doPreviewUnlockPrize, fillReward,
  fillUnlockTitle, fillUnlockPurchaseButton, buildConditionsConfig, fillUnlockConditions, fillUnlockStages } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getUnlockById, getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { isBattleTask } = require("%scripts/unlocks/battleTasks.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let { getUnlockIds } = require("%scripts/unlocks/unlockMarkers.nut")
let { getManualUnlocks } = require("%scripts/unlocks/personalUnlocks.nut")
let { makeConfig, makeConfigStrByList } = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { openUnlockManually, buyUnlock } = require("%scripts/unlocks/unlocksAction.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { openTrophyRewardsList } = require("%scripts/items/trophyRewardList.nut")
let openUnlockUnitListWnd = require("%scripts/unlocks/unlockUnitListWnd.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { getDaguiObjAabb } = require("%sqDagui/daguiUtil.nut")

const SELECTED_ACHIEVEMENT_SAVE_ID = "wnd/selectedAchievement"

let seenUnlockMarkers = seenList.get(SEEN.UNLOCK_MARKERS)

let unlockTypesToShow = [
  UNLOCKABLE_ACHIEVEMENT,
  UNLOCKABLE_CHALLENGE,
  UNLOCKABLE_TROPHY,
  UNLOCKABLE_TROPHY_PSN,
  UNLOCKABLE_TROPHY_XBOXONE,
  UNLOCKABLE_TROPHY_STEAM
]

function filterAchievementListFunc(achievement, nameFilter) {
  if (nameFilter != "") {
    let hasSubstring = (achievement.searchId.indexof(nameFilter) != null) ||
    achievement.searchName.indexof(nameFilter) != null
    if (!hasSubstring)
      return false
  }
  return true
}

let countedTypes = [
  "trophy_steam"
  "trophy_psn"
  "trophy_xboxone"
]

let countedChapters = [
  "challenges"
  "achievements"
]

local AchievementsHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType          = handlerType.CUSTOM
  sceneBlkName     = "%gui/profile/achievementsPage.blk"

  parent = null
  openParams = null
  treeHandlerWeak = null
  achievementsCache = null
  totalReceived = 0
  applyFilterTimer = null
  achievementsNameFilter = ""
  selectedCategory = ""
  selectedAchievement = ""
  needUpdateFlag = true

  gradientObj = null
  gradientTop = 0

  function initScreen() {
    this.gradientObj = this.scene.findObject("gradient")
    this.gradientTop = this.gradientObj.getPosRC()[1]

    this.prepareAchievements()
    this.updateTotalReceived()
    this.loadSelectedAchievement()
    this.applyOpenParams()
    this.createAchievementsTree()
  }

  function applyOpenParams() {
    if (this.openParams == null)
      return

    let { initCategory = "", initialUnlockId = "" } = this.openParams
    if (initCategory == "" && initialUnlockId == "")
      return

    if (initialUnlockId != "") {
      let unlockCategory = this.findGroupName(initialUnlockId)
      if (unlockCategory != "") {
        this.selectedCategory = unlockCategory
        this.selectedAchievement = initialUnlockId
      }
      return
    }

    this.selectedCategory = initCategory
    this.selectedAchievement = ""
  }

  function createAchievementsTree() {
    this.treeHandlerWeak = initTree({
      scene = this.scene.findObject("treeAchievementsNest")
      treeData = this.prepareAchievementsTreeData()
      selectCallback = Callback(@(id) this.onAchievementsCategorySelect(id), this)
      prevSelected = this.selectedCategory
      allowGroupSelection = true
    })
  }

  function isSuitable(unlock) {
    let unlockTypeId = get_unlock_type(unlock?.type ?? "")
    let isForceVisibleInTree = unlock?.isForceVisibleInTree ?? false
    if (!unlockTypesToShow.contains(unlockTypeId) && !isForceVisibleInTree)
      return false
    if (unlock?.isRevenueShare || !isUnlockVisible(unlock) || isBattleTask(unlock))
     return false

    let mode = unlock?.mode
    if(mode != null) {
      if((mode % "condition").findindex(@(v) v?.type == "battlepassSeason") != null)
        return false
      if((mode % "hostCondition").findindex(@(v) v?.type == "battlepassSeason") != null)
        return false
    }
    return true
  }

  function prepareAchievements() {
    if (this.achievementsCache != null)
      return
    this.achievementsCache = []
    this.totalReceived = 0
    let unlocks = getAllUnlocksWithBlkOrder()
    foreach (_idx, unlockBlk in unlocks) {
      if (!this.isSuitable(unlockBlk))
        continue

      this.achievementsCache.append({
        id = unlockBlk.id
        category = unlockBlk?.chapter ?? ""
        group = unlockBlk?.group ?? ""
        searchName = utf8ToLower(getUnlockTitle(buildConditionsConfig(unlockBlk)))
        searchId = utf8ToLower(unlockBlk.id)
      })

      if ((countedTypes.contains(unlockBlk.type) || countedChapters.contains(unlockBlk?.chapter)) && isUnlockOpened(unlockBlk.id))
        this.totalReceived++
    }
  }

  getAchievementsInCategory = @(category) this.achievementsCache.filter(@(v) v.category == category)
  getAchievementsInGroup = @(category, group) this.achievementsCache.filter(@(v) v.category == category && v.group == group)

  function prepareAchievementsTreeData() {
    let tree = {}

    foreach (achievement in this.achievementsCache) {
      let { category, group } = achievement
      if (category not in tree)
        tree[category] <- {}
      if (group not in tree[category] && group != "")
        tree[category][group] <- true
    }

    let treeData = []
    foreach (category, groups in tree) {
      let markerUnlockIds = getUnlockIds(getShopDiffCode())
      let manualUnlockIds = getManualUnlocks().map(@(unlock) unlock.id)

      let achievementsInCategory = this.getAchievementsInCategory(category).map(@(v) v.id)
      local markerSeenIds = markerUnlockIds.filter(@(id) achievementsInCategory.contains(id))
      local manualSeenIds = manualUnlockIds.filter(@(id) achievementsInCategory.contains(id) && canClaimUnlockRewardForUnit(id))

      let isNoGroups = groups.len() == 0
      treeData.append({
        id = category
        itemTag = "campaign_item"
        itemText = $"#unlocks/chapter/{category}"
        isCollapsable = !isNoGroups
        hidden = false
        isNoGroups
        unseenIcon = (markerSeenIds.len() == 0 && manualSeenIds.len() == 0) ? null : makeConfigStrByList([
          makeConfig(SEEN.UNLOCK_MARKERS, markerSeenIds),
          makeConfig(SEEN.MANUAL_UNLOCKS, manualSeenIds)
        ])
      })

      if (isNoGroups)
        continue

      foreach (group, _ in groups) {
        let achievementsInGroup = this.getAchievementsInGroup(category, group).map(@(v) v.id)
        markerSeenIds = markerUnlockIds.filter(@(id) achievementsInGroup.contains(id))
        manualSeenIds = manualUnlockIds.filter(@(id) achievementsInGroup.contains(id) && canClaimUnlockRewardForUnit(id))
        treeData.append({
          id = $"{category}/{group}"
          itemText = $"#unlocks/group/{group}"
          hidden = false
          unseenIcon = (markerSeenIds.len() == 0 && manualSeenIds.len() == 0) ? null : makeConfigStrByList([
            makeConfig(SEEN.UNLOCK_MARKERS, markerSeenIds),
            makeConfig(SEEN.MANUAL_UNLOCKS, manualSeenIds)
          ])
        })
      }
    }
    return treeData
  }

  function updateTotalReceived() {
    let totalReceivedObj = this.scene.findObject("total_received")
    totalReceivedObj.setValue(loc("profile/achievements/totalReceived", { count = this.totalReceived }))
  }

  function applyAchievementsFilter(obj) {
    clearTimer(this.applyFilterTimer)
    this.achievementsNameFilter = obj.getValue()
    if(this.achievementsNameFilter == "") {
      this.updateAchievementsTree()
      return
    }

    let applyCallback = Callback(@() this.updateAchievementsTree(), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else if (this.parent != null)
      this.guiScene.performDelayed(this.parent, this.parent.goBack)
  }

  function updateAchievementsTree() {
    let nameFilter = utf8ToLower(this.achievementsNameFilter)
    let filteredAchievements = this.achievementsCache.filter(@(achievement) filterAchievementListFunc(achievement, nameFilter))
    this.showContent(filteredAchievements.len() > 0)
    if (filteredAchievements.len() == 0)
      return

    let treeData = []

    foreach (achievement in filteredAchievements) {
      let { category, group } = achievement
      if (!treeData.contains(category))
        treeData.append(category)

      let groupId = $"{category}/{group}"
      if (!treeData.contains(groupId))
        treeData.append(groupId)
    }
    this.treeHandlerWeak?.update(treeData)
  }

  function onAchievementsCategorySelect(id) {
    let [category, group = ""] = id.split("/")
    let nameFilter = utf8ToLower(this.achievementsNameFilter)
    let filteredAchievements = this.getAchievementsInGroup(category, group)
      .filter(@(achievement) filterAchievementListFunc(achievement, nameFilter))
      .map(@(v) v.id)
    this.printAchievementsList(filteredAchievements)
    this.selectedCategory = id
    this.saveSelectedAchievement()
  }

  function printAchievementsList(list) {
    let achievementsCount = list.len()
    let unlocksListObj = showObjById("unlocks_list", true, this.scene)
    showObjById("item_desc", false, this.scene)
    local blockAmount = unlocksListObj.childrenCount()

    this.guiScene.setUpdatesEnabled(false, false)

    if (blockAmount < achievementsCount) {
      let unlockItemBlk = "%gui/profile/unlockItem.blk"
      for (; blockAmount < achievementsCount; blockAmount++)
        this.guiScene.createElementByObject(unlocksListObj, unlockItemBlk, "expandable", this)
    }
    else if (blockAmount > achievementsCount) {
      for (; blockAmount > achievementsCount; blockAmount--) {
        unlocksListObj.getChild(blockAmount - 1).show(false)
        unlocksListObj.getChild(blockAmount - 1).enable(false)
      }
    }
    this.guiScene.setUpdatesEnabled(true, true)

    if (unlocksListObj.childrenCount() > 0) {
      this.needUpdateFlag = false
      unlocksListObj.setValue(0) 
      this.needUpdateFlag = true
    }

    local selectedIdx = null
    for (local i = 0; i < list.len(); ++i) {
      let curUnlock = getUnlockById(list[i])
      let unlockObj = unlocksListObj.getChild(i)
      unlockObj.id = $"{curUnlock.id}_block"
      unlockObj.holderId = curUnlock.id
      if (selectedIdx == null && (this.selectedAchievement == curUnlock.id || canOpenUnlockManually(curUnlock))) {
        selectedIdx = i
        unlocksListObj.setValue(selectedIdx)
      }

      this.fillUnlockInfo(curUnlock, unlockObj)
    }

    this.updateGradientObj()

    seenUnlockMarkers.markSeen(getUnlockIds(getCurrentGameModeEdiff())
      .filter(@(unlock) list.contains(unlock)))
  }

  function updateGradientObj() {
    this.gradientObj.show(false)

    let unlocksListObj = this.scene.findObject("unlocks_list")

    let count = unlocksListObj.childrenCount()
    for (local i = 0; i < count; ++i) {
      let obj = unlocksListObj.getChild(i)
      let aabb = getDaguiObjAabb(obj)
      if (!aabb.visible)
        continue

      let bottom = aabb.pos[1] + aabb.size[1]
      if (bottom > this.gradientTop) {
        this.gradientObj.show(true)
        return
      }
    }
  }

  function fillUnlockInfo(unlockBlk, unlockObj) {
    let itemData = buildConditionsConfig(unlockBlk)
    buildUnlockDesc(itemData)
    unlockObj.show(true)
    unlockObj.enable(true)

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

  function onBuyUnlock(obj) {
    let unlockId = obj?.unlockId
    if (unlockId == null)
      return

    let cost = getUnlockCost(unlockId)

    let title = warningIfGold(
      loc("onlineShop/needMoneyQuestion", { purchase = colorize("unlockHeaderColor",
        getUnlockNameText(-1, unlockId)),
        cost = cost.getTextAccordingToBalance()
      }), cost)
    purchaseConfirmation("question_buy_unlock", title, @() buyUnlock(unlockId,
      Callback(@() this.updateUnlockBlock(unlockId), this),
      Callback(@() this.onAchievementsCategorySelect(this.selectedCategory), this)))
  }

  function updateUnlockBlock(unlockData) {
    local unlock = unlockData
    if (isString(unlockData))
      unlock = getUnlockById(unlockData)

    let unlockObj = this.scene.findObject($"{unlock.id}_block")
    if (checkObj(unlockObj))
      this.fillUnlockInfo(unlock, unlockObj)
  }

  function unlockToFavoritesByActivateItem(obj) {
    let childrenCount = obj.childrenCount()
    let index = obj.getValue()
    if (index < 0 || index >= childrenCount)
      return

    let checkBoxObj = obj.getChild(index).findObject("checkbox_favorites")
    if (!checkObj(checkBoxObj))
      return

    this.unlockToFavorites(checkBoxObj)
  }

  function unlockToFavorites(obj) {
    toggleUnlockFavButton(obj)
  }

  function onManualOpenUnlock(obj) {
    let unlockId = obj?.unlockId ?? ""
    if (unlockId == "")
      return

    let unit = findUnusableUnitForManualUnlock(unlockId)
    if (unit) {
      this.msgBox("cantClaimReward", loc("msgbox/cantClaimManualUnlockPrize",
        { unitname = getUnitName(unit) }), [["ok"]], "ok")
      return
    }

    let onSuccess = Callback(@() this.updateUnlockBlock(unlockId), this)
    openUnlockManually(unlockId, onSuccess)
  }

  function showUnlockPrizes(obj) {
    openTrophyRewardsList({ trophy = findItemById(obj.trophyId) })
  }

  function onPrizePreview(obj) {
    let unlockCfg = buildConditionsConfig(getUnlockById(obj.unlockId))
    deferOnce(@() doPreviewUnlockPrize(unlockCfg))
  }

  function showUnlockUnits(obj) {
    openUnlockUnitListWnd(obj.unlockId, Callback(@(unit) this.showUnitInShop(unit), this))
  }

  function showUnitInShop(unitName) {
    if (!unitName)
      return

    broadcastEvent("ShowUnitInShop", { unitName })
    let handler = this.parent
    defer(@() handler?.goBack())
  }

  function findGroupName(id) {
    let achievement = this.achievementsCache.findvalue(@(v) v.id == id)
    if (achievement == null)
      return ""
    if (achievement.group == "")
      return achievement.category
    return $"{achievement.category}/{achievement.group}"
  }

  function jumpToUnlock(unlockId) {
    let groupName = this.findGroupName(unlockId)
    if (groupName == "")
      return

    let list = this.treeHandlerWeak.getTreeObject()
    if (list == null)
      return
    let currentIndex = list.getValue()

    this.selectedCategory = groupName
    this.selectedAchievement = unlockId

    let count = list.childrenCount()
    for (local i = 0; i < count; i++) {
      let curObj = list.getChild(i)
      if (curObj.id != groupName)
        continue

      if (currentIndex != i)
        list.setValue(i)
      else
        this.onAchievementsCategorySelect(this.selectedCategory)
    }
    this.saveSelectedAchievement()
  }

  function onShowUnlockCondition(obj) {
    let unlockId = obj?.unlockId
    this.jumpToUnlock(unlockId)
  }

  function onAchievementSelect(obj) {
    if (!this.needUpdateFlag)
      return
    if (!obj?.isValid())
      return

    let currentIndex = obj.getValue()
    let item = obj.getChild(currentIndex)
    if (item.holderId != "") {
      this.selectedAchievement = item.holderId
      this.saveSelectedAchievement()
    }

    this.updateGradientObj()
  }

  function saveSelectedAchievement() {
    saveLocalAccountSettings(SELECTED_ACHIEVEMENT_SAVE_ID, {
      category = this.selectedCategory
      achievement = this.selectedAchievement
    })
  }

  function loadSelectedAchievement() {
    let blk = loadLocalAccountSettings(SELECTED_ACHIEVEMENT_SAVE_ID)
    if (blk == null)
      return

    this.selectedCategory = blk?.category
    this.selectedAchievement = blk?.achievement
  }

  function showContent(visible) {
    showObjById("content", visible, this.scene)
    showObjById("empty_text", !visible, this.scene)
  }

  function onEventUnlocksCacheInvalidate(_p) {
    if (!isProfileReceived.get())
      return
    this.initScreen()
  }

  function onEventRegionalUnlocksChanged(_params) {
    this.initScreen()
  }

  function onEventUnlockMarkersCacheInvalidate(_) {
    if (!isProfileReceived.get())
      return
    this.initScreen()
  }

  function onEventInventoryUpdate(_p) {
    this.initScreen()
  }
}

gui_handlers.AchievementsHandler <- AchievementsHandler

return {
  openAchievementsPage = @(params = {}) handlersManager.loadHandler(AchievementsHandler, params)
}
