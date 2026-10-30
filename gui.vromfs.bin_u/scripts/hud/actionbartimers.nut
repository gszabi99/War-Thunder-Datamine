from "eventbus" import eventbus_subscribe
from "mission" import get_mission_time
from "dagor.workcycle" import resetTimeout
from "%scripts/hud/actionBarState.nut" import hasAAComplexMenuItem
from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%sqstd/string.nut" import startsWith
from "%scripts/dagui_library.nut" import *
from "%scripts/timeBar.nut" import g_time_bar

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { g_hud_live_stats } = require("%scripts/hud/hudLiveStats.nut")

const REPAIR_SHOW_TIME_THRESHOLD = 1.5
const TIMER_ANIM_WIDTH_END = 5

enum REARM_EVENT_STATE {
  REARMING = "rearming"
  NOT_IN_REARM = "notInRearm"
}

enum REARM_STATE {
  CHARGE = "charge"
  PAUSE = "pause"
  DISCHARGE = "discharge"
}

enum REPAIR_STATE {
  NOT_IN_REPAIR = "notInRepair"
  PREPARE = "prepareRepair"
  REPAIRING = "repairing"
  REPAIRING_AUTO = "repairingAuto"
}

function getRearmTimerCurrentTime(timer) {
  let { currentTime, receiveTime, rearmState } = timer
  if (rearmState == REARM_STATE.PAUSE)
    return currentTime
  let elapsed = get_mission_time() - receiveTime
  return rearmState == REARM_STATE.DISCHARGE ? currentTime - elapsed : currentTime + elapsed
}

function applyRearmTimerState(placeObj, timer) {
  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setDirectionForward(timebarObj)
  g_time_bar.setPeriod(timebarObj, timer.period)
  g_time_bar.setCurrentTime(timebarObj, getRearmTimerCurrentTime(timer))
  if (timer.rearmState == REARM_STATE.PAUSE)
    g_time_bar.pauseTimer(timebarObj)
  else if (timer.rearmState == REARM_STATE.DISCHARGE)
    g_time_bar.setDirectionBackward(timebarObj)
}

function applyFireTimerState(placeObj, timer) {
  let { time, totalTime, receiveTime } = timer
  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setDirectionBackward(timebarObj)
  g_time_bar.setPeriod(timebarObj, totalTime)
  g_time_bar.setCurrentTime(timebarObj, totalTime - time + get_mission_time() - receiveTime)
}

function applyRepairTimerState(placeObj, timer) {
  let { state, time, totalTime, receiveTime, isTracksOnly } = timer
  let isRepairing = state == REPAIR_STATE.REPAIRING || state == REPAIR_STATE.REPAIRING_AUTO
  let iconObj = placeObj.findObject("icon")
  iconObj["background-image"] = state == REPAIR_STATE.REPAIRING_AUTO && isTracksOnly
    ? "#ui/gameuiskin#track_state_indicator.svg"
    : "#ui/gameuiskin#icon_repair_in_progress.svg"
  iconObj["wink"] = isRepairing ? "no" : "fast"

  let timebarObj = placeObj.findObject("timer")
  if (isRepairing)
    g_time_bar.setDirectionForward(timebarObj)
  else
    g_time_bar.setDirectionBackward(timebarObj)
  g_time_bar.setPeriod(timebarObj, totalTime)
  g_time_bar.setCurrentTime(timebarObj, totalTime - time + get_mission_time() - receiveTime)
}

function applyCrewTimerState(placeObj, timer) {
  let { timeToTakePlace, totalTakePlaceTime, availableTime, timeToAvailable, receiveTime } = timer
  let elapsed = get_mission_time() - receiveTime
  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setDirectionForward(timebarObj)
  g_time_bar.setPeriod(timebarObj, totalTakePlaceTime)
  g_time_bar.setCurrentTime(timebarObj, totalTakePlaceTime - timeToTakePlace + elapsed)

  let availableTimerNestObj = placeObj.findObject("available_timer_nest")
  if (availableTimerNestObj == null)
    return
  let curTimeToAvailable = timeToAvailable - elapsed
  availableTimerNestObj.show(curTimeToAvailable > 0)
  if (curTimeToAvailable <= 0)
    return
  let availableTimebarObj = placeObj.findObject("available_timer")
  g_time_bar.setPeriod(availableTimebarObj, availableTime)
  g_time_bar.setCurrentTime(availableTimebarObj, availableTime - curTimeToAvailable)
}

function applyHealingTimerState(placeObj, timer) {
  let { totalHealingTime, currentHealingTime, receiveTime } = timer
  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setDirectionForward(timebarObj)
  g_time_bar.setPeriod(timebarObj, totalHealingTime)
  g_time_bar.setCurrentTime(timebarObj, currentHealingTime + get_mission_time() - receiveTime)
}

function applyMoveCooldownTimerState(placeObj, timer) {
  let { time, receiveTime } = timer
  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setDirectionBackward(timebarObj)
  g_time_bar.setPeriod(timebarObj, time)
  g_time_bar.setCurrentTime(timebarObj, get_mission_time() - receiveTime)
}

