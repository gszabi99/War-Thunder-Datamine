from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/timeBar.nut" import g_time_bar

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { eventbus_subscribe } = require("eventbus")
let { get_time_msec } = require("dagor.time")
let { resetTimeout } = require("dagor.workcycle")
let { fabs } = require("math")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { millisecondsToSeconds } = require("%scripts/time.nut")
let { MISSION_CAPTURE_ZONE_START, MISSION_CAPTURING_ZONE } = require("guiMission")
let { get_local_mplayer, get_mp_local_team } = require("mission")
let { startsWith } = require("%sqstd/string.nut")

let REPAIR_SHOW_TIME_THRESHOLD = 1.5

local scene = null
local guiScene = null

local repairUpdater = null
local repairBreachesUpdater = null
local extinguishUpdater = null
local inextinguishableFireUpdater = null
local timersUnitType = ES_UNIT_TYPE_INVALID

local curZoneCaptureName = null
local lastZoneCaptureUpdate = 0
local zoneCaptureOutdateTimeMsec = 3000

let timersList = [
  {
    id = "repair_status"
    color = "#787878"
    icon = "#ui/gameuiskin#icon_repair_in_progress.svg"
    needTimeText = true
  },
  {
    id = "repair_auto_status"
    color = "#787878"
    icon = function () {
      if (timersUnitType == ES_UNIT_TYPE_SHIP)
        return "#ui/gameuiskin#ship_crew_driver.svg"
      return "#ui/gameuiskin#track_state_indicator.svg"
    }
    needTimeText = true
  },
  {
    id = "rearm_primary_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_weapons_in_progress.svg"
  },
  {
    id = "rearm_secondary_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_weapons_in_progress.svg"
  },
  {
    id = "rearm_machinegun_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_weapons_in_progress.svg"
  },
  {
    id = "rearm_coaxial_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_weapons_in_progress.svg"
  },
  {
    id = "rearm_rocket_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_rocket_in_progress.svg"
  },
  {
    id = "rearm_smoke_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_smoke_screen_in_progress.svg"
  },
  {
    id = "rearm_aps_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_rocket_in_progress.svg"
  },
  {
    id = "driver_status"
    color = "@crewTransferColor"
    icon = function () {
      if (timersUnitType == ES_UNIT_TYPE_SHIP)
        return "#ui/gameuiskin#ship_crew_driver.svg"
      return "#ui/gameuiskin#crew_driver_indicator.svg"
    }
  },
  {
    id = "gunner_status"
    color = "@crewTransferColor"
    icon = function () {
      if (timersUnitType == ES_UNIT_TYPE_SHIP)
        return "#ui/gameuiskin#ship_crew_gunner.svg"
      return "#ui/gameuiskin#crew_gunner_indicator.svg"
    }
    needSecondTimebar=true
  },
  {
    id = "healing_status"
    color = "@white"
    icon = "#ui/gameuiskin#medic_status_indicator.svg"
  },
  {
    id = "repair_breaches_status"
    color = "#787878"
    icon = "#ui/gameuiskin#dmg_ship_breach.svg"
    needTimeText = true
  },
  {
    id = "unwatering_status"
    color = "#787878"
    icon = "#ui/gameuiskin#unwatering_in_progress.svg"
    needTimeText = true
  },
  {
    id = "cancel_repair_breaches_status"
    color = "#787878"
    icon = "#ui/gameuiskin#dmg_ship_breach.svg"
    needTimeText = true
  },
  {
    id = "extinguish_status"
    color = "#DD1111"
    icon = "#ui/gameuiskin#fire_indicator.svg"
    needTimeText = true
  },
  {
    id = "cancel_extinguish_status"
    color = "#DD1111"
    icon = "#ui/gameuiskin#fire_indicator.svg"
    needTimeText = true
  },
  {
    id = "capture_progress"
    needTimeText = true
  },
  {
    id = "replenish_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_weapons_relocation_in_progress.svg"
  },
  {
    id = "move_cooldown_status"
    color = "@white"
    icon = "#ui/gameuiskin#icon_repair_in_progress.svg"
  },
  {
    id = "battery_status"
    color = "#DD1111"
    icon = "#ui/gameuiskin#icon_battery_in_progress.svg"
    needTimeText = true
  },
  {
    id = "building_status"
    color = "#787878"
    icon = "#ui/gameuiskin#icon_building_in_progress.svg"
    needTimeText = true
  },
  {
    id = "inextinguishable_fire_status"
    color = "#DD1111"
    icon = "#ui/gameuiskin#fire_indicator.svg"
    needTimeText = true
  },
  {
    id = "extinguish_assist"
    color = "#DD1111"
    icon = "#ui/gameuiskin#fire_indicator.svg"
    needTimeText = true
  },
  {
    id = "mine_detonation"
    color = "@white"
    icon = "#ui/gameuiskin#mine_detonation_indicator.svg"
  },
  {
    id = "cancel_smoke_screen"
    color = "#787878"
    icon = "#ui/gameuiskin#icon_smoke_screen_in_progress.svg"
    needTimeText = true
  },
  {
    id = "mining_wall"
    color = "@white"
    icon = "#ui/gameuiskin#time_bomb.svg"
  },
  {
    id = "wall_time_to_explode"
    color = "@white"
    icon = "#ui/gameuiskin#time_bomb.svg"
  },
  {
    id = "building_a_wall"
    color = "@white"
    icon = "#ui/gameuiskin#building_wall.svg"
  },
  {
    id = "self_healing"
    color = "@white"
    icon = "#ui/gameuiskin#cross.svg"
  },
  {
    id = "fire_put_out"
    color = "@white"
    icon = "#ui/gameuiskin#extinguish_fire.svg"
  }
]

