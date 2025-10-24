from "%scripts/dagui_library.nut" import *
import "%sqstd/math.nut" as stdMath

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { leftSpecialTasksBoughtCount } = require("%scripts/warbonds/warbondShopState.nut")
let { warbondsShopLevelByStages } = require("%scripts/battlePass/seasonState.nut")

enum WARBOND_SHOP_LEVEL_STATUS {
  LOCKED = "locked"
  RECEIVED = "received"
  CURRENT = "current"
}

const progressBarId = "warbond_shop_progress"
const progressBarAddId = "warbond_shop_progress_additional_bar"
const levelItemIdPrefix = "level_"
const maxProgressBarValue = 10000

let getWarbondMedalsCount = @(wbClass) wbClass ? wbClass.getCurrentMedalsCount() : 0

let showOrdinaryProgress = @(wbClass) wbClass && wbClass.haveAnyOrdinaryRequirements()

let showSpecialProgress = @(wbClass) wbClass && wbClass.haveAnySpecialRequirements()

let getBattlePassStageByShopLevel = @(level) warbondsShopLevelByStages.get().findindex(
    @(l) level == l) ?? -1

function getSpecialMedalView(wbClass, reqAwardMedals = 0, needShowZero = false, hasName = false) {
  let medalsCount = getWarbondMedalsCount(wbClass)
  return {
    posX = 0
    image = wbClass ? wbClass.getMedalIcon() : null
    countText = needShowZero && reqAwardMedals == 0 ? reqAwardMedals.tostring() : reqAwardMedals
    inactive = medalsCount < reqAwardMedals
    title = hasName ? loc("mainmenu/battleTasks/special/medals") : null
  }
}

function getSpecialMedalInProgressView(wbClass) {
  let leftTasks = wbClass.leftForAnotherMedalTasks()
  return {
    sector = 360 - (360 * leftTasks.tofloat() / wbClass.medalForSpecialTasks)
    image = wbClass ? wbClass.getMedalIcon() : null
  }
}

function getSpecialMedalCanBuyMarkUp(wbClass) {
  if (leftSpecialTasksBoughtCount.get() < 0)
    return ""

  let view = {
    medal = [{
      posX = 0
      image = wbClass?.getMedalIcon()
      countText = leftSpecialTasksBoughtCount.get().tostring()
      title = loc("warbonds/canBuySpecialTasks")
    }]
    tooltip = loc("warbonds/canBuySpecialTasks/tooltip")
  }

  return handyman.renderCached("%gui/items/warbondSpecialMedal.tpl", view)
}

let getLevelItemTooltipKey = @(status) status == WARBOND_SHOP_LEVEL_STATUS.LOCKED
    ? "warbonds/shop/level/locked/tooltip_battlepass"
    : "warbonds/shop/level/current/tooltip"

function getLevelStatus(wbClass, level) {
  let curShopLevel = wbClass.getCurrentShopLevel()
  if (curShopLevel == level)
    return WARBOND_SHOP_LEVEL_STATUS.CURRENT

  if (level > curShopLevel)
    return WARBOND_SHOP_LEVEL_STATUS.LOCKED

  return WARBOND_SHOP_LEVEL_STATUS.RECEIVED
}


function getLevelItemData(wbClass, level, forcePosX = null, params = {}) {
  let status = getLevelStatus(wbClass, level)
  let reqTasks = getBattlePassStageByShopLevel(level)

  local posX = forcePosX
  if (!posX) {
    let maxLevel = wbClass.levelsArray.len() - 1
    posX = $"{level / maxLevel.tofloat()}pw - 50%w"
  }

  let lvlText = wbClass.getShopLevelText(level)
  return {
    id = $"{levelItemIdPrefix}{level}"
    levelIcon = wbClass.getLevelIcon()
    levelIconOverlay = wbClass.getLevelIconOverlay()
    text = lvlText
    tooltip = loc(getLevelItemTooltipKey(status), { level = lvlText, tasksNum = reqTasks })
    status = status
    posX = posX
    hasOverlayIcon = true
  }.__merge(params)
}

function getLevelItemMarkUp(wbClass, level, forcePosX = null, params = {}) {
  let levelData = getLevelItemData(wbClass, level, forcePosX, params)
  return handyman.renderCached("%gui/items/warbondShopLevelItem.tpl", { level = [levelData] })
}

function getCurrentLevelItemMarkUp(wbClass, forcePosX = "0") {
  let curLevel = wbClass.getCurrentShopLevel()
  if (curLevel < 0)
    return null

  return getLevelItemMarkUp(wbClass, curLevel, forcePosX)
}

