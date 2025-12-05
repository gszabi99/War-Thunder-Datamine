from "%scripts/dagui_natives.nut" import set_hint_options_by_blk, disable_hint, set_option_hint_enabled
from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HINT_INTERVAL
from "%scripts/timeBar.nut" import g_time_bar

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { isNull } = require("%sqStdLibs/helpers/u.nut")
let { get_charserver_time_sec } = require("chard")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let DaguiSceneTimers = require("%sqDagui/timer/daguiSceneTimers.nut")
let { getHudElementAabb, dmPanelStatesAabb } = require("%scripts/hud/hudElementsAabb.nut")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { isInFlight } = require("gameplayBinding")
let { getHintSeenCount, increaseHintShowCount, resetHintShowCount, getHintSeenTime,
  getHintByShowEvent, g_hud_hints} = require("%scripts/hud/hudHints.nut")
let { register_command } = require("console")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isVisualHudAirWeaponSelectorOpened } = require("%scripts/hud/hudAirWeaponSelector.nut")
let { isPlayerAlive } = require("%scripts/hud/hudState.nut")
let { get_game_mode } = require("mission")
let { deferOnce } = require("dagor.workcycle")

const TIMERS_CHECK_INTEVAL = 0.25

enum HintShowState {
  NOT_MATCH = 0
  SHOW_HINT = 1
  DISABLE   = 2
}

let activeHints = persist("activeHints", @() [])

let shipFireControlPos = persist("shipFireControlPos", @() {
  x = 0
  y = 0
})

local nest = null
local guiScene = null
local hintIdx = 0 
local isSubscribed = false

let animatedRemovedHints = [] 
let timers = DaguiSceneTimers(TIMERS_CHECK_INTEVAL, "hudHintsTimers")
let lastShowedTimeDict = {} 
let delayedShowTimers = {} 
let filterHints = {} 
let nestList = []

function updateWidgets() {
  handlersManager.updateWidgets()
}

function isHintDisabledByUnitTags(hint) {
  if (hint.disabledByUnitTags == null)
    return false

  let unit = getPlayerCurUnit()
  if (unit == null)
    return false

  return hint.disabledByUnitTags.findvalue(@(v) unit.tags.contains(v)) != null
}

let findActiveHintFromSameGroup = @(hint)
  activeHints.findvalue(@(hintData) hint.hintType.isSameReplaceGroup(hintData.hint, hint))

function isHintNestEmpty(hint) {
  return activeHints.findvalue(
    @(hintData) hintData.hint != hint && hintData.hint.hintType == hint.hintType) == null
}

function addToList(hint, eventData) {
  activeHints.append({
    hint = hint
    hintObj = null
    addTime = get_time_msec()
    eventData = eventData
    lifeTimerWeak = null
  })

  let addedHint = activeHints?[activeHints.len() - 1]
  return addedHint
}

function removeFromList(hintData) {
  let idx = activeHints.findindex(@(item) item == hintData)
  if (idx != null)
    activeHints.remove(idx)
}

function getUidForSeenCount(hint, e) {
  if (e?.conditionSeenCountType == null)
    return hint.uid
  return (hint.uid << 14) | e.conditionSeenCountType
}

function updatePosHudHintBlock() {
  if (!(nest?.isValid() ?? false))
    return

  let hintBlockObj = nest.findObject("hintBlock")
  if (!(hintBlockObj?.isValid() ?? false))
    return

  let hudUnitType = getHudUnitType()
  let isTank = hudUnitType == HUD_UNIT_TYPE.TANK
  let isShip = hudUnitType == HUD_UNIT_TYPE.SHIP
  let isAir = hudUnitType == HUD_UNIT_TYPE.AIRCRAFT
   || hudUnitType == HUD_UNIT_TYPE.HUMAN_DRONE
  let isHeli = hudUnitType == HUD_UNIT_TYPE.HELICOPTER
   || hudUnitType == HUD_UNIT_TYPE.HUMAN_DRONE_HELI

  local posY = "ph - h - @hudActionBarItemHeight"
  if (isShip) {
    posY = $"{shipFireControlPos.y} - 1@bhHud - h"
  } else if (isTank) {
    posY = "ph - h - @hudActionBarItemHeight - @tankGunsAmmoBlockHeight"
  } else if (isAir || isHeli) {
    if (isVisualHudAirWeaponSelectorOpened())
      posY = $"ph - h - 1@awsHeight"
  }

  hintBlockObj.pos = $"0.5pw - 0.5w, {posY}"
  guiScene.applyPendingChanges(false)
}

