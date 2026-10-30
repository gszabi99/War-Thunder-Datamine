import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/promo/promo.nut" import getPromoConfig, getPromoCollapsedText, getPromoCollapsedIcon, getPromoVisibilityById, togglePromoItem, PERFORM_PROMO_ACTION_NAME, performPromoAction, getPromoActionParamsKey
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/viewUtils/daguiFonts.nut" import getStringWidthPx
from "%scripts/sqDagui/guiBhv/guiBhvValueConfig.nut" import stashBhvValueConfig
from "%scripts/promo/promoButtonsConfig.nut" import addPromoButtonConfig
from "%scripts/unlocks/battleTaskDifficulty.nut" import getDefaultDifficultyGroup
from "%scripts/unlocks/battleTasksState.nut" import getDifficultyTypeByTask
from "%scripts/unlocks/battleTasks.nut" import isBattleTaskActive, isBattleTasksAvailable, isBattleTaskDone, isBattleTaskExpired, canActivateSpecialTask, canGetBattleTaskReward, getBattleTaskWithAvailableAward
  , getBattleTasksOrderedByDiff, filterBattleTasksByGameModeId, getBattleTaskDiffGroups, requestBattleTaskReward
from "%scripts/unlocks/battleTasksView.nut" import setBattleTasksUpdateTimer, getBattleTaskView, getBattleTaskDifficultyImage
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/unlocks/unlocksState.nut" import buildConditionsConfig
from "%scripts/unlocks/unlocksViewModule.nut" import buildUnlockDesc
from "%scripts/gameModes/gameModeManagerState.nut" import getGameModeEvent, getCurrentGameMode, getCurrentGameModeId
from "%scripts/warbonds/warbondsManager.nut" import openWarbondsShop
from "%sqstd/datablock.nut" import copyParamsToTable
from "%scripts/dagui_library.nut" import *
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { easyDailyTaskProgressWatchObj, mediumDailyTaskProgressWatchObj, leftSpecialTasksBoughtCountWatchObj } = require("%scripts/battlePass/watchObjInfoConfig.nut")

dagui_propid_add_name_id("task_id")
dagui_propid_add_name_id("difficultyGroup")

