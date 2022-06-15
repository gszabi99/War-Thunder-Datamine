let stdMath = require("%sqstd/math.nut")
let { leftSpecialTasksBoughtCount } = require("%scripts/warbonds/warbondShopState.nut")
let { warbondsShopLevelByStages } = require("%scripts/battlePass/seasonState.nut")

enum WARBOND_SHOP_LEVEL_STATUS {
  LOCKED = "locked"
  RECEIVED = "received"
  CURRENT = "current"
}

::g_warbonds_view <- {
  [PERSISTENT_DATA_PARAMS] = ["needShowProgressBarInPromo"]
  progressBarId = "warbond_shop_progress"
  progressBarAddId = "warbond_shop_progress_additional_bar"
  levelItemIdPrefix = "level_"
  maxProgressBarValue = 10000

  needShowProgressBarInPromo = false

  function getSpecialMedalView(wbClass, reqAwardMedals = 0, needShowZero = false, hasName = false)
  {
    let medalsCount = getWarbondMedalsCount(wbClass)
    return {
      posX = 0
      image = wbClass? wbClass.getMedalIcon() : null
      countText = needShowZero && reqAwardMedals==0? reqAwardMedals.tostring() : reqAwardMedals
      inactive = medalsCount < reqAwardMedals
      title = hasName ? ::loc("mainmenu/battleTasks/special/medals") : null
    }
  }

  function getSpecialMedalInProgressView(wbClass)
  {
    let leftTasks = wbClass.leftForAnotherMedalTasks()
    return {
      sector = 360 - (360 * leftTasks.tofloat() / wbClass.medalForSpecialTasks)
      image = wbClass ? wbClass.getMedalIcon() : null
    }
  }

  function getSpecialMedalCanBuyMarkUp(wbClass) {
    if (leftSpecialTasksBoughtCount.value < 0)
      return ""

    let view = {
      medal = [{
        posX = 0
        image = wbClass?.getMedalIcon()
        countText = leftSpecialTasksBoughtCount.value.tostring()
        title = ::loc("warbonds/canBuySpecialTasks")
      }]
      tooltip = ::loc("warbonds/canBuySpecialTasks/tooltip")
    }

    return ::handyman.renderCached("%gui/items/warbondSpecialMedal", view)
  }

  getBattlePassStageByShopLevel = @(level) warbondsShopLevelByStages.value.findindex(
    @(l) level == l) ?? -1

  function getLevelItemTooltipKey(status)
  {
    if (!::has_feature("BattlePass"))
      return "warbonds/shop/level/" + status + "/tooltip"

    if (status == WARBOND_SHOP_LEVEL_STATUS.LOCKED)
      return "warbonds/shop/level/locked/tooltip_battlepass"

    return "warbonds/shop/level/current/tooltip"
  }

}

g_warbonds_view.createProgressBox <- function createProgressBox(wbClass, placeObj, handler, needForceHide = false)
{
  if (!::check_obj(placeObj))
    return

  let nest = placeObj.findObject("progress_box_place")
  if (!::check_obj(nest))
    return

  let show = !needForceHide
               && wbClass != null
               && wbClass.haveAnyOrdinaryRequirements()
               && wbClass.levelsArray.len()
  nest.show(show)
  if (!show)
    return

  local pbMarkUp = getProgressBoxMarkUp()
  pbMarkUp += getLevelItemsMarkUp(wbClass)

  nest.getScene().replaceContentFromText(nest, pbMarkUp, pbMarkUp.len(), handler)
  updateProgressBar(wbClass, nest)
}

g_warbonds_view.getProgressBoxMarkUp <- function getProgressBoxMarkUp()
{
  return ::handyman.renderCached("%gui/commonParts/progressBarModern", {
    id = progressBarId
    addId = progressBarAddId
    additionalProgress = true
  })
}

