import "%scripts/unlocks/unlockGroupWnd.nut" as showUnlocksGroupWnd
import "%scripts/utils/getNavigationImagesText.nut" as getNavigationImagesText
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/viewUtils/layeredIcon.nut" import LayersIcon
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import getSelectedChild, move_mouse_on_obj
from "%scripts/battlePass/challenges.nut" import updateChallenges, curSeasonChallenges, getChallengeView
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById
from "%scripts/unlocks/favoriteUnlocks.nut" import getFavoriteUnlocks
from "%scripts/unlocks/unlocksModule.nut" import getUnlockType
from "%scripts/unlocks/unlocksState.nut" import getUnlockMainCondDescByCfg, getUnlockMultDescByCfg, getUnlockDesc, getUnlockCondsDescByCfg, buildConditionsConfig
from "%scripts/unlocks/unlocksViewModule.nut" import getUnlockTitle, getUnlockSnapshotText, needShowLockIcon, getUnlockImageConfig, getRewardCfgByUnlockCfg, getSubunlocksView, getUnlockStagesView
from "%scripts/unlocks/battleTasksState.nut" import isBattleTask, getBattleTaskById
from "%scripts/unlocks/battleTasks.nut" import isBattleTasksAvailable, isBattleTaskDone, getCurBattleTasksByGm
from "%scripts/unlocks/battleTasksView.nut" import mkUnlockConfigByBattleTask, getBattleTaskView
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import getRoomEvent
from "%scripts/unlocks/unlocks.nut" import buildLogUnlockData
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%globalScripts/unlockConsts.nut" import *
from "%globalScripts/loc_helpers.nut" import locByVendor, getVendorLocId
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")


const NUM_SUBUNLOCK_COLUMNS = 3

function getBattleTasksView() {
  let view = { items = [] }
  let gmName = getRoomEvent()?.name
  if (gmName == null)
    return view

  foreach (task in getCurBattleTasksByGm(gmName)) {
    let cfg = mkUnlockConfigByBattleTask(task)
    let item = getBattleTaskView(cfg, { isInteractive = false })
    item.isSelected <- !isBattleTaskDone(task)
    view.items.append(item)
  }
  return view
}

local isBpTasksUpdated = false
function updateBpTasksOnce() {
  if (!isBpTasksUpdated) {
    updateChallenges()
    isBpTasksUpdated = true
  }
}
addListenersWithoutEnv({
  BattlePassCacheInvalidate = @(_) isBpTasksUpdated = false
})

function getBattlePassTasksView() {
  updateBpTasksOnce()
  let items = curSeasonChallenges.get()
    .map(@(blk) getChallengeView(blk, { isInteractive = false }))
  return { items }
}

function getFavUnlockIcon(unlockId) {
  let unlockType = getUnlockType(unlockId)
  return unlockType == UNLOCKABLE_SKIN ? "#ui/gameuiskin#unlock_skin"
    : unlockType == UNLOCKABLE_DECAL ? "#ui/gameuiskin#unlock_decal"
    : unlockType == UNLOCKABLE_ATTACHABLE ? "#ui/gameuiskin#unlock_attachable"
    : "#ui/gameuiskin#unlock_achievement"
}

function getFavUnlocksView() {
  let view = { items = [] }
  let unlockListBlk = getFavoriteUnlocks()
  for (local i = 0; i < unlockListBlk.blockCount(); ++i) {
    let blk = unlockListBlk.getBlock(i)
    let cfg = buildConditionsConfig(blk)
    let progressData = cfg.getProgressBarData()
    let mainCondition = getUnlockMainCondDescByCfg(cfg)
    let hasProgressBar = progressData.show && mainCondition != ""
    let snapshot = hasProgressBar ? getUnlockSnapshotText(cfg) : ""
    let hasLock = needShowLockIcon(cfg)
    let imageCfg = getUnlockImageConfig(cfg)
    let image = LayersIcon.getIconData(imageCfg.style, imageCfg.image,
      imageCfg.ratio, null, imageCfg.params)
    let { rewardText, tooltipId } = getRewardCfgByUnlockCfg(cfg)
    let { subunlocks = null } = getSubunlocksView(cfg, NUM_SUBUNLOCK_COLUMNS, true)

    view.items.append({
      icon = getFavUnlockIcon(cfg.id)
      title = getUnlockTitle(cfg)
      image
      hasLock
      effectType = imageCfg.effect
      description = getUnlockDesc(cfg)
      hasProgressBar
      progress = progressData.value
      mainCondition = " ".join([mainCondition, snapshot], true)
      multDesc = getUnlockMultDescByCfg(cfg)
      conditions = getUnlockCondsDescByCfg(cfg)
      rewardText
      rewardTooltipId = tooltipId
      subunlocks
      stages = getUnlockStagesView(cfg)
    })
  }
  return view
}