function onUpdateShipFireControlPanel(value) {
  shipFireControlPos.__update({ x = value.pos[0], y = value.pos[1] })
  if (!(nest?.isValid() ?? false))
    return
  updatePosHudHintBlock()
  updateWidgets() 
}


function findSceneObjects() {
  let scene = nest.findObject("hud_hints_nest")
  if (!scene?.isValid())
    return false

  guiScene = scene.getScene()
  timers.setUpdaterObj(scene)
  return true
}

function changeMissionHintsPosition(value) {
  if (!(nest?.isValid() ?? false))
    return
  let mission_hints = nest.findObject("mission_action_hints_holder")
  if (!(mission_hints?.isValid() ?? false))
    return

  mission_hints["width"] = "pw"
  let isShip = [HUD_UNIT_TYPE.SHIP, HUD_UNIT_TYPE.SHIP_EX].contains(getHudUnitType())
  if(!isShip) {
    mission_hints["left"] = ""
    return
  }
  let dmgPanelWidth = value?.size[0] ?? 0
  let left = $"{dmgPanelWidth} + 0.015@shHud"
  mission_hints["left"] = $"{left} - 1/6@rwHud"
  let map_left = getHudElementAabb("map")?.pos[0] ?? 0
  if(map_left > 0)
    mission_hints["width"] = $"{map_left - dmgPanelWidth} - 0.03@shHud - 1@bwHud"
}

function changeCommonHintsPosition(dmgPanelAabb) {
  if (!(nest?.isValid() ?? false))
    return
  let common_priority_hints = nest.findObject("common_priority_hints_holder")
  if (!(common_priority_hints?.isValid() ?? false))
    return

  let hintContainerScreenBorder = to_pixels($"1/6@rwHud + 1@bwHud")
  let screenWidth = to_pixels($"sw")
  let screenCenterX = screenWidth / 2

  let {pos = [0, 0], size = [0, 0]} = dmgPanelAabb
  let dmgPanelRightSide = size[0] + pos[0]
  let dmgPanelLeftSide = pos[0]
  let dmgPanelOffset = dmgPanelLeftSide < screenCenterX
    ? dmgPanelRightSide
    : (screenWidth - dmgPanelLeftSide)

  let mapAabb = getHudElementAabb("map")
  let mapLeft = mapAabb?.pos[0] ?? 0
  let mapWidth = mapAabb?.size[0] ?? 0
  let mapOffset = mapLeft < screenCenterX
    ? mapLeft + mapWidth
    : screenWidth - mapLeft

  let maxOffset = max(dmgPanelOffset, mapOffset, hintContainerScreenBorder)
  common_priority_hints["left"] = $"{maxOffset} - {hintContainerScreenBorder} + 0.05@shHud"
  common_priority_hints["width"] = $"sw - {maxOffset}*2 - 0.1@shHud"
}

function updateMissionHintStyle() {
  let mission_hints = nest.findObject("mission_action_hints_holder")
  if (!(mission_hints?.isValid() ?? false))
    return

  let isShip = [HUD_UNIT_TYPE.SHIP, HUD_UNIT_TYPE.SHIP_EX].contains(getHudUnitType())
  mission_hints["hintSizeStyle"] = isShip ? "action" : "common"
}

function hideSameHintsIfExist(hintToHideId) {
  let invalidNestIdxs = []
  foreach (idx, nestObj in nestList) {
    if (!nestObj.isValid()) {
      invalidNestIdxs.append(idx)
      continue
    }
    let hintToHide = nestObj.findObject(hintToHideId)
    if (!hintToHide?.isValid())
      continue
    guiScene.destroyElement(hintToHide)
  }

  for (local idx = invalidNestIdxs.len() - 1; idx >= 0; idx--)
    nestList.remove(invalidNestIdxs[idx])
}

