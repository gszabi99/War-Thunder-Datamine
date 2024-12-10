from "%scripts/dagui_natives.nut" import set_hint_options_by_blk, disable_hint
from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HINT_INTERVAL
from "%scripts/timeBar.nut" import g_time_bar

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { get_charserver_time_sec } = require("chard")
let { subscribe_handler, add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
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

const TIMERS_CHECK_INTEVAL = 0.25

enum HintShowState {
  NOT_MATCH = 0
  SHOW_HINT = 1
  DISABLE   = 2
}

function isHintDisabledByUnitTags(hint) {
  if (hint.disabledByUnitTags == null)
    return false

  let unit = getPlayerCurUnit()
  if (unit == null)
    return false

  return hint.disabledByUnitTags.findvalue(@(v) unit.tags.contains(v)) != null
}

let activeHints = persist("activeHints", @() [])

let shipFireControlPos = persist("shipFireControlPos", @() {
  x = 0
  y = 0
})

let g_hud_hints_manager = {
  nest = null
  scene = null
  guiScene = null

  activeHints = activeHints
  animatedRemovedHints = [] //hints set to remove animation. to be able instant finish them

  timers = DaguiSceneTimers(TIMERS_CHECK_INTEVAL, "hudHintsTimers")

  hintIdx = 0 //used only for unique hint id

  lastShowedTimeDict = {} // key = uid, value = lastShowedTime

  delayedShowTimers = {} // key = hint.name, value = timer

  function init(v_nest) {
    this.subscribe()
    if (!checkObj(v_nest))
      return
    this.nest = v_nest
    if (!this.findSceneObjects())
      return
    this.restoreAllHints()
    this.updatePosHudHintBlock()
    this.changeMissionHintsPosition(dmPanelStatesAabb.value)
    this.changeCommonHintsPosition(dmPanelStatesAabb.value)
  }

  function reinit() {
    if (!this.findSceneObjects())
      return
    this.restoreAllHints()
    this.updatePosHudHintBlock()
    this.changeMissionHintsPosition(dmPanelStatesAabb.value)
    this.changeCommonHintsPosition(dmPanelStatesAabb.value)
  }

  function onEventLoadingStateChange(_p) {
    if (!isInFlight()) {
      this.activeHints.clear()
      this.timers.reset()
    }
    else {
      let hintOptionsBlk = DataBlock()
      foreach (hint in g_hud_hints.types)
        hint.updateHintOptionsBlk(hintOptionsBlk)
      set_hint_options_by_blk(hintOptionsBlk)
    }
    this.animatedRemovedHints.clear()
  }

  function removeAllHints(hintFilterField = "isHideOnDeath") {
    let hints = this.activeHints.filter(@(hintData) hintData.hint[hintFilterField])
    foreach (hintData in hints)
      this.removeHint(hintData, true)
  }

    function onLocalPlayerDead() {
    this.removeAllHints()
  }

  function onWatchedHeroChanged() {
    this.removeAllHints("isHideOnWatchedHeroChanged")
  }

  //return false if can't
  function findSceneObjects() {
    this.scene = this.nest.findObject("hud_hints_nest")
    if (!checkObj(this.scene))
      return false

    this.guiScene = this.scene.getScene()
    this.timers.setUpdaterObj(this.scene)
    return true
  }

  function restoreAllHints() {
    this.updateMissionHintStyle()
    foreach (hintData in this.activeHints)
      this.updateHint(hintData)
  }

  function changeCommonHintsPosition(value) {
    if (!(this.nest?.isValid() ?? false))
      return
    let common_priority_hints = this.nest.findObject("common_priority_hints_holder")
    if (!(common_priority_hints?.isValid() ?? false))
      return

    let hintContainerScreenBorder = to_pixels($"1/6@rwHud + 1@bwHud")
    let screenWidth = to_pixels($"sw")

    let {pos = [0, 0], size = [0, 0]} = value
    local dmgPanelRightSide = size[0] + pos[0]// its global coords
    if(dmgPanelRightSide == 0)
      dmgPanelRightSide = hintContainerScreenBorder

    local leftOffset = dmgPanelRightSide

    let mapLeft = getHudElementAabb("map")?.pos[0] ?? screenWidth
    local rightOffset = screenWidth - mapLeft

    let maxOffset = max(leftOffset, rightOffset)

    common_priority_hints["left"] = $"{maxOffset} - {hintContainerScreenBorder} + 0.05@shHud"
    common_priority_hints["width"] = $"sw - {maxOffset}*2 - 0.1@shHud"
  }

  function updateMissionHintStyle() {
    let mission_hints = this.nest.findObject("mission_action_hints_holder")
    if (!(mission_hints?.isValid() ?? false))
      return

    let isShip = [HUD_UNIT_TYPE.SHIP, HUD_UNIT_TYPE.SHIP_EX].contains(getHudUnitType())
    mission_hints["hintSizeStyle"] = isShip ? "action" : "common"
  }

  function changeMissionHintsPosition(value) {
    if (!(this.nest?.isValid() ?? false))
      return
    let mission_hints = this.nest.findObject("mission_action_hints_holder")
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

  function updatePosHudHintBlock() {
    if (!(this.nest?.isValid() ?? false))
      return

    let hintBlockObj = this.nest.findObject("hintBlock")
    if (!(hintBlockObj?.isValid() ?? false))
      return

    let isTank = getHudUnitType() == HUD_UNIT_TYPE.TANK
    let isShip = getHudUnitType() == HUD_UNIT_TYPE.SHIP
    let isAir = getHudUnitType() == HUD_UNIT_TYPE.AIRCRAFT
    let isHeli = getHudUnitType() == HUD_UNIT_TYPE.HELICOPTER

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
    this.guiScene.applyPendingChanges(false)
  }

  function subscribe() {
    g_hud_event_manager.subscribe("LocalPlayerDead", function (_eventData) {
      this.onLocalPlayerDead()
    }, this)

    g_hud_event_manager.subscribe("WatchedHeroChanged", function (_eventData) {
      this.onWatchedHeroChanged()
    }, this)

    foreach (hintType in g_hud_hints.types) {
      let isExceeded = this.isHintShowCountExceeded(hintType, { dontWriteLog=true })
      if (!hintType.isEnabled() || (hintType.totalCount > 0 && isExceeded && hintType.secondsOfForgetting == 0)) {
        log($"Hints: {(hintType?.showEvent ?? "_")} is disabled")
        continue
      }

      let hint = hintType
      if (this.isHintShowCountExceeded(hint) && hint.secondsOfForgetting > 0) {
        let currentSecond = get_charserver_time_sec()
        let secondsAfterLastShow = currentSecond - getHintSeenTime(hint.uid)
        if (secondsAfterLastShow > hint.secondsOfForgetting) {
          resetHintShowCount(hint.uid)
        }
      }

      if (hint.showEvent != "")
        g_hud_event_manager.subscribe(hint.showEvent, function (eventData) {

          let hintUid = this.getUidForSeenCount(hint, eventData)
          if (eventData?.hidden) {
            increaseHintShowCount(hintUid)
            return
          }

          if (this.isHintShowCountExceeded(hint, { eventData })) {
            return
          }

          if (isHintDisabledByUnitTags(hint))
            return

          if (hint.delayTime > 0)
            this.showDelayed(hint, eventData)
          else
            this.onShowEvent(hint, eventData)
        }, this)

      if (!u.isNull(hint.hideEvent))
        g_hud_event_manager.subscribe(hint.hideEvent, function (eventData) {
          if (!hint.isCurrent(eventData, true))
            return

          this.removeDelayedShowTimer(hint)

          let hintData = this.findActiveHintFromSameGroup(hint)
          if (!hintData)
            return
          this.removeHint(hintData, hintData.hint.isInstantHide(eventData))
        }, this)

      if (hint.toggleHint != null) {
        for (local i = 0; i < hint.toggleHint.len(); i++) {
          g_hud_event_manager.subscribe(hint.toggleHint[i], function (eventData) {
            if (eventData.isVisible) {
              let hintUid = this.getUidForSeenCount(hint, eventData)
              if (eventData?.hidden) {
                increaseHintShowCount(hintUid)
                return
              }

              if (this.isHintShowCountExceeded(hint, { eventData })) {
                return
              }

              if (isHintDisabledByUnitTags(hint))
                return

              if (hint.delayTime > 0)
                this.showDelayed(hint, eventData)
              else
                this.onShowEvent(hint, eventData)
            }
            else {
              if (!hint.isCurrent(eventData, true))
                return

              this.removeDelayedShowTimer(hint)

              let hintData = this.findActiveHintFromSameGroup(hint)
              if (!hintData)
                return
              this.removeHint(hintData, hintData.hint.isInstantHide(eventData))
            }
          }, this)
        }
      }

      if (hint.updateCbs)
        foreach (eventName, func in hint.updateCbs) {
          let cbFunc = func
          g_hud_event_manager.subscribe(eventName, function (eventData) {
            if (!hint.isCurrent(eventData, false))
              return

            let hintData = this.findActiveHintFromSameGroup(hint)
            let needUpdate = cbFunc.call(hint, hintData, eventData)
            if (hintData && needUpdate)
              this.updateHint(hintData)
          }, this)
        }
    }
  }

  function findActiveHintFromSameGroup(hint) {
    return u.search(this.activeHints, @(hintData) hint.hintType.isSameReplaceGroup(hintData.hint, hint))
  }

  function addToList(hint, eventData) {
    this.activeHints.append({
      hint = hint
      hintObj = null
      addTime = get_time_msec()
      eventData = eventData
      lifeTimerWeak = null
    })

    let addedHint = this.activeHints?[this.activeHints.len() - 1]
    return addedHint
  }

  function updateRemoveTimer(hintData) {
    if (!hintData.hint.selfRemove)
      return

    let lifeTime = hintData.hint.getLifeTime(hintData.eventData)
    if (hintData.lifeTimerWeak) {
      if (lifeTime <= 0)
        this.timers.removeTimer(hintData.lifeTimerWeak)
      else
        this.timers.setTimerTime(hintData.lifeTimerWeak, lifeTime)
      return
    }

    if (lifeTime <= 0)
      return

    hintData.lifeTimerWeak = this.timers.addTimer(lifeTime, Callback(function () {
      this.hideHint(hintData, false)
      this.removeFromList(hintData)
      this.removeDelayedShowTimer(hintData.hint)
    }, this)).weakref()
  }

  function removeDelayedShowTimer(hint) {
    if (this.delayedShowTimers?[hint.name]) {
      this.timers.removeTimer(this.delayedShowTimers[hint.name])
      this.delayedShowTimers.$rawdelete(hint.name)
    }
  }

  function updateHintInList(hintData, eventData) {
    hintData.eventData = eventData
    hintData.addTime = get_time_msec()
  }

  function removeFromList(hintData) {
    let idx = this.activeHints.findindex(@(item) item == hintData)
    if (idx != null)
      this.activeHints.remove(idx)
  }

  function isHintShowAllowed(eventName, eventData, params = null) {
    let hint = getHintByShowEvent(eventName)
    if (!hint)
      return false

    if (this.isHintShowCountExceeded(hint, { eventData, dontWriteLog = true }))
      return false

    if (params?.needCheckCountOnly)
      return true

    if (isHintDisabledByUnitTags(hint))
      return false

    if (eventData && !hint.isCurrent(eventData, false))
      return false

    let res = this.checkHintInterval(hint)
    if (res != HintShowState.SHOW_HINT) {
      return false
    }

    if (hint.isSingleInNest && !this.isHintNestEmpty(hint))
      return false

    if (eventData) {
      local hintData = this.findActiveHintFromSameGroup(hint)
      if (hintData)
        if (!hint.hintType.isReplaceable(hint, eventData, hintData.hint, hintData.eventData))
          return false
    }

    return true
  }


  function onShowEvent(hint, eventData) {
    if (!hint.isCurrent(eventData, false))
      return

    let res = this.checkHintInterval(hint)
    if (res == HintShowState.DISABLE) {
      if (hint.secondsOfForgetting == 0)
        disable_hint(hint.mask)
      return
    }
    else if (res == HintShowState.NOT_MATCH)
      return

    if (hint.isSingleInNest && !this.isHintNestEmpty(hint))
      return

    local hintData = this.findActiveHintFromSameGroup(hint)

    if (hintData)
      if (!hint.hintType.isReplaceable(hint, eventData, hintData.hint, hintData.eventData))
        return
      else if (hint == hintData.hint) {
        this.hideHint(hintData, true)
        this.updateHintInList(hintData, eventData)
      }
      else {
        this.removeHint(hintData, true)
        hintData = null
      }

    if (!hintData)
      hintData = this.addToList(hint, eventData)

    this.showHint(hintData)
    this.updateHint(hintData)
  }

  function isHintNestEmpty(hint) {
    return !u.search(this.activeHints, @(hintData)
      hintData.hint != hint && hintData.hint.hintType == hint.hintType)
  }

  function showHint(hintData) {
    if (!checkObj(this.nest) || !this.guiScene)
      return

    let hintNestObj = this.nest.findObject(hintData.hint.getHintNestId())
    if (!checkObj(hintNestObj))
      return

    this.checkRemovedHints(hintData.hint) //remove hints with not finished animation if needed
    this.removeSingleInNestHints(hintData.hint)

    let id = hintData.hint.name + (++this.hintIdx)
    let markup = hintData.hint.buildMarkup(hintData.eventData, id)
    this.guiScene.appendWithBlk(hintNestObj, markup, markup.len(), null)
    hintData.hintObj = hintNestObj.findObject(id)
    this.setCoutdownTimer(hintData)

    let uid = this.getUidForSeenCount(hintData.hint, hintData.eventData)
    this.lastShowedTimeDict[uid] <- get_time_msec()
    increaseHintShowCount(uid)
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

  function hideHint(hintData, isInstant) {
    let hintObject = hintData.hintObj
    if (!checkObj(hintObject))
      return

    let needFinalizeRemove = hintData.hint.hideHint(hintObject, isInstant)
    if (needFinalizeRemove)
      this.animatedRemovedHints.append(clone hintData)
  }

  function removeHint(hintData, isInstant) {
    this.hideHint(hintData, isInstant)
    if (hintData.hint.selfRemove && hintData.lifeTimerWeak)
      this.timers.removeTimer(hintData.lifeTimerWeak)
    this.removeFromList(hintData)
  }

  function checkRemovedHints(hint) {
    for (local i = this.animatedRemovedHints.len() - 1; i >= 0; i--) {
      let hintData = this.animatedRemovedHints[i]
      if (checkObj(hintData.hintObj)) {
        if (!hint.hintType.isSameReplaceGroup(hintData.hint, hint))
          continue
        hintData.hint.hideHint(hintData.hintObj, true)
      }
      this.animatedRemovedHints.remove(i)
    }
  }

  function removeSingleInNestHints(hint) {
    foreach (hintData in this.activeHints)
      if (hintData.hint != hint &&
          hintData.hint.hintType == hint.hintType &&
          hintData.hint.isSingleInNest)
        this.removeHint(hintData, true)
  }

  function updateHint(hintData) {
    this.updateRemoveTimer(hintData)

    let hintObj = hintData.hintObj
    if (!checkObj(hintObj))
      return this.showHint(hintData)

    this.setCoutdownTimer(hintData)

    let timeBarObj = hintObj.findObject("time_bar")
    if (checkObj(timeBarObj)) {
      let totaltime = hintData.hint.getTimerTotalTimeSec(hintData.eventData)
      let currentTime = hintData.hint.getTimerCurrentTimeSec(hintData.eventData, hintData.addTime)
      g_time_bar.setPeriod(timeBarObj, totaltime)
      g_time_bar.setCurrentTime(timeBarObj, currentTime)
    }
  }

  function onEventScriptsReloaded(_p) {
    foreach (hintData in this.activeHints)
      hintData.hint = g_hud_hints.getByName(hintData.hint.name)
  }


  function checkHintInterval(hint) {
    let interval = hint.getTimeInterval()
    if (interval == HINT_INTERVAL.ALWAYS_VISIBLE)
      return HintShowState.SHOW_HINT
    else if (interval == HINT_INTERVAL.HIDDEN)
      return HintShowState.DISABLE

    if (!(hint.uid in this.lastShowedTimeDict)) {
      return HintShowState.SHOW_HINT
    }
    else {
      let ageSec = (get_time_msec() - this.lastShowedTimeDict[hint.uid]) * 0.001
      return ageSec >= interval ? HintShowState.SHOW_HINT : HintShowState.NOT_MATCH
    }

    return HintShowState.NOT_MATCH
  }

  function getUidForSeenCount(hint, e) {
    if (e?.conditionSeenCountType == null)
      return hint.uid
    return (hint.uid << 14) | e.conditionSeenCountType
  }

  function isHintShowCountExceeded(hint, params = {}) {
    let {eventData = null, dontWriteLog = false} = params
    if ( hint.uid == -1 )
      return false
    let uid = this.getUidForSeenCount(hint, eventData)
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


  function showDelayed(hint, eventData) {
    if (hint.delayTime <= 0)
      return
    if (this.delayedShowTimers?[hint.name])
      return

    this.delayedShowTimers[hint.name] <- this.timers.addTimer(hint.delayTime, Callback(function () {
      if (this.delayedShowTimers?[hint.name])
        this.onShowEvent(hint, eventData)
    }, this)).weakref()
  }


  function onUpdateShipFireControlPanel(value) {
    shipFireControlPos.__update({ x = value.pos[0], y = value.pos[1] })
    if (!(this.nest?.isValid() ?? false))
      return
    this.updatePosHudHintBlock()
    handlersManager.updateWidgets() //update pos for SHIP_OBSTACLE_RF widget
  }
}

eventbus_subscribe("update_ship_fire_control_panel", @(value) g_hud_hints_manager.onUpdateShipFireControlPanel(value))
add_event_listener("ChangedShowActionBar", @(_value) g_hud_hints_manager.updatePosHudHintBlock())


dmPanelStatesAabb.subscribe(function(value) {
  g_hud_hints_manager.changeMissionHintsPosition(value)
  g_hud_hints_manager.changeCommonHintsPosition(value)
})

subscribe_handler(g_hud_hints_manager, g_listener_priority.DEFAULT_HANDLER)
register_command(@(hintName) g_hud_hints_manager.isHintShowAllowed(hintName, null), "smart_hints.isHintShowAllowed")
::g_hud_hints_manager <- g_hud_hints_manager