function getViewData() {
  return {
    timersList
  }
}

let isCapturingZoneMy = @(eventData) (get_mp_local_team() == Team.A) == (eventData.captureProgress < 0)

function destoyRepairUpdater() {
  if (repairUpdater == null)
    return

  repairUpdater.remove()
  repairUpdater = null
}

function destoyRepairBreachesUpdater() {
  if (repairBreachesUpdater == null)
    return

  repairBreachesUpdater.remove()
  repairBreachesUpdater = null
}

function destoyExtinguishUpdater() {
  if (extinguishUpdater == null)
    return

  extinguishUpdater.remove()
  extinguishUpdater = null
}

function destroyInextinguishableFireUpdater() {
  if (inextinguishableFireUpdater != null)
    inextinguishableFireUpdater.remove()
  inextinguishableFireUpdater = null
}

function onInextinguishableFire(debuffs_data) {
  destroyInextinguishableFireUpdater()
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("inextinguishable_fire_status")
  if (!checkObj(placeObj))
    return

  let showTimer = debuffs_data.totalTime > 0;
  placeObj.animation = showTimer ? "show" : "hide"
  let timeTextObj = placeObj.findObject("time_text")
  let timebarObj = placeObj.findObject("timer")
  timeTextObj.setValue("")

  if (showTimer) {
    let createTime = get_time_msec()
    inextinguishableFireUpdater = SecondsUpdater(timeTextObj, function(obj, _p) {
      let timeToShowSeconds = debuffs_data.time - millisecondsToSeconds(get_time_msec() - createTime)
      if (timeToShowSeconds < 0)
        return true
      obj.setValue(timeToShowSeconds.tointeger().tostring())
      return false
    })
  }

  g_time_bar.setDirectionBackward(timebarObj)
  g_time_bar.setPeriod(timebarObj, debuffs_data.totalTime)
  g_time_bar.setCurrentTime(timebarObj, debuffs_data.totalTime - debuffs_data.time)
}

function hideAnimTimer(objId) {
  let placeObj = scene.findObject(objId)
  if (!checkObj(placeObj))
    return
  placeObj.animation = "hide"
  placeObj.findObject("icon").wink = "no"
}

function clearAllTimers() {
  if (!checkObj(scene))
    return

  foreach (timerData in timersList) {
    let placeObj = scene.findObject(timerData.id)
    if (!checkObj(placeObj))
      return

    placeObj.animation = "hide"

    let iconObj = placeObj.findObject("icon")
    if (checkObj(iconObj))
      iconObj.wink = "no"
  }

  destoyRepairUpdater()
  destoyRepairBreachesUpdater()
  destoyExtinguishUpdater()
  destroyInextinguishableFireUpdater()
}

function hudDisplayTimersReInit() {
  if (getTblValue("isDead", get_local_mplayer(), false))
    clearAllTimers()
}

function onLocalPlayerDead(_eventData) {
  clearAllTimers()
}