function applyBatteryTimerState(placeObj, timer) {
  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setPeriod(timebarObj, 0)
  g_time_bar.setValue(timebarObj, timer.charge / 100.0)
}

function applyBuildingTimerState(placeObj, timer) {
  let { remainingTime, totalTime, backward, pause, receiveTime } = timer
  let elapsed = pause ? 0 : get_mission_time() - receiveTime
  let curRemainingTime = backward ? remainingTime + elapsed : remainingTime - elapsed
  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setPeriod(timebarObj, totalTime)
  if (backward)
    g_time_bar.setDirectionBackward(timebarObj)
  else
    g_time_bar.setDirectionForward(timebarObj)
  g_time_bar.setCurrentTime(timebarObj, backward ? curRemainingTime : totalTime - curRemainingTime)
  if (pause)
    g_time_bar.pauseTimer(timebarObj)
}

let defaultTimerCfg = {
  timerIconSize = "actionBar"
  animWidthEnd = TIMER_ANIM_WIDTH_END
}

let timersCfg = [
  {
    id = "inextinguishable_fire_status"
    color = "#DD1111"
    icon = "#ui/gameuiskin#fire_indicator.svg"
    applyTimerStateFn = applyFireTimerState
  }
  {
    id = "repair_status"
    color = "#787878"
    icon = "#ui/gameuiskin#icon_repair_in_progress.svg"
    applyTimerStateFn = applyRepairTimerState
  }
  {
    id = "move_cooldown_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_repair_in_progress.svg"
    applyTimerStateFn = applyMoveCooldownTimerState
  }
  {
    id = "driver_status"
    color = "@crewTransferColor"
    icon = "#ui/gameuiskin#crew_driver_indicator.svg"
    applyTimerStateFn = applyCrewTimerState
  }
  {
    id = "gunner_status"
    color = "@crewTransferColor"
    icon = "#ui/gameuiskin#crew_gunner_indicator.svg"
    needSecondTimebar = true
    applyTimerStateFn = applyCrewTimerState
  }
  {
    id = "healing_status"
    color = "@white"
    icon = "#ui/gameuiskin#medic_status_indicator.svg"
    applyTimerStateFn = applyHealingTimerState
  }
  {
    id = "rearm_primary_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_weapons_in_progress.svg"
    applyTimerStateFn = applyRearmTimerState
  }
  {
    id = "rearm_secondary_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_weapons_in_progress.svg"
    applyTimerStateFn = applyRearmTimerState
  }
  {
    id = "rearm_rocket_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_rocket_in_progress.svg"
    applyTimerStateFn = applyRearmTimerState
  }
  {
    id = "rearm_smoke_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_smoke_screen_in_progress.svg"
    applyTimerStateFn = applyRearmTimerState
  }
  {
    id = "building_status"
    color = "#787878"
    icon = "#ui/gameuiskin#icon_building_in_progress.svg"
    applyTimerStateFn = applyBuildingTimerState
  }
  {
    id = "battery_status"
    color = "#DD1111"
    icon = "#ui/gameuiskin#icon_battery_in_progress.svg"
    applyTimerStateFn = applyBatteryTimerState
  }
]

let timersCfgById = timersCfg.reduce(function(res, cfg) {
  res[cfg.id] <- cfg
  return res
}, {})

let actionBarTimers = Watched({})

function setTimerData(timerId, data) {
  if (data != null)
    actionBarTimers.mutate(@(v) v[timerId] <- data)
  else if (timerId in actionBarTimers.get())
    actionBarTimers.mutate(@(v) v.$rawdelete(timerId))
}

function onRearm(data) {
  let { object_name, state, timeToLoadOne = 0, currentLoadTime = 0, rearmState = REARM_STATE.CHARGE } = data
  if (object_name not in timersCfgById)
    return

  if (state == REARM_EVENT_STATE.REARMING)
    setTimerData(object_name, {
      period = timeToLoadOne
      currentTime = currentLoadTime
      receiveTime = get_mission_time()
      rearmState
    })
  else if (state == REARM_EVENT_STATE.NOT_IN_REARM)
    setTimerData(object_name, null)
}

function onInextinguishableFire(data) {
  let { time = 0, totalTime = 0 } = data
  setTimerData("inextinguishable_fire_status", totalTime <= 0 ? null
    : { time, totalTime, receiveTime = get_mission_time() })
}

function isTracksOnlyRepair(repairingParts) {
  let partsValue = repairingParts?.name ?? []
  let parts = typeof(partsValue) == "array" ? partsValue : [partsValue]
  return parts.len() > 0 && parts.findindex(@(part) !startsWith(part, "track_") && !startsWith(part, "wheel_")) == null
}