let BattleTasksPromoHandler = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM

  sceneBlkName = "%gui/empty.blk"
  savePathBattleTasksDiff = "promo/battleTasksDiff"

  static function open(params) {
    handlersManager.loadHandler(get_gui_handler("BattleTasksPromoHandler"), params)
  }

  function initScreen() {
    this.updateHandler()
  }

  function updateHandler() {
    let id = this.scene.id
    local difficultyGroupArray = []

    
    let tasksArray = getBattleTasksOrderedByDiff()

    
    local reqTask = getBattleTaskWithAvailableAward(tasksArray)

    let event = getGameModeEvent(getCurrentGameMode())
    let currentGameModeId = event?.name ?? getCurrentGameModeId()
    
    if (!reqTask && currentGameModeId) {
      local curDifficultyGroup = loadLocalAccountSettings(this.savePathBattleTasksDiff,
        getDefaultDifficultyGroup())
      let activeTasks = filterBattleTasksByGameModeId(tasksArray, currentGameModeId).filter(
          @(task) !isBattleTaskDone(task) && isBattleTaskActive(task)
          && (canGetBattleTaskReward(task) || !isBattleTaskExpired(task)))

              
      difficultyGroupArray = this.getDifficultyRadioButtonsListByTasks(activeTasks,
        getBattleTaskDiffGroups(),
        curDifficultyGroup)
      if (difficultyGroupArray.len() == 1)
        curDifficultyGroup = difficultyGroupArray[0].difficultyGroup
      reqTask = u.search(activeTasks,
        @(task) (getDifficultyTypeByTask(task).getDifficultyGroup() == curDifficultyGroup))
    }

    let promoView = copyParamsToTable(getPromoConfig()?[id])
    local view = {}

    if (reqTask) {
      let config = buildConditionsConfig(reqTask)
      buildUnlockDesc(config)

      let itemView = getBattleTaskView(config, { isPromo = true })
      itemView.canReroll = false
      view = u.tablesCombine(itemView, promoView, function(val1, val2) { return val1 != null ? val1 : val2 })
      view.collapsedText <- getPromoCollapsedText(view, id)
    }
    else {
      promoView.id <- id
      view = getBattleTaskView(promoView, { isPromo = true })
      view.collapsedText <- getPromoCollapsedText(promoView, id)
      view.refreshTimer <- true
    }

    if (!(view.needShowProgressBar ?? false) && view.needShowProgressValue) {
      let progressValueText = loc("ui/parentheses/space",
        { text = "".concat(view.progressValue, "/", view.progressMaxValue) })
      view.collapsedText = $"{view.collapsedText}{progressValueText}"
    }
    let maxTextWidth = to_pixels("".concat("1@arrowButtonWidth-1@mIco-2@blockInterval",
      view.taskStatus != null ? "-1@modStatusHeight" : "",
      view.newIconWidget != null ? "-1@arrowButtonHeight" : ""))
    view.collapsedIcon <- getPromoCollapsedIcon(view, id)
    let iconSize = getStringWidthPx(view.collapsedIcon, "fontNormal", this.guiScene) + to_pixels("1@blockInterval")
    if (getStringWidthPx(view.collapsedText, "fontNormal", this.guiScene) > maxTextWidth - iconSize)
      view.shortInfoBlockWidth <- to_pixels("1@arrowButtonWidth-1@blockInterval")
    view.hasMarginCollapsedIcon <- view.collapsedText != "" && view.taskDifficultyImage != ""
    view.hasCollapsedText <- view.collapsedText != ""
    let taskHeaderCondition = view?.taskHeaderCondition ?? ""
    if (taskHeaderCondition != "")
      view.title = $"{view.title} {taskHeaderCondition}"
    if (getStringWidthPx(view.title, "fontNormal", this.guiScene) > maxTextWidth)
      view.headerWidth <- maxTextWidth
    view.performActionId <- getPromoActionParamsKey(id)
    view.taskId <- reqTask?.id
    view.action <- PERFORM_PROMO_ACTION_NAME


    view.isShowRadioButtons <- (difficultyGroupArray.len() > 1 && hasFeature("PromoBattleTasksRadioButtons"))
    view.radioButtons <- difficultyGroupArray
    view.otherTasksNumText <- view.otherTasksNum > 0 ? "#mainmenu/battleTasks/OtherTasksCount" : ""
    let isEmptyTask = view.taskId == null
    if (isEmptyTask) {
      view.easyDailyTaskProgressValue <- stashBhvValueConfig(easyDailyTaskProgressWatchObj)
      view.mediumDailyTaskProgressValue <- stashBhvValueConfig(mediumDailyTaskProgressWatchObj)
      if (canActivateSpecialTask())
        view.leftSpecialTasksBoughtCountValue <- stashBhvValueConfig(leftSpecialTasksBoughtCountWatchObj)
    }

    let data = handyman.renderCached("%gui/promo/promoBattleTasks.tpl",
      { items = [view], collapsedAction = PERFORM_PROMO_ACTION_NAME })
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)

    setBattleTasksUpdateTimer(reqTask, this.scene)
  }

  function onGetRewardForTask(obj) {
    requestBattleTaskReward(obj?.task_id)
  }

  function onWarbondsShop(_obj) {
    openWarbondsShop()
  }

  function onSelectDifficultyBattleTasks(obj) {
    let index = obj.getValue()
    if (index < 0 || index >= obj.childrenCount())
      return

    let difficultyGroup = obj.getChild(index)?.difficultyGroup

    if (!difficultyGroup)
      return

    saveLocalAccountSettings(this.savePathBattleTasksDiff, difficultyGroup)

    this.guiScene.performDelayed(this, function() {
      this.updateHandler()
    })
  }

  function getDifficultyRadioButtonsListByTasks(tasksArray, difficultyTypeArray, curDifficultyGroup) {
    let result = []
    foreach (btDiffType in difficultyTypeArray) {
      let difficultyGroup = btDiffType.getDifficultyGroup()
      let tasksByDiff = u.search(tasksArray,
          @(task) (getDifficultyTypeByTask(task) == btDiffType))

      if (!tasksByDiff)
        continue

      result.append({ radioButtonImage = getBattleTaskDifficultyImage(tasksByDiff)
        difficultyGroup = difficultyGroup
        difficultyLocName = btDiffType.getLocName()
        selected = (curDifficultyGroup == difficultyGroup) })
    }
    return result
  }

  function performAction(obj) { performPromoAction(this, obj) }
  function performActionCollapsed(obj) {
    let buttonObj = obj.getParent()
    this.performAction(buttonObj.findObject(getPromoActionParamsKey(buttonObj.id)))
  }
  function onToggleItem(obj) { togglePromoItem(obj) }

  function updateHandlerWhenUnitChanged() {
    if (getCurrentGameMode()?.isDependsOnUnit)
      this.updateHandler()
  }

  onEventNewBattleTasksChanged                = @(_p) this.updateHandler()
  onEventBattleTasksFinishedUpdate            = @(_p) this.updateHandler()
  onEventBattleTasksTimeExpired               = @(_p) this.updateHandler()
  onEventCurrentGameModeIdChanged             = @(_p) this.updateHandler()
  onEventWarbondShopMarkSeenLevel             = @(_p) this.updateHandler()
  onEventXboxMultiplayerPrivilegeUpdated      = @(_p) this.updateHandler()
  onEventCrewChanged                          = @(_p) this.updateHandlerWhenUnitChanged()
  onEventCountryChanged                       = @(_p) this.updateHandlerWhenUnitChanged()
}
register_gui_handler("BattleTasksPromoHandler", BattleTasksPromoHandler)

const promoButtonId = "current_battle_tasks_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "battleTask"
  collapsedIconLocKey = "icon/battleTasks"
  collapsedText = "title"
  updateByEvents = ["BattleTasksFinishedUpdate"]
  updateFunctionInHandler = function() {
    let id = promoButtonId
    let show = isBattleTasksAvailable()
      && getPromoVisibilityById(id)
    let buttonObj = showObjById(id, show, this.scene)
    if (!show || !checkObj(buttonObj))
      return

    BattleTasksPromoHandler.open({ scene = buttonObj })
  }
})