function onMissionResult(_eventData) {
  clearAllTimers()
}

function onCancelAction(debuffs_data, placeObj) {
  placeObj.animation = debuffs_data.time > 0 ? "show" : "hide"
  placeObj.show(true)

  let timebarObj = placeObj.findObject("timer")
  let iconObj = placeObj.findObject("icon")
  iconObj.wink = "no"
  let timeTextObj = placeObj.findObject("time_text")
  timeTextObj.show(false)

  if (debuffs_data.time > 0)
    g_time_bar.setDirectionBackward(timebarObj)

  g_time_bar.setPeriod(timebarObj, debuffs_data.time)
  g_time_bar.setCurrentTime(timebarObj, 0)
}


function onCrewMemberState(memberId, newStateData) {
  if (!("state" in newStateData))
    return

  let placeObj = scene.findObject($"{memberId}_status")
  if (!checkObj(placeObj))
    return

  let showTimer = newStateData.state == "takingPlace"
  placeObj.animation = showTimer ? "show" : "hide"
  if (!showTimer)
    return

  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setPeriod(timebarObj, newStateData.totalTakePlaceTime)
  g_time_bar.setCurrentTime(timebarObj, newStateData.totalTakePlaceTime - newStateData.timeToTakePlace)
}


function hideAvailableTimer(memberId) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject($"{memberId}_status")
  if (!placeObj?.isValid())
    return
  showObjById("available_timer_nest", false, placeObj )
}

function onAvailableMemberState(memberId, newStateData) {
  if (!("state" in newStateData))
    return

  let placeObj = scene.findObject($"{memberId}_status")
  if (!checkObj(placeObj))
    return

  let showTimer = newStateData.state == "takingPlace"
  placeObj.animation = showTimer ? "show" : "hide"
  let timeToAvailable = newStateData?.timeToAvailable ?? -1.0
  let timerNestObj = placeObj.findObject("available_timer_nest")
  if (!showTimer || timeToAvailable < 0.0) {
    timerNestObj.show(false)
    return
  }
  timerNestObj.show(true)

  let timebarObj = placeObj.findObject("available_timer")
  g_time_bar.setPeriod(timebarObj, newStateData.availableTime)
  g_time_bar.setCurrentTime(timebarObj, newStateData.availableTime - timeToAvailable)

  resetTimeout(newStateData.availableTime, @() hideAvailableTimer(memberId))
}

function onCrewState(newStateData) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("healing_status")
  if (!checkObj(placeObj))
    return

  let showTimer = newStateData.healing
  placeObj.animation = showTimer ? "show" : "hide"
  if (!showTimer)
    return

  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setPeriod(timebarObj, newStateData.totalHealingTime)
  g_time_bar.setCurrentTime(timebarObj, newStateData.currentHealingTime)
}

function onRearm(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject(debuffs_data.object_name)
  if (!checkObj(placeObj))
    return

  let showTimer = debuffs_data.state == "rearming"
  placeObj.animation = showTimer ? "show" : "hide"

  if (!showTimer)
    return

  let timebarObj = placeObj.findObject("timer")

  g_time_bar.setDirectionForward(timebarObj)
  g_time_bar.setPeriod(timebarObj, debuffs_data.timeToLoadOne)
  g_time_bar.setCurrentTime(timebarObj, debuffs_data.currentLoadTime)
  let { rearmState = null } = debuffs_data
  if (rearmState == null)
    return

  if (rearmState == "pause") {
    g_time_bar.pauseTimer(timebarObj)
  }
  else if (rearmState == "discharge") {
    g_time_bar.setDirectionBackward(timebarObj)
  }
}

function onReplenish(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("replenish_status")
  if (!checkObj(placeObj))
    return

  let showTimer = debuffs_data?.isReplenishActive ?? false
  placeObj.animation = showTimer ? "show" : "hide"

  let timebarObj = placeObj.findObject("timer")

  if (!showTimer) {
    g_time_bar.setPeriod(timebarObj, 0)
    g_time_bar.setCurrentTime(timebarObj, 0)
    return
  }

  g_time_bar.setDirectionBackward(timebarObj)
  g_time_bar.setPeriod(timebarObj, debuffs_data?.periodTime ?? 0, true)
  g_time_bar.setCurrentTime(timebarObj, debuffs_data?.currentLoadTime ?? 0)
}