function getLevelItemsMarkUp(wbClass) {
  let view = { level = [] }
  foreach (level, _reqTasks in wbClass.levelsArray)
    view.level.append(getLevelItemData(wbClass, level))

  return handyman.renderCached("%gui/items/warbondShopLevelItem.tpl", view)
}


function getSpecialMedalsTooltip(wbClass) {
  return loc("mainmenu/battleTasks/special/medals/tooltip",
  {
    medals = getWarbondMedalsCount(wbClass),
    tasksNum = wbClass.medalForSpecialTasks
  })
}

function getSpecialMedalsMarkUp(wbClass, reqAwardMedals = 0, needShowZero = false, hasName = false, needShowInProgress = false) {
  let view = {
    medal = [getSpecialMedalView(wbClass, reqAwardMedals, needShowZero, hasName)]
    tooltip = getSpecialMedalsTooltip(wbClass)
  }

  if (needShowInProgress && wbClass.needShowSpecialTasksProgress)
    view.medal.append(getSpecialMedalInProgressView(wbClass))

  return handyman.renderCached("%gui/items/warbondSpecialMedal.tpl", view)
}


function createSpecialMedalsProgress(wbClass, placeObj, handler, addCanBuySpecialTasks = false) {
  if (!checkObj(placeObj))
    return

  let nest = placeObj.findObject("medal_icon")
  if (!checkObj(nest))
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

function getProgressBoxMarkUp() {
  return handyman.renderCached("%gui/commonParts/progressBarModern.tpl", {
    id = progressBarId
    addId = progressBarAddId
    additionalProgress = true
  })
}

function calculateProgressBarValue(wbClass, level, steps, curTasksDone) {
  if (wbClass.isMaxLevelReached() && steps == 1)
    level -= 1

  let levelTasks = wbClass.getShopLevelTasks(level)
  let nextLevelTasks = wbClass.getShopLevelTasks(level + 1)

  let progressPeerLevel = maxProgressBarValue.tofloat() / steps
  let iLerp = stdMath.lerp(levelTasks, nextLevelTasks, 0, progressPeerLevel, curTasksDone)

  return steps == 1 ? iLerp : (progressPeerLevel * level + iLerp)
}

function updateProgressBar(wbClass, placeObj, isForSingleStep = false) {
  if (!wbClass)
    return

  let progressBoxObj = placeObj.findObject(progressBarId)
  if (!checkObj(progressBoxObj))
    return

  let steps = isForSingleStep ? 1 : wbClass.levelsArray.len() - 1
  let level = wbClass.getCurrentShopLevel()
  let tasks = wbClass.getCurrentShopLevelTasks()

  let curProgress = calculateProgressBarValue(wbClass, level, steps, tasks)
  progressBoxObj.setValue(curProgress.tointeger())

  let addProgressBarObj = progressBoxObj.findObject(progressBarAddId)
  if (checkObj(addProgressBarObj)) {
    let addBarValue = calculateProgressBarValue(wbClass, level, steps, tasks)
    addProgressBarObj.setValue(addBarValue)
  }
}

function createProgressBox(wbClass, placeObj, handler, needForceHide = false) {
  if (!checkObj(placeObj))
    return

  let nest = placeObj.findObject("progress_box_place")
  if (!checkObj(nest))
    return

  let show = !needForceHide
               && wbClass != null
               && wbClass.haveAnyOrdinaryRequirements()
               && wbClass.levelsArray.len()
  nest.show(show)
  if (!show)
    return

  let pbMarkUp = "".concat(getProgressBoxMarkUp(), getLevelItemsMarkUp(wbClass))
  nest.getScene().replaceContentFromText(nest, pbMarkUp, pbMarkUp.len(), handler)
  updateProgressBar(wbClass, nest)
}

return {
  progressBarId
  progressBarAddId
  levelItemIdPrefix
  maxProgressBarValue

  getWarbondMedalsCount
  showOrdinaryProgress
  showSpecialProgress
  getBattlePassStageByShopLevel
  getSpecialMedalView
  getSpecialMedalInProgressView
  getSpecialMedalCanBuyMarkUp
  getLevelItemTooltipKey
  getLevelStatus
  getLevelItemData
  getLevelItemMarkUp
  getCurrentLevelItemMarkUp
  getLevelItemsMarkUp
  getSpecialMedalsTooltip
  getSpecialMedalsMarkUp
  createSpecialMedalsProgress
  createProgressBox
  getProgressBoxMarkUp
  calculateProgressBarValue
  updateProgressBar
}