g_warbonds_view.getLevelItemsMarkUp <- function getLevelItemsMarkUp(wbClass)
{
  let view = { level = [] }
  foreach (level, reqTasks in wbClass.levelsArray)
    view.level.append(getLevelItemData(wbClass, level))

  return ::handyman.renderCached("%gui/items/warbondShopLevelItem", view)
}

g_warbonds_view.getCurrentLevelItemMarkUp <- function getCurrentLevelItemMarkUp(wbClass, forcePosX = "0")
{
  let curLevel = wbClass.getCurrentShopLevel()
  if (curLevel < 0)
    return null

  return getLevelItemMarkUp(wbClass, curLevel, forcePosX)
}

g_warbonds_view.getLevelItemMarkUp <- function getLevelItemMarkUp(wbClass, level, forcePosX = null, params = {})
{
  let levelData = getLevelItemData(wbClass, level, forcePosX, params)
  return ::handyman.renderCached("%gui/items/warbondShopLevelItem", { level = [levelData]} )
}

g_warbonds_view.getLevelItemData <- function getLevelItemData(wbClass, level, forcePosX = null, params = {})
{
  let status = getLevelStatus(wbClass, level)
  let reqTasks = ::has_feature("BattlePass") ? getBattlePassStageByShopLevel(level)
    : wbClass.getShopLevelTasks(level)

  local posX = forcePosX
  if (!posX)
  {
    let maxLevel = wbClass.levelsArray.len() - 1
    posX = level / maxLevel.tofloat() + "pw - 50%w"
  }

  let lvlText = wbClass.getShopLevelText(level)
  return {
    id = levelItemIdPrefix + level
    levelIcon = wbClass.getLevelIcon()
    levelIconOverlay = wbClass.getLevelIconOverlay()
    text = lvlText
    tooltip = ::loc(getLevelItemTooltipKey(status), {level = lvlText, tasksNum = reqTasks})
    status = status
    posX = posX
    hasOverlayIcon = true
  }.__merge(params)
}

g_warbonds_view.getLevelStatus <- function getLevelStatus(wbClass, level)
{
  let curShopLevel = wbClass.getCurrentShopLevel()
  if (curShopLevel == level)
    return WARBOND_SHOP_LEVEL_STATUS.CURRENT

  if (level > curShopLevel)
    return WARBOND_SHOP_LEVEL_STATUS.LOCKED

  return WARBOND_SHOP_LEVEL_STATUS.RECEIVED
}

g_warbonds_view.calculateProgressBarValue <- function calculateProgressBarValue(wbClass, level, steps, curTasksDone)
{
  if (wbClass.isMaxLevelReached() && steps == 1)
    level -= 1

  let levelTasks = wbClass.getShopLevelTasks(level)
  let nextLevelTasks = wbClass.getShopLevelTasks(level + 1)

  let progressPeerLevel = maxProgressBarValue.tofloat() / steps
  let iLerp = stdMath.lerp(levelTasks, nextLevelTasks, 0, progressPeerLevel, curTasksDone)

  return steps == 1? iLerp : (progressPeerLevel * level + iLerp)
}

g_warbonds_view.updateProgressBar <- function updateProgressBar(wbClass, placeObj, isForSingleStep = false)
{
  if (!wbClass)
    return

  let progressBoxObj = placeObj.findObject(progressBarId)
  if (!::check_obj(progressBoxObj))
    return

  let steps = isForSingleStep? 1 : wbClass.levelsArray.len() - 1
  let level = wbClass.getCurrentShopLevel()
  let tasks = wbClass.getCurrentShopLevelTasks()

  local totalTasks = tasks
  let reqTask = ::g_battle_tasks.getTaskWithAvailableAward(::g_battle_tasks.getActiveTasksArray())
  if (reqTask && ::g_battle_task_difficulty.getDifficultyTypeByTask(reqTask).canIncreaseShopLevel)
    totalTasks++
  let curProgress = calculateProgressBarValue(wbClass, level, steps, totalTasks)

  progressBoxObj.setValue(curProgress.tointeger())

  if (!::has_feature("BattlePass"))
    progressBoxObj.tooltip = getCurrentShopProgressBarText(wbClass)

  let addProgressBarObj = progressBoxObj.findObject(progressBarAddId)
  if (::checkObj(addProgressBarObj))
  {
    let addBarValue = calculateProgressBarValue(wbClass, level, steps, tasks)
    addProgressBarObj.setValue(addBarValue)
  }
}