function onRepair(debuffs_data) {
  if (!scene?.isValid())
    return
  destoyRepairUpdater()
  hideAnimTimer("repair_status")
  hideAnimTimer("repair_auto_status")
  let { state = "notInRepair", time, totalTime, repairingParts = null } = debuffs_data
  if (time <= REPAIR_SHOW_TIME_THRESHOLD && state != "prepareRepair")
    return

  if (state == "notInRepair")
    return

  let isAutoRepairing = state == "repairingAuto"
  let objId = isAutoRepairing ? "repair_auto_status" : "repair_status"
  let placeObj = scene.findObject(objId)
  if (!checkObj(placeObj))
    return

  placeObj.animation = "show"

  let iconObj = placeObj.findObject("icon")
  if (isAutoRepairing && timersUnitType == ES_UNIT_TYPE_TANK && repairingParts != null) {
    local partsArray = repairingParts?.name ?? []
    partsArray = type(partsArray) == "array" ? partsArray : [partsArray] 
    let tracksPartsArray = partsArray.filter(@(part) startsWith(part, "track_") || startsWith(part, "wheel_"))
    iconObj["background-image"] = tracksPartsArray.len() == partsArray.len() ? "#ui/gameuiskin#track_state_indicator.svg"
      : "#ui/gameuiskin#icon_repair_in_progress.svg"
  }
  let timebarObj = placeObj.findObject("timer")
  let timeTextObj = placeObj.findObject("time_text")
  timeTextObj.setValue("")

  placeObj.show(true)

  if (state == "prepareRepair") {
    iconObj.wink = "fast"
    g_time_bar.setDirectionBackward(timebarObj)
  }
  else if (state == "repairing" || isAutoRepairing) {
    iconObj.wink = "no"
    g_time_bar.setDirectionForward(timebarObj)
    let createTime = get_time_msec() - (totalTime - time) * 1000
    repairUpdater = SecondsUpdater(timeTextObj, function(obj, _p) {
      let curTime = get_time_msec()
      let timeToShowSeconds = totalTime - millisecondsToSeconds(curTime - createTime)
      if (timeToShowSeconds < 0)
        return true

      obj.setValue(timeToShowSeconds.tointeger().tostring())
      return false
    })
  }

  g_time_bar.setPeriod(timebarObj, totalTime)
  g_time_bar.setCurrentTime(timebarObj, totalTime - time)
}

function onMoveCooldown(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("move_cooldown_status")
  if (!checkObj(placeObj))
    return

  let showTimer = debuffs_data.time >= 0
  placeObj.animation = showTimer ? "show" : "hide"

  let timebarObj = placeObj.findObject("timer")

  if (!showTimer) {
    g_time_bar.setPeriod(timebarObj, 0)
    g_time_bar.setCurrentTime(timebarObj, 0)
    return
  }

  g_time_bar.setDirectionBackward(timebarObj)
  g_time_bar.setPeriod(timebarObj, debuffs_data.time)
  g_time_bar.setCurrentTime(timebarObj, 0)
}

function onBattery(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("battery_status")
  if (!checkObj(placeObj))
    return

  let showTimer = debuffs_data.charge < 100
  placeObj.animation = showTimer ? "show" : "hide"

  let timeTextObj = placeObj.findObject("time_text")
  timeTextObj.setValue(debuffs_data.charge.tointeger().tostring());
  let timebarObj = placeObj.findObject("timer")

  g_time_bar.setPeriod(timebarObj, 0)
  g_time_bar.setCurrentTime(timebarObj, 0)
}

function onBuilding(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("building_status")
  if (!checkObj(placeObj))
    return

  let { timer, totalTime, pause, backward, showTimer } = debuffs_data
  placeObj.animation = showTimer ? "show" : "hide"

  let timeTextObj = placeObj.findObject("time_text")
  timeTextObj.setValue(timer.tointeger().tostring());
  let timebarObj = placeObj.findObject("timer")

  g_time_bar.setPeriod(timebarObj, totalTime)
  if (backward)
    g_time_bar.setDirectionBackward(timebarObj)
  else
    g_time_bar.setDirectionForward(timebarObj)
  g_time_bar.setCurrentTime(timebarObj, backward ? timer : totalTime - timer)

  if (pause)
    g_time_bar.pauseTimer(timebarObj)
}

