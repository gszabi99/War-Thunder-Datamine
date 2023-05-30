from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { updateChallenges, curSeasonChallenges, getChallengeView
} = require("%scripts/battlePass/challenges.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getSelectedChild } = require("%sqDagui/daguiUtil.nut")
let { getFavoriteUnlocks } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getUnlockTypeById } = require("unlocks")
let { getUnlockMainCondDescByCfg, getUnlockMultDescByCfg, getUnlockDesc, getUnlockCondsDescByCfg,
  getUnlockTitle, getUnlockSnapshotText } = require("%scripts/unlocks/unlocksViewModule.nut")

const NUM_SUBUNLOCK_COLUMNS = 3

let function getBattleTasksView() {
  let gmName = ::game_mode_manager.getCurrentGameModeId()
  let items = []
  foreach (task in ::g_battle_tasks.getCurBattleTasksByGm(gmName)) {
    let cfg = ::g_battle_tasks.generateUnlockConfigByTask(task)
    let item = ::g_battle_tasks.generateItemView(cfg, { isInteractive = false })
    item.isSelected <- !::g_battle_tasks.isTaskDone(task)
    items.append(item)
  }
  return { items }
}

local isBpTasksUpdated = false
let function updateBpTasksOnce() {
  if (!isBpTasksUpdated) {
    updateChallenges()
    isBpTasksUpdated = true
  }
}
addListenersWithoutEnv({
  BattlePassCacheInvalidate = @(_) isBpTasksUpdated = false
})

let function getBattlePassTasksView() {
  updateBpTasksOnce()
  let items = curSeasonChallenges.value
    .map(@(blk) getChallengeView(blk, { isInteractive = false }))
  return { items }
}

let function getFavUnlockIcon(unlockId) {
  let unlockType = getUnlockTypeById(unlockId)
  return unlockType == UNLOCKABLE_SKIN ? "#ui/gameuiskin#unlock_skin"
    : unlockType == UNLOCKABLE_DECAL ? "#ui/gameuiskin#unlock_decal"
    : unlockType == UNLOCKABLE_ATTACHABLE ? "#ui/gameuiskin#unlock_attachable"
    : "#ui/gameuiskin#unlock_achievement"
}

let function getFavUnlocksView() {
  let view = { items = [] }
  let unlockListBlk = getFavoriteUnlocks()
  for (local i = 0; i < unlockListBlk.blockCount(); ++i) {
    let blk = unlockListBlk.getBlock(i)
    let cfg = ::build_conditions_config(blk)
    let progressData = cfg.getProgressBarData()
    let mainCondition = getUnlockMainCondDescByCfg(cfg)
    let hasProgressBar = progressData.show && mainCondition != ""
    let snapshot = getUnlockSnapshotText(cfg)
    let hasLock = ::g_unlock_view.needShowLockIcon(cfg)
    let imageCfg = ::g_unlock_view.getUnlockImageConfig(cfg)
    let image = LayersIcon.getIconData(imageCfg.style, imageCfg.image,
      imageCfg.ratio, null, imageCfg.params)
    let { rewardText, tooltipId } = ::g_unlock_view.getRewardConfig(cfg)
    let { subunlocks = null } = ::g_unlock_view.getSubunlocksView(cfg, NUM_SUBUNLOCK_COLUMNS, true)

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
      stages = ::g_unlock_view.getStagesView(cfg)
    })
  }
  return view
}

let tabsConfig = [
  {
    isVisible = @() ::g_battle_tasks.isAvailableForUser()
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

let function getTabsView() {
  let view = { tabs = [] }
  foreach (idx, tabData in tabsConfig)
    view.tabs.append({
      tabName = tabData.text
      navImagesText = ::get_navigation_images_text(idx, tabsConfig.len())
      hidden = !tabData.isVisible()
    })
  return view
}

let class PersonalTasksModal extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/unlocks/personalTasksModal.blk"

  function initScreen() {
    let tabList = this.scene.findObject("tab_list")
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", getTabsView())
    this.guiScene.replaceContentFromText(tabList, data, data.len(), this)

    let gmName = ::game_mode_manager.getCurrentGameModeId()
    let hasBattleTasks = ::g_battle_tasks.getCurBattleTasksByGm(gmName).len() > 0
    tabList.setValue(hasBattleTasks ? 0 : 1) // if no tasks select next one
  }

  function onTabChange(obj) {
    let { getTasksView, noTasksLocId, tasksTpl } = tabsConfig[obj.getValue()]

    let view = getTasksView()
    let hasTasks = view.items.len() > 0
    let tasksObj = this.showSceneBtn("task_list", hasTasks)
    let noTasksObj = this.showSceneBtn("no_tasks_text", !hasTasks)

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
    ::move_mouse_on_obj(taskObj)
  }

  function onViewBattleTaskRequirements(obj) {
    let unlockBlk = ::g_battle_tasks.isBattleTask(obj.task_id)
      ? ::g_battle_tasks.getTaskById(obj.task_id)
      : getUnlockById(obj.task_id)
    let unlockCfg = ::build_conditions_config(unlockBlk)
    let reqUnlocks = unlockCfg.names.map(
      @(id) ::build_log_unlock_data(::build_conditions_config(getUnlockById(id))))
    showUnlocksGroupWnd(reqUnlocks, loc("unlocks/requirements"))
  }
}

::gui_handlers.PersonalTasksModal <- PersonalTasksModal

return {
  openPersonalTasks = @() ::handlersManager.loadHandler(PersonalTasksModal)
}