function hideHint(hintData, isInstant) {
  let hintObject = hintData.hintObj
  if (!checkObj(hintObject))
    return

  let needFinalizeRemove = hintData.hint.hideHint(hintObject, isInstant)
  if (needFinalizeRemove)
    animatedRemovedHints.append(clone hintData)

  if (!needFinalizeRemove) {
    hideSameHintsIfExist(hintData.hintObjId)
  }
}


function removeHint(hintData, isInstant) {
  hideHint(hintData, isInstant)
  if (hintData.hint.selfRemove && hintData.lifeTimerWeak)
    timers.removeTimer(hintData.lifeTimerWeak)
  removeFromList(hintData)
  deferOnce(updateWidgets)
}

function checkRemovedHints(hint) {
  for (local i = animatedRemovedHints.len() - 1; i >= 0; i--) {
    let hintData = animatedRemovedHints[i]
    if (checkObj(hintData.hintObj)) {
      if (!hint.hintType.isSameReplaceGroup(hintData.hint, hint))
        continue
      hintData.hint.hideHint(hintData.hintObj, true)
    }
    animatedRemovedHints.remove(i)
  }
}

function removeSingleInNestHints(hint) {
  foreach (hintData in activeHints)
    if (hintData.hint != hint &&
        hintData.hint.hintType == hint.hintType &&
        hintData.hint.isSingleInNest)
      removeHint(hintData, true)
}

function setCoutdownTimer(hintData) {
  if (!hintData.hint.selfRemove)
    return

  let hintObj = hintData.hintObj
  if (!checkObj(hintObj))
    return

  hintData.secondsUpdater <- SecondsUpdater(hintObj, function (obj, _params) {
    let textObj = obj.findObject("time_text")
    if (!checkObj(textObj))
      return false

    let lifeTime = hintData.hint.getTimerTotalTimeSec(hintData.eventData)
    let offset = hintData.hint.getTimerCurrentTimeSec(hintData.eventData, hintData.addTime)
    let timeLeft = (lifeTime - offset + 0.5).tointeger()

    if (timeLeft < 0)
      return true

    textObj.setValue(timeLeft.tostring())
    return false
  })
}

function checkHintByFilter(hintData) {
  let filter = filterHints[nest.id]
  if (!filter.len())
    return true
  foreach(name in filter) {
    if (!hintData.eventData?[name])
      return false
  }
  return true
}

function showHint(hintData, renewCurrent = false) {
  if (!checkObj(nest) || !guiScene)
    return

  let hintNestObj = nest.findObject(hintData.hint.getHintNestId())
  if (!checkObj(hintNestObj))
    return

  if (!checkHintByFilter(hintData))
    return

  checkRemovedHints(hintData.hint) 
  removeSingleInNestHints(hintData.hint)

  ++hintIdx
  let id = renewCurrent ? hintData.hintObj.id : $"{hintData.hint.name}{hintIdx}"
  hintData.hintObjId <- id
  let markup = hintData.hint.buildMarkup(hintData.eventData, id)
  guiScene.appendWithBlk(hintNestObj, markup, markup.len(), null)
  hintData.hintObj = hintNestObj.findObject(id)
  setCoutdownTimer(hintData)

  let uid = getUidForSeenCount(hintData.hint, hintData.eventData)
  lastShowedTimeDict[uid] <- get_time_msec()
  increaseHintShowCount(uid)
  updateWidgets()
}

function removeDelayedShowTimer(hint) {
  if (delayedShowTimers?[hint.name]) {
    timers.removeTimer(delayedShowTimers[hint.name])
    delayedShowTimers.$rawdelete(hint.name)
  }
}

function updateHintInList(hintData, eventData) {
  hintData.eventData = eventData
  hintData.addTime = get_time_msec()
}

function removeHintByTimer(hintData) {
  hideHint(hintData, false)
  removeFromList(hintData)
  removeDelayedShowTimer(hintData.hint)
}