function onRepairBreaches(debuffs_data) {
  if (!scene?.isValid())
    return
  if (debuffs_data.state == "notInRepair") {
    destoyRepairBreachesUpdater()
    hideAnimTimer("unwatering_status")
    hideAnimTimer("repair_breaches_status")
    return
  }

  let objId = debuffs_data.state == "unwatering" ? "unwatering_status" : "repair_breaches_status"
  let placeObj = scene.findObject(objId)
  if (!checkObj(placeObj))
    return

  placeObj.animation = "show"

  destoyRepairBreachesUpdater()
  let iconObj = placeObj.findObject("icon")
  let timebarObj = placeObj.findObject("timer")
  let timeTextObj = placeObj.findObject("time_text")
  timeTextObj.setValue("")

  placeObj.show(true)

  if (debuffs_data.state == "repairing" || debuffs_data.state == "unwatering") {
    iconObj.wink = "no"
    g_time_bar.setDirectionForward(timebarObj)
    let createTime = get_time_msec()
    repairBreachesUpdater = SecondsUpdater(timeTextObj, function(obj, _p) {
      let curTime = get_time_msec()
      let timeToShowSeconds = debuffs_data.time - millisecondsToSeconds(curTime - createTime)
      if (timeToShowSeconds < 0)
        return true

      obj.setValue(timeToShowSeconds.tointeger().tostring())
      return false
    })
  }

  g_time_bar.setPeriod(timebarObj, debuffs_data.time)
  g_time_bar.setCurrentTime(timebarObj, 0)
}

function onCancelRepairBreaches(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("cancel_repair_breaches_status")
  if (!checkObj(placeObj))
    return

  onCancelAction(debuffs_data, placeObj)
}

function onExtinguishAssist(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("extinguish_assist")
  if (!checkObj(placeObj))
    return

  onCancelAction(debuffs_data, placeObj)
}

function onCancelSmokeScreen(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("cancel_smoke_screen")
  if (!checkObj(placeObj))
    return

  onCancelAction(debuffs_data, placeObj)
}

function onMineDetonation(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("mine_detonation")
  if (!checkObj(placeObj))
    return

  let showTimer = (debuffs_data?.timer ?? -1) >= 0.0
  placeObj.animation = showTimer ? "show" : "hide"

  let timebarObj = placeObj.findObject("timer")

  if (!showTimer) {
    g_time_bar.setPeriod(timebarObj, 0)
    g_time_bar.setCurrentTime(timebarObj, 0)
    return
  }

  g_time_bar.setDirectionBackward(timebarObj)
  g_time_bar.setPeriod(timebarObj, debuffs_data?.periodTime ?? 0, true)
  g_time_bar.setCurrentTime(timebarObj, debuffs_data?.timer ?? 0)
}

function onExtinguish(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("extinguish_status")
  if (!checkObj(placeObj))
    return

  let showTimer = debuffs_data.state != "notInExtinguish"
  placeObj.animation = showTimer ? "show" : "hide"

  destoyExtinguishUpdater()
  let iconObj = placeObj.findObject("icon")

  if (!showTimer) {
    iconObj.wink = "no"
    return
  }

  let timebarObj = placeObj.findObject("timer")
  let timeTextObj = placeObj.findObject("time_text")
  timeTextObj.setValue("")

  placeObj.show(true)

  if (debuffs_data.state == "extinguish") {
    iconObj.wink = "no"
    g_time_bar.setDirectionForward(timebarObj)
    let createTime = get_time_msec()
    extinguishUpdater = SecondsUpdater(timeTextObj, function(obj, _p) {
      let curTime = get_time_msec()
      let timeToShowSeconds = debuffs_data.time - millisecondsToSeconds(curTime - createTime)
      if (timeToShowSeconds < 0)
        return true

      obj.setValue(timeToShowSeconds.tointeger().tostring())
      return false
    })
  }

  g_time_bar.setPeriod(timebarObj, debuffs_data.time)
  g_time_bar.setCurrentTime(timebarObj, 0)
}

function onCancelExtinguish(debuffs_data) {
  if (!scene?.isValid())
    return
  let placeObj = scene.findObject("cancel_extinguish_status")
  if (!checkObj(placeObj))
    return

  onCancelAction(debuffs_data, placeObj)
}

function onDriverState(newStateData) {
  if (!scene?.isValid())
    return
  onCrewMemberState("driver", newStateData)
}

