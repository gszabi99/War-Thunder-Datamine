local stdMath = require("std/math.nut")

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
}

g_warbonds_view.createProgressBox <- function createProgressBox(wbClass, placeObj, handler, needForceHide = false)
{
  if (!::check_obj(placeObj))
    return

  local nest = placeObj.findObject("progress_box_place")
  if (!::check_obj(nest))
    return

  local show = !needForceHide
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
  return ::handyman.renderCached("gui/commonParts/progressBarModern", {
    id = progressBarId
    addId = progressBarAddId
    additionalProgress = true
  })
}

g_warbonds_view.getLevelItemsMarkUp <- function getLevelItemsMarkUp(wbClass)
{
  local view = { level = [] }
  foreach (level, reqTasks in wbClass.levelsArray)
    view.level.append(getLevelItemData(wbClass, level))

  return ::handyman.renderCached("gui/items/warbondShopLevelItem", view)
}

g_warbonds_view.getCurrentLevelItemMarkUp <- function getCurrentLevelItemMarkUp(wbClass, forcePosX = "0")
{
  local curLevel = wbClass.getCurrentShopLevel()
  if (curLevel < 0)
    return null

  return getLevelItemMarkUp(wbClass, curLevel, forcePosX)
}

g_warbonds_view.getLevelItemMarkUp <- function getLevelItemMarkUp(wbClass, level, forcePosX = null)
{
  local levelData = getLevelItemData(wbClass, level, forcePosX)
  return ::handyman.renderCached("gui/items/warbondShopLevelItem", { level = [levelData]} )
}

g_warbonds_view.getLevelItemData <- function getLevelItemData(wbClass, level, forcePosX = null)
{
  local status = getLevelStatus(wbClass, level)
  local reqTasks = wbClass.getShopLevelTasks(level)

  local posX = forcePosX
  if (!posX)
  {
    local maxLevel = wbClass.levelsArray.len() - 1
    posX = level / maxLevel.tofloat() + "pw - 50%w"
  }

  local lvlText = wbClass.getShopLevelText(level)
  return {
    id = levelItemIdPrefix + level
    levelIcon = wbClass.getLevelIcon()
    text = lvlText
    tooltip = ::loc("warbonds/shop/level/" + status + "/tooltip", {level = lvlText, tasksNum = reqTasks})
    status = status
    posX = posX
  }
}

g_warbonds_view.getLevelStatus <- function getLevelStatus(wbClass, level)
{
  local curShopLevel = wbClass.getCurrentShopLevel()
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

  local levelTasks = wbClass.getShopLevelTasks(level)
  local nextLevelTasks = wbClass.getShopLevelTasks(level + 1)

  local progressPeerLevel = maxProgressBarValue.tofloat() / steps
  local iLerp = stdMath.lerp(levelTasks, nextLevelTasks, 0, progressPeerLevel, curTasksDone)

  return steps == 1? iLerp : (progressPeerLevel * level + iLerp)
}

g_warbonds_view.updateProgressBar <- function updateProgressBar(wbClass, placeObj, isForSingleStep = false)
{
  if (!wbClass)
    return

  local progressBoxObj = placeObj.findObject(progressBarId)
  if (!::check_obj(progressBoxObj))
    return

  local steps = isForSingleStep? 1 : wbClass.levelsArray.len() - 1
  local level = wbClass.getCurrentShopLevel()
  local tasks = wbClass.getCurrentShopLevelTasks()

  local totalTasks = tasks
  local reqTask = ::g_battle_tasks.getTaskWithAvailableAward(::g_battle_tasks.getActiveTasksArray())
  if (reqTask && ::g_battle_task_difficulty.getDifficultyTypeByTask(reqTask).canIncreaseShopLevel)
    totalTasks++
  local curProgress = calculateProgressBarValue(wbClass, level, steps, totalTasks)

  progressBoxObj.setValue(curProgress.tointeger())
  progressBoxObj.tooltip = getCurrentShopProgressBarText(wbClass)

  local addProgressBarObj = progressBoxObj.findObject(progressBarAddId)
  if (::checkObj(addProgressBarObj))
  {
    local addBarValue = calculateProgressBarValue(wbClass, level, steps, tasks)
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

g_warbonds_view.createSpecialMedalsProgress <- function createSpecialMedalsProgress(wbClass, placeObj, handler)
{
  if (!::check_obj(placeObj))
    return

  local nest = placeObj.findObject("medal_icon")
  if (!::check_obj(nest))
    return

  local show = wbClass && wbClass.haveAnySpecialRequirements()
  nest.show(show)
  if (!show)
    return

  nest.tooltip = getSpecialMedalsTooltip(wbClass)
  local data = getSpecialMedalsMarkUp(wbClass, getWarbondMedalsCount(wbClass), true)
  data += getSpecialMedalInProgressMarkUp(wbClass)
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

g_warbonds_view.getSpecialMedalsMarkUp <- function getSpecialMedalsMarkUp(wbClass, reqAwardMedals = 0, needShowZero = false)
{
  local medalsCount = getWarbondMedalsCount(wbClass)
  local view = { medal = [{
      posX = 0
      image = wbClass? wbClass.getMedalIcon() : null
      countText = needShowZero && reqAwardMedals==0? reqAwardMedals.tostring() : reqAwardMedals
      inactive = medalsCount < reqAwardMedals
  }]}

  return ::handyman.renderCached("gui/items/warbondSpecialMedal", view)
}

g_warbonds_view.getSpecialMedalInProgressMarkUp <- function getSpecialMedalInProgressMarkUp(wbClass)
{
  if (!wbClass.needShowSpecialTasksProgress)
    return ""

  local leftTasks = wbClass.leftForAnotherMedalTasks()
  local view = { medal = [{
    sector = 360 - (360 * leftTasks.tofloat()/wbClass.medalForSpecialTasks)
    image = wbClass? wbClass.getMedalIcon() : null
  }]}
  return ::handyman.renderCached("gui/items/warbondSpecialMedal", view)
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