function updateRemoveTimer(hintData) {
  if (!hintData.hint.selfRemove)
    return

  let lifeTime = hintData.hint.getLifeTime(hintData.eventData)
  if (hintData.lifeTimerWeak) {
    if (lifeTime <= 0)
      timers.removeTimer(hintData.lifeTimerWeak)
    else
      timers.setTimerTime(hintData.lifeTimerWeak, lifeTime)
    return
  }

  if (lifeTime <= 0)
    return

  hintData.lifeTimerWeak = timers.addTimer(lifeTime, @() removeHintByTimer(hintData)).weakref()
}

function updateHint(hintData) {
  updateRemoveTimer(hintData)

  let hintObj = hintData.hintObj
  if (!checkObj(hintObj))
    return showHint(hintData)
  if (!nest.findObject(hintData.hintObj?.id))
    return showHint(hintData, true)
  setCoutdownTimer(hintData)

  let timeBarObj = hintObj.findObject("time_bar")
  if (checkObj(timeBarObj)) {
    let totaltime = hintData.hint.getTimerTotalTimeSec(hintData.eventData)
    let currentTime = hintData.hint.getTimerCurrentTimeSec(hintData.eventData, hintData.addTime)
    g_time_bar.setPeriod(timeBarObj, totaltime)
    g_time_bar.setCurrentTime(timeBarObj, currentTime)
  }
}

function checkHintInterval(hint) {
  let interval = hint.getTimeInterval()
  if (interval == HINT_INTERVAL.ALWAYS_VISIBLE)
    return HintShowState.SHOW_HINT
  else if (interval == HINT_INTERVAL.HIDDEN)
    return HintShowState.DISABLE

  if (!(hint.uid in lastShowedTimeDict)) {
    return HintShowState.SHOW_HINT
  }
  else {
    let ageSec = (get_time_msec() - lastShowedTimeDict[hint.uid]) * 0.001
    return ageSec >= interval ? HintShowState.SHOW_HINT : HintShowState.NOT_MATCH
  }

  return HintShowState.NOT_MATCH
}

function isHintShowCountExceeded(hint, params = {}) {
  let {eventData = null, dontWriteLog = false} = params
  if ( hint.uid == -1 )
    return false
  let uid = getUidForSeenCount(hint, eventData)
  let seenCount = getHintSeenCount(uid)

  if ( !dontWriteLog && (hint.uid >= 0 || hint.totalCount > 0 || hint.totalCountByCondition > 0))
    log(" ".concat(
      $"Hints: {hint.showEvent == "" ? "_" : hint.showEvent}",
      $"uid = {hint.uid}",
      eventData?.conditionSeenCountType != null
        ? $"conditionSeenCountType = {eventData.conditionSeenCountType}"
        : "",
      $"totalCount = {hint.totalCount}",
      $"totalCountByCondition = {hint.totalCountByCondition}",
      $"showedCount = {seenCount}"
    ))

  let isCountExced = hint.totalCount > 0 && seenCount >= hint.totalCount
  let isCountByCondExceed = hint.totalCountByCondition > 0 && seenCount >= hint.totalCountByCondition
  return isCountExced || isCountByCondExceed
}

function isHintShowAllowed(eventName, eventData, params = null) {
  let hint = getHintByShowEvent(eventName)
  if (!hint)
    return false

  if (isHintShowCountExceeded(hint, { eventData, dontWriteLog = true }))
    return false

  if (params?.needCheckCountOnly)
    return true

  if (isHintDisabledByUnitTags(hint))
    return false

  if (eventData && !hint.isCurrent(eventData, false))
    return false

  let res = checkHintInterval(hint)
  if (res != HintShowState.SHOW_HINT) {
    return false
  }

  if (hint.isSingleInNest && !isHintNestEmpty(hint))
    return false

  if (eventData) {
    local hintData = findActiveHintFromSameGroup(hint)
    if (hintData)
      if (!hint.hintType.isReplaceable(hint, eventData, hintData.hint, hintData.eventData))
        return false
  }

  return true
}