function onGunnerState(newStateData) {
  if (!scene?.isValid())
    return
  onCrewMemberState("gunner", newStateData)
  onAvailableMemberState("gunner", newStateData)
}

function onZoneCapturingEvent(eventData) {
  if (!scene?.isValid())
    return
  if (!eventData.isHeroAction && eventData.zoneName != curZoneCaptureName)
    return
  let placeObj = scene.findObject("capture_progress")
  if (!checkObj(placeObj))
    return

  let isZoneCapturing = eventData.isHeroAction
    && (eventData.eventId == MISSION_CAPTURE_ZONE_START || eventData.eventId == MISSION_CAPTURING_ZONE)
  placeObj.animation = isZoneCapturing ? "show" : "hide"
  curZoneCaptureName = isZoneCapturing ? eventData.zoneName : null
  if (!isZoneCapturing)
    return

  lastZoneCaptureUpdate = get_time_msec()
  let timebarObj = placeObj.findObject("timer")
  g_time_bar.setPeriod(timebarObj, 0)
  g_time_bar.setValue(timebarObj, fabs(eventData.captureProgress))

  let color = isCapturingZoneMy(eventData) ? "hudColorBlue" : "hudColorRed"
  timebarObj["background-color"] = guiScene.getConstantValue(color)

  let timerObj = placeObj.findObject("time_text")
  timerObj.setValue(curZoneCaptureName)

  
  
  SecondsUpdater(timerObj, function(_obj, _p) {
    if (lastZoneCaptureUpdate + zoneCaptureOutdateTimeMsec > get_time_msec())
      return false

    if (checkObj(placeObj))
      placeObj.animation = "hide"
    return true
  })
}

function onMiningWallEvent(eventData) {
  if (!scene?.isValid())
    return

  let placeObj = scene.findObject("mining_wall")
  if (!placeObj?.isValid())
    return

  let showTimer = eventData.isMiningWall
  placeObj.animation = showTimer ? "show" : "hide"

  let timebarObj = placeObj.findObject("timer")

  if (!showTimer) {
    g_time_bar.setPeriod(timebarObj, 0)
    g_time_bar.setCurrentTime(timebarObj, 0)
    return
  }

  g_time_bar.setPeriod(timebarObj, eventData.miningWallTimeTotal, true)
  g_time_bar.setCurrentTime(timebarObj, 0)
}

function onPlantedBombEvent(eventData) {
  if (!scene?.isValid())
    return

  let placeObj = scene.findObject("wall_time_to_explode")
  if (!placeObj?.isValid())
    return

  let showTimer = eventData.curPlantedExplosionAtTime > 0.0
  placeObj.animation = showTimer ? "show" : "hide"

  let timebarObj = placeObj.findObject("timer")

  if (!showTimer) {
    g_time_bar.setPeriod(timebarObj, 0)
    g_time_bar.setCurrentTime(timebarObj, 0)
    return
  }

  g_time_bar.setDirectionBackward(timebarObj)
  g_time_bar.setPeriod(timebarObj, eventData?.curPlantedExplosionDelay, true)
  g_time_bar.setCurrentTime(timebarObj, 0)
}

function onBuildingWallEvent(eventData) {
  if (!scene?.isValid())
    return

  let placeObj = scene.findObject("building_a_wall")
  if (!placeObj?.isValid())
    return

  let showTimer = eventData.isReassemblingWall
  placeObj.animation = showTimer ? "show" : "hide"

  let timebarObj = placeObj.findObject("timer")

  if (!showTimer) {
    g_time_bar.setPeriod(timebarObj, 0)
    g_time_bar.setCurrentTime(timebarObj, 0)
    return
  }

  g_time_bar.setPeriod(timebarObj, eventData.reassemblingTotalTime, true)
  g_time_bar.setCurrentTime(timebarObj, 0)
}

function onSelfHealingEvent(eventData) {
  if (!scene?.isValid())
    return

  let placeObj = scene.findObject("self_healing")
  if (!placeObj?.isValid())
    return

  let showTimer = eventData.isMedkitUsing
  placeObj.animation = showTimer ? "show" : "hide"

  let timebarObj = placeObj.findObject("timer")

  if (!showTimer) {
    g_time_bar.setPeriod(timebarObj, 0)
    g_time_bar.setCurrentTime(timebarObj, 0)
    return
  }

  g_time_bar.setPeriod(timebarObj, eventData.entityUseTotalTime, true)
  g_time_bar.setCurrentTime(timebarObj, 0)
}

