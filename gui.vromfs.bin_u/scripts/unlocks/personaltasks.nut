from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getSelectedChild, move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { updateChallenges, curSeasonChallenges, getChallengeView
} = require("%scripts/battlePass/challenges.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getFavoriteUnlocks } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getUnlockType } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockMainCondDescByCfg, getUnlockMultDescByCfg, getUnlockDesc, getUnlockCondsDescByCfg,
  getUnlockTitle, getUnlockSnapshotText, needShowLockIcon, getUnlockImageConfig, buildConditionsConfig,
  getRewardCfgByUnlockCfg, getSubunlocksView, getUnlockStagesView
} = require("%scripts/unlocks/unlocksViewModule.nut")
let { isBattleTask, isBattleTasksAvailable, isBattleTaskDone, getBattleTaskById,
  getCurBattleTasksByGm
} = require("%scripts/unlocks/battleTasks.nut")
let { mkUnlockConfigByBattleTask, getBattleTaskView } = require("%scripts/unlocks/battleTasksView.nut")
let { getRoomEvent } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { build_log_unlock_data } = require("%scripts/unlocks/unlocks.nut")

let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")

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
  let items = curSeasonChallenges.value
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
    text = "#mainmenu/btnFavoritesUnlockAchievement"
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

let class PersonalTasksModal (gui_handlers.BaseGuiHandlerWT) {
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
      noTasksObj.setValue(loc(noTasksLocId))
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
      @(id) build_log_unlock_data(buildConditionsConfig(getUnlockById(id))))
    showUnlocksGroupWnd(reqUnlocks, loc("unlocks/requirements"))
  }
}

gui_handlers.PersonalTasksModal <- PersonalTasksModal

return {
  openPersonalTasks = @() handlersManager.loadHandler(PersonalTasksModal)
}