g_warbonds_view.getCurrentShopProgressBarText <- function getCurrentShopProgressBarText(wbClass)
{
  if (!showOrdinaryProgress(wbClass) || wbClass.levelsArray.len() == 0)
    return ""

  return getShopProgressBarText(
    wbClass.getCurrentShopLevelTasks(),
    wbClass.getNextShopLevelTasks()
  )
}

g_warbonds_view.getShopProgressBarText <- function getShopProgressBarText(curTasks, nextLevelTasks)
{
  return ::loc("mainmenu/battleTasks/progressBarTooltip", {
    tasksNum = curTasks
    nextLevelTasksNum = nextLevelTasks
  })
}

g_warbonds_view.createSpecialMedalsProgress <- function createSpecialMedalsProgress(wbClass, placeObj, handler, addCanBuySpecialTasks = false)
{
  if (!::check_obj(placeObj))
    return

  let nest = placeObj.findObject("medal_icon")
  if (!::check_obj(nest))
    return

  let show = showSpecialProgress(wbClass)
  nest.show(show)
  if (!show)
    return

  local data = getSpecialMedalsMarkUp(wbClass, getWarbondMedalsCount(wbClass), true, true, true)

  if (addCanBuySpecialTasks)
    data = $"{data}{getSpecialMedalCanBuyMarkUp(wbClass)}"

  nest.getScene().replaceContentFromText(nest, data, data.len(), handler)
}

g_warbonds_view.getSpecialMedalsTooltip <- function getSpecialMedalsTooltip(wbClass)
{
  return ::loc("mainmenu/battleTasks/special/medals/tooltip",
  {
    medals = getWarbondMedalsCount(wbClass),
    tasksNum = wbClass.medalForSpecialTasks
  })
}

g_warbonds_view.getSpecialMedalsMarkUp <- function getSpecialMedalsMarkUp(wbClass, reqAwardMedals = 0, needShowZero = false, hasName = false, needShowInProgress = false)
{
  let view = {
    medal = [getSpecialMedalView(wbClass, reqAwardMedals, needShowZero, hasName)]
    tooltip = getSpecialMedalsTooltip(wbClass)
  }

  if (needShowInProgress && wbClass.needShowSpecialTasksProgress)
    view.medal.append(getSpecialMedalInProgressView(wbClass))

  return ::handyman.renderCached("%gui/items/warbondSpecialMedal", view)
}

g_warbonds_view.getWarbondMedalsCount <- function getWarbondMedalsCount(wbClass)
{
  return wbClass? wbClass.getCurrentMedalsCount() : 0
}

g_warbonds_view.showOrdinaryProgress <- function showOrdinaryProgress(wbClass)
{
  return wbClass && wbClass.haveAnyOrdinaryRequirements()
}

g_warbonds_view.showSpecialProgress <- function showSpecialProgress(wbClass)
{
  return wbClass && wbClass.haveAnySpecialRequirements()
}

g_warbonds_view.resetShowProgressBarFlag <- function resetShowProgressBarFlag()
{
  if (!needShowProgressBarInPromo)
    return

  needShowProgressBarInPromo = false
  ::broadcastEvent("WarbondViewShowProgressBarFlagUpdate")
}

::g_script_reloader.registerPersistentDataFromRoot("g_warbonds_view")
::subscribe_handler(::g_warbonds_view, ::g_listener_priority.DEFAULT_HANDLER)