function removeAllHints(hintFilterField = "isHideOnDeath") {
  let hints =
    hintFilterField == "isHideOnDeath" ? activeHints.filter(@(hintData) hintData.hint.isHideOnDeath(hintData.eventData))
    : hintFilterField != "" ? activeHints.filter(@(hintData) hintData.hint[hintFilterField])
    : activeHints.filter(@(_hintData) true)

  foreach (hintData in hints)
    removeHint(hintData, true)
}

function onLocalPlayerDead(_) {
  removeAllHints()
}

function onMissionResult(_) {
  removeAllHints("isHideOnMissionEnd")
}

function onWatchedHeroChanged(_) {
  removeAllHints("isHideOnWatchedHeroChanged")
}

function restoreAllHints() {
  updateMissionHintStyle()
  foreach (hintData in activeHints)
    updateHint(hintData)
}

function hudHintsManagerReinit(v_nest) {
  nest = v_nest
  if (!findSceneObjects())
    return
  restoreAllHints()
  updatePosHudHintBlock()
  changeMissionHintsPosition(dmPanelStatesAabb.get())
  changeCommonHintsPosition(dmPanelStatesAabb.get())
}

function onShowEvent(hint, eventData) {
  if (!hint.isCurrent(eventData, false))
    return
  if (hint.isHideOnDeath(eventData) && !isPlayerAlive.get())
    return
  let res = checkHintInterval(hint)
  if (res == HintShowState.DISABLE) {
    if (hint.secondsOfForgetting == 0)
      disable_hint(hint.mask)
    return
  }
  else if (res == HintShowState.NOT_MATCH)
    return

  if (hint.isSingleInNest && !isHintNestEmpty(hint))
    return

  local hintData = findActiveHintFromSameGroup(hint)

  if (hintData)
    if (!hint.hintType.isReplaceable(hint, eventData, hintData.hint, hintData.eventData))
      return
    else if (hint == hintData.hint) {
      hideHint(hintData, true)
      updateHintInList(hintData, eventData)
    }
    else {
      removeHint(hintData, true)
      hintData = null
    }

  if (!hintData)
    hintData = addToList(hint, eventData)

  showHint(hintData)
  updateHint(hintData)
}

function showDelayed(hint, eventData) {
  if (hint.delayTime <= 0)
    return
  if (delayedShowTimers?[hint.name])
    return

  delayedShowTimers[hint.name] <- timers.addTimer(hint.delayTime, Callback(function() {
    if (delayedShowTimers?[hint.name])
      onShowEvent(hint, eventData)
  })).weakref()
}