function onRepair(data) {
  let { state = REPAIR_STATE.NOT_IN_REPAIR, time = 0, totalTime = 0, repairingParts = null } = data
  let isVisible = state != REPAIR_STATE.NOT_IN_REPAIR
    && (time > REPAIR_SHOW_TIME_THRESHOLD || state == REPAIR_STATE.PREPARE)
  setTimerData("repair_status", !isVisible ? null : {
    state, time, totalTime, receiveTime = get_mission_time(), isTracksOnly = isTracksOnlyRepair(repairingParts)
  })
}

function onBuilding(data) {
  let { timer = 0, totalTime = 0, pause = false, backward = false, showTimer = false } = data
  setTimerData("building_status", !showTimer ? null : {
    remainingTime = timer, totalTime, backward, pause, receiveTime = get_mission_time()
  })
}

function hideGunnerAvailableTimer() {
  if ("gunner_status" in actionBarTimers.get())
    actionBarTimers.mutate(@(v) v.gunner_status.timeToAvailable = -1)
}

function setCrewTimerData(timerId, data) {
  let { state = "", timeToTakePlace = 0, totalTakePlaceTime = 0, availableTime = 0, timeToAvailable = -1 } = data
  setTimerData(timerId, state != "takingPlace" ? null
    : { timeToTakePlace, totalTakePlaceTime, availableTime, timeToAvailable, receiveTime = get_mission_time() })
  
  if (state == "takingPlace" && timeToAvailable > 0)
    resetTimeout(timeToAvailable, hideGunnerAvailableTimer)
}

function onCrewState(data) {
  let { healing = false, totalHealingTime = 0, currentHealingTime = 0 } = data
  setTimerData("healing_status", !healing ? null
    : { totalHealingTime, currentHealingTime, receiveTime = get_mission_time() })
}

function onMoveCooldown(data) {
  let { time = -1 } = data
  setTimerData("move_cooldown_status", time < 0 ? null : { time, receiveTime = get_mission_time() })
}

function onBattery(data) {
  let charge = (data?.charge ?? 100).tointeger()
  if (actionBarTimers.get()?.battery_status.charge == charge)
    return
  setTimerData("battery_status", charge >= 100 ? null : { charge })
}

let clearActionBarTimers = @(_eventData) actionBarTimers.mutate(@(v) v.clear())

function subscribeHudManagerEvents() {
  g_hud_event_manager.subscribe("TankDebuffs:Repair", onRepair)
  g_hud_event_manager.subscribe("TankDebuffs:Building", onBuilding)
  g_hud_event_manager.subscribe("LocalPlayerDead", clearActionBarTimers)
  g_hud_event_manager.subscribe("MissionResult", clearActionBarTimers)
  g_hud_event_manager.subscribe("LiveStatsVisibilityToggled", @(_eventData) actionBarTimers.trigger())
}

eventbus_subscribe("TankDebuffs:Rearm", onRearm)
eventbus_subscribe("TankDebuffs:InextinguishableFire", onInextinguishableFire)
eventbus_subscribe("TankDebuffs:MoveCooldown", onMoveCooldown)
eventbus_subscribe("TankDebuffs:Battery", onBattery)
eventbus_subscribe("CrewState:DriverState", @(data) setCrewTimerData("driver_status", data))
eventbus_subscribe("CrewState:GunnerState", @(data) setCrewTimerData("gunner_status", data))
eventbus_subscribe("CrewState:CrewState", onCrewState)

subscribeHudManagerEvents()

add_event_listener("LoadingStateChange", clearActionBarTimers)
add_event_listener("HudEventManagerReset", @(_eventData) subscribeHudManagerEvents())

function applyTimerStateImpl(placeObj, timerId, newTimers) {
  let timer = newTimers?[timerId]
  placeObj["animation"] = timer != null ? "show" : "hide"
  if (timer != null)
    timersCfgById[timerId].applyTimerStateFn(placeObj, timer)
}

function createActionBarTimers(nestObj) {
  let isRendered = nestObj.childrenCount() > 0
  let needTimers = hasAAComplexMenuItem()
  if (isRendered == needTimers)
    return

  if (!needTimers) {
    nestObj.getScene().replaceContentFromText(nestObj, "", 0, {})
    return
  }

  let timersList = timersCfg.map(@(cfg) {}.__update(defaultTimerCfg, cfg))
  let blk = handyman.renderCached("%gui/hud/hudDisplayTimers.tpl", { timersList })
  nestObj.getScene().replaceContentFromText(nestObj, blk, blk.len(), {})
}

function updateActionBarTimersState(nestObj, newTimers) {
  if (nestObj.childrenCount() == 0)
    return
  foreach (cfg in timersCfg) {
    let placeObj = nestObj.findObject(cfg.id)
    if (placeObj != null)
      applyTimerStateImpl(placeObj, cfg.id, newTimers)
  }
}

function setActionBarTimers(nestObj, newTimers) {
  if (!nestObj?.isValid())
    return
  nestObj.show(!g_hud_live_stats.isVisible())
  createActionBarTimers(nestObj)
  updateActionBarTimersState(nestObj, newTimers)
}

return {
  actionBarTimers
  setActionBarTimers
}