function onFirePutOutEvent(eventData) {
  if (!scene?.isValid())
    return

  let placeObj = scene.findObject("fire_put_out")
  if (!placeObj?.isValid())
    return

  let showTimer = eventData.isPuttingOut
  placeObj.animation = showTimer ? "show" : "hide"

  let timebarObj = placeObj.findObject("timer")

  if (!showTimer) {
    g_time_bar.setPeriod(timebarObj, 0)
    g_time_bar.setCurrentTime(timebarObj, 0)
    return
  }

  g_time_bar.setPeriod(timebarObj, eventData.firePutOutFullTime, false)
  g_time_bar.setCurrentTime(timebarObj, eventData.firePutOutElapsedTime)
}

function hudDisplayTimersInit(nest, v_unitType) {
  scene = nest.findObject("display_timers")
  if (!(scene?.isValid() ?? false))
    return

  timersUnitType = v_unitType
  guiScene = scene.getScene()
  let blk = handyman.renderCached("%gui/hud/hudDisplayTimers.tpl", getViewData())
  guiScene.replaceContentFromText(scene, blk, blk.len(), {})

  g_hud_event_manager.subscribe("TankDebuffs:Rearm", onRearm, scene)
  g_hud_event_manager.subscribe("TankDebuffs:Replenish", onReplenish, scene)
  g_hud_event_manager.subscribe("TankDebuffs:Repair", onRepair, scene)
  g_hud_event_manager.subscribe("TankDebuffs:MoveCooldown", onMoveCooldown, scene)
  g_hud_event_manager.subscribe("TankDebuffs:Battery", onBattery, scene)
  g_hud_event_manager.subscribe("TankDebuffs:ExtinguishAssist", onExtinguishAssist, scene)
  g_hud_event_manager.subscribe("TankDebuffs:MineDetonation", onMineDetonation, scene)
  g_hud_event_manager.subscribe("TankDebuffs:Building", onBuilding, scene)
  g_hud_event_manager.subscribe("TankDebuffs:CancelSmokeScreen", onCancelSmokeScreen, scene)

  g_hud_event_manager.subscribe("ShipDebuffs:Rearm", onRearm, scene)
  g_hud_event_manager.subscribe("ShipDebuffs:Repair", onRepair, scene)
  g_hud_event_manager.subscribe("ShipDebuffs:Cooldown", onMoveCooldown, scene)
  g_hud_event_manager.subscribe("ShipDebuffs:RepairBreaches", onRepairBreaches, scene)
  g_hud_event_manager.subscribe("ShipDebuffs:Extinguish", onExtinguish, scene)
  g_hud_event_manager.subscribe("ShipDebuffs:CancelRepairBreaches", onCancelRepairBreaches, scene)
  g_hud_event_manager.subscribe("ShipDebuffs:CancelExtinguish", onCancelExtinguish, scene)

  g_hud_event_manager.subscribe("CrewState:CrewState", onCrewState, scene)
  g_hud_event_manager.subscribe("CrewState:DriverState", onDriverState, scene)
  g_hud_event_manager.subscribe("CrewState:GunnerState", onGunnerState, scene)

  g_hud_event_manager.subscribe("LocalPlayerDead", onLocalPlayerDead, scene)
  g_hud_event_manager.subscribe("MissionResult", onMissionResult, scene)

  g_hud_event_manager.subscribe("zoneCapturingEvent", onZoneCapturingEvent, scene)
  g_hud_event_manager.subscribe("miningWallInProgress", onMiningWallEvent, scene)
  g_hud_event_manager.subscribe("plantedBombInProgress", onPlantedBombEvent, scene)
  g_hud_event_manager.subscribe("buildingWallInProgress", onBuildingWallEvent, scene)
  g_hud_event_manager.subscribe("selfHealingInProgress", onSelfHealingEvent, scene)
  g_hud_event_manager.subscribe("firePutOutInProgress", onFirePutOutEvent, scene)

  if (getTblValue("isDead", get_local_mplayer(), false))
    clearAllTimers()
}

eventbus_subscribe("TankDebuffs:InextinguishableFire", @(params) onInextinguishableFire(params))

return {
  hudDisplayTimersInit
  hudDisplayTimersReInit
}