function subscribe() {
  if (isSubscribed)
    return
  isSubscribed = true

  g_hud_event_manager.subscribe("LocalPlayerDead", onLocalPlayerDead)
  g_hud_event_manager.subscribe("MissionResult", onMissionResult)
  g_hud_event_manager.subscribe("WatchedHeroChanged", onWatchedHeroChanged)

  foreach (hintType in g_hud_hints.types) {
    let isExceeded = isHintShowCountExceeded(hintType, { dontWriteLog=true })
    if (!hintType.isEnabled() || (hintType.totalCount > 0 && isExceeded && hintType.secondsOfForgetting == 0)) {
      log($"Hints: {(hintType?.showEvent ?? "_")} is disabled")
      continue
    }

    let hint = hintType
    if (isHintShowCountExceeded(hint) && hint.secondsOfForgetting > 0) {
      let currentSecond = get_charserver_time_sec()
      let secondsAfterLastShow = currentSecond - getHintSeenTime(hint.uid)
      if (secondsAfterLastShow > hint.secondsOfForgetting) {
        resetHintShowCount(hint.uid)
      }
    }

    if (hint.showEvent != "")
      g_hud_event_manager.subscribe(hint.showEvent, function (eventData) {
        let hintUid = getUidForSeenCount(hint, eventData)
        if (eventData?.hidden) {
          increaseHintShowCount(hintUid)
          return
        }

        if (isHintShowCountExceeded(hint, { eventData })) {
          return
        }

        if (isHintDisabledByUnitTags(hint))
          return

        if (hint.delayTime > 0)
          showDelayed(hint, eventData)
        else
          onShowEvent(hint, eventData)
      })

    if (!isNull(hint.hideEvent))
      g_hud_event_manager.subscribe(hint.hideEvent, function (eventData) {
        if (hint?.hideOnDeath && !isPlayerAlive.get())
          return
        if (!hint.isCurrent(eventData, true))
          return

        removeDelayedShowTimer(hint)

        let hintData = findActiveHintFromSameGroup(hint)
        if (!hintData)
          return
        removeHint(hintData, hintData.hint.isInstantHide(eventData))
      })

    if (hint.toggleHint != null) {
      for (local i = 0; i < hint.toggleHint.len(); i++) {
        g_hud_event_manager.subscribe(hint.toggleHint[i], function (eventData) {
          if (eventData.isVisible) {
            let hintUid = getUidForSeenCount(hint, eventData)
            if (eventData?.hidden) {
              increaseHintShowCount(hintUid)
              return
            }

            if (isHintShowCountExceeded(hint, { eventData })) {
              return
            }

            if (isHintDisabledByUnitTags(hint))
              return

            if (hint.delayTime > 0)
              showDelayed(hint, eventData)
            else
              onShowEvent(hint, eventData)
          }
          else {
            if (!hint.isCurrent(eventData, true))
              return

            removeDelayedShowTimer(hint)

            let hintData = findActiveHintFromSameGroup(hint)
            if (!hintData)
              return
            removeHint(hintData, hintData.hint.isInstantHide(eventData))
          }
        })
      }
    }

    if (hint.updateCbs)
      foreach (eventName, func in hint.updateCbs) {
        let cbFunc = func
        g_hud_event_manager.subscribe(eventName, function (eventData) {
          if (!hint.isCurrent(eventData, false))
            return

          let hintData = findActiveHintFromSameGroup(hint)
          let needUpdate = cbFunc.call(hint, hintData, eventData)
          if (hintData && needUpdate)
            updateHint(hintData)
        })
      }
  }
}

function hudHintsManagerInit(v_nest, params = {}) {
  let { paramsToCheck = [] } = params
  subscribe()
  if (!checkObj(v_nest))
    return
  nest = v_nest
  nestList.append(v_nest)
  filterHints[nest.id] <- paramsToCheck

  if (!findSceneObjects())
    return
  restoreAllHints()
  updatePosHudHintBlock()
  changeMissionHintsPosition(dmPanelStatesAabb.get())
  changeCommonHintsPosition(dmPanelStatesAabb.get())
}

let isHintWillBeShown = @(event_name) isHintShowAllowed(event_name, null, {needCheckCountOnly = true})

eventbus_subscribe("update_ship_fire_control_panel", @(value) onUpdateShipFireControlPanel(value))

addListenersWithoutEnv({
  function ScriptsReloaded(_) {
    foreach (hintData in activeHints)
      hintData.hint = g_hud_hints.getByName(hintData.hint.name)
  }

  function LoadingStateChange(_) {
    if (!isInFlight()) {
      activeHints.clear()
      timers.reset()
      isSubscribed = false
      filterHints.clear()
      nestList.clear()
    }
    else {
      let hintOptionsBlk = DataBlock()
      foreach (hint in g_hud_hints.types)
        hint.updateHintOptionsBlk(hintOptionsBlk)
      set_hint_options_by_blk(hintOptionsBlk)
      let gm = get_game_mode()
      set_option_hint_enabled(gm != GM_TRAINING)
    }
    animatedRemovedHints.clear()
  }

  HudEventManagerReset = @(_) isSubscribed = false
  ChangedShowActionBar = @(_) updatePosHudHintBlock()
}, g_listener_priority.DEFAULT_HANDLER)

dmPanelStatesAabb.subscribe(function(value) {
  changeMissionHintsPosition(value)
  changeCommonHintsPosition(value)
})

register_command(@(hintName) isHintShowAllowed(hintName, null), "smart_hints.isHintShowAllowed")

return {
  hudHintsManagerInit
  hudHintsManagerReinit
  isHintWillBeShown
}