let tabsConfig = [
  {
    isVisible = @() isBattleTasksAvailable()
    text = "#userlog/page/battletasks"
    noTasksLocId = "mainmenu/personalTasks/noBattleTasks"
    getTasksView = getBattleTasksView
    tasksTpl = "%gui/unlocks/battleTasksItem.tpl"
  }
  {
    isVisible = @() true
    text = "#mainmenu/personalTasks/battlePassTasks"
    noTasksLocId = ""
    getTasksView = getBattlePassTasksView
    tasksTpl = "%gui/unlocks/battleTasksItem.tpl"
  }
  {
    isVisible = @() true
    text = $"#{getVendorLocId("mainmenu/btnFavoritesUnlockAchievement")}"
    noTasksLocId = "mainmenu/noFavoriteAchievements"
    getTasksView = getFavUnlocksView
    tasksTpl = "%gui/unlocks/unlockExpandable.tpl"
  }
]

function getTabsView() {
  let view = { tabs = [] }
  foreach (idx, tabData in tabsConfig)
    view.tabs.append({
      tabName = tabData.text
      navImagesText = getNavigationImagesText(idx, tabsConfig.len())
      hidden = !tabData.isVisible()
    })
  return view
}

class PersonalTasksModal (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/unlocks/personalTasksModal.blk"

  function initScreen() {
    let tabList = this.scene.findObject("tab_list")
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", getTabsView())
    this.guiScene.replaceContentFromText(tabList, data, data.len(), this)

    let gmName = getRoomEvent()?.name
    let hasBattleTasks = gmName != null
      && getCurBattleTasksByGm(gmName).len() > 0
    tabList.setValue(hasBattleTasks ? 0 : 1) 
  }

  function onTabChange(obj) {
    let { getTasksView, noTasksLocId, tasksTpl } = tabsConfig[obj.getValue()]

    let view = getTasksView()
    let hasTasks = view.items.len() > 0
    let tasksObj = showObjById("task_list", hasTasks, this.scene)
    let noTasksObj = showObjById("no_tasks_text", !hasTasks, this.scene)

    if (hasTasks) {
      let data = handyman.renderCached(tasksTpl, view)
      this.guiScene.replaceContentFromText(tasksObj, data, data.len(), this)

      let idx = view.items.findindex(@(i) i?.isSelected ?? false) ?? 0
      tasksObj.setValue(idx)
    }
    else
      noTasksObj.setValue(locByVendor(noTasksLocId))
  }

  function onTaskSelect(obj) {
    this.guiScene.applyPendingChanges(false)

    let taskObj = getSelectedChild(obj)
    taskObj.scrollToView(true)
    move_mouse_on_obj(taskObj)
  }

  function onViewBattleTaskRequirements(obj) {
    let unlockBlk = isBattleTask(obj.task_id)
      ? getBattleTaskById(obj.task_id)
      : getUnlockById(obj.task_id)
    let unlockCfg = buildConditionsConfig(unlockBlk)
    let reqUnlocks = unlockCfg.names.map(
      @(id) buildLogUnlockData(buildConditionsConfig(getUnlockById(id))))
    showUnlocksGroupWnd(reqUnlocks, loc("unlocks/requirements"))
  }
}

register_gui_handler("PersonalTasksModal", PersonalTasksModal)

return freeze({
  openPersonalTasks = @() handlersManager.loadHandler(PersonalTasksModal)
})
