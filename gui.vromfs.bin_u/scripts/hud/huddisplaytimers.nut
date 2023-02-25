//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")
let { fabs } = require("math")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { MISSION_CAPTURE_ZONE_START, MISSION_CAPTURING_ZONE } = require("guiMission")

let REPAIR_SHOW_TIME_THRESHOLD = 1.5

::g_hud_display_timers <- {
  timersList = [
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
        if (::g_hud_display_timers.unitType == ES_UNIT_TYPE_SHIP)
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
        if (::g_hud_display_timers.unitType == ES_UNIT_TYPE_SHIP)
          return "#ui/gameuiskin#ship_crew_driver.svg"
        return "#ui/gameuiskin#crew_driver_indicator.svg"
      }
    },
    {
      id = "gunner_status"
      color = "@crewTransferColor"
      icon = function () {
        if (::g_hud_display_timers.unitType == ES_UNIT_TYPE_SHIP)
          return "#ui/gameuiskin#ship_crew_gunner.svg"
        return "#ui/gameuiskin#crew_gunner_indicator.svg"
      }
    },
    {
      id = "healing_status"
      color = "@white"
      icon = "#ui/gameuiskin#medic_status_indicator.svg"
    },
    {
      id = "repair_breaches_status"
      color = "#787878"
      icon = "#ui/gameuiskin#icon_repair_in_progress.svg"
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
      icon = "#ui/gameuiskin#icon_repair_in_progress.svg"
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
  ]

  scene = null
  guiScene = null

  repairUpdater = null
  repairBreachesUpdater = null
  extinguishUpdater = null
  unitType = ES_UNIT_TYPE_INVALID

  curZoneCaptureName = null
  lastZoneCaptureUpdate = 0
  zoneCaptureOutdateTimeMsec = 3000

  function init(nest, v_unitType) {
    this.scene = nest.findObject("display_timers")
    if (!this.scene && !checkObj(this.scene))
      return

    this.unitType = v_unitType
    this.guiScene = this.scene.getScene()
    let blk = ::handyman.renderCached("%gui/hud/hudDisplayTimers.tpl", this.getViewData())
    this.guiScene.replaceContentFromText(this.scene, blk, blk.len(), this)

    ::g_hud_event_manager.subscribe("TankDebuffs:Rearm", this.onRearm, this)
    ::g_hud_event_manager.subscribe("TankDebuffs:Replenish", this.onReplenish, this)
    ::g_hud_event_manager.subscribe("TankDebuffs:Repair", this.onRepair, this)
    ::g_hud_event_manager.subscribe("TankDebuffs:MoveCooldown", this.onMoveCooldown, this)
    ::g_hud_event_manager.subscribe("TankDebuffs:Battery", this.onBattery, this)
    ::g_hud_event_manager.subscribe("TankDebuffs:ExtinguishAssist", this.onExtinguishAssist, this)
    ::g_hud_event_manager.subscribe("TankDebuffs:MineDetonation", this.onMineDetonation, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:Rearm", this.onRearm, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:Repair", this.onRepair, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:Cooldown", this.onMoveCooldown, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:RepairBreaches", this.onRepairBreaches, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:Extinguish", this.onExtinguish, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:CancelRepairBreaches", this.onCancelRepairBreaches, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:CancelExtinguish", this.onCancelExtinguish, this)

    ::g_hud_event_manager.subscribe("CrewState:CrewState", this.onCrewState, this)
    ::g_hud_event_manager.subscribe("CrewState:DriverState", this.onDriverState, this)
    ::g_hud_event_manager.subscribe("CrewState:GunnerState", this.onGunnerState, this)

    ::g_hud_event_manager.subscribe("LocalPlayerDead", this.onLocalPlayerDead, this)
    ::g_hud_event_manager.subscribe("MissionResult", this.onMissionResult, this)

    ::g_hud_event_manager.subscribe("zoneCapturingEvent", this.onZoneCapturingEvent, this)

    if (getTblValue("isDead", ::get_local_mplayer(), false))
      this.clearAllTimers()
  }


  function reinit() {
    if (getTblValue("isDead", ::get_local_mplayer(), false))
      this.clearAllTimers()
  }


  function getViewData() {
    return {
      timersList = this.timersList
    }
  }


  function onLocalPlayerDead(_eventData) {
    this.clearAllTimers()
  }


  function onMissionResult(_eventData) {
    this.clearAllTimers()
  }


  function clearAllTimers() {
    if (!checkObj(this.scene))
      return

    foreach (timerData in this.timersList) {
      let placeObj = this.scene.findObject(timerData.id)
      if (!checkObj(placeObj))
        return

      placeObj.animation = "hide"

      let iconObj = placeObj.findObject("icon")
      if (checkObj(iconObj))
        iconObj.wink = "no"
    }

    this.destoyRepairUpdater()
    this.destoyRepairBreachesUpdater()
    this.destoyExtinguishUpdater()
  }


  function onDriverState(newStateData) {
    this.onCrewMemberState("driver", newStateData)
  }


  function onGunnerState(newStateData) {
    this.onCrewMemberState("gunner", newStateData)
  }


  function onCrewMemberState(memberId, newStateData) {
    if (!("state" in newStateData))
      return

    let placeObj = this.scene.findObject(memberId + "_status")
    if (!checkObj(placeObj))
      return

    let showTimer = newStateData.state == "takingPlace"
    placeObj.animation = showTimer ? "show" : "hide"
    if (!showTimer)
      return

    let timebarObj = placeObj.findObject("timer")
    ::g_time_bar.setPeriod(timebarObj, newStateData.totalTakePlaceTime)
    ::g_time_bar.setCurrentTime(timebarObj, newStateData.totalTakePlaceTime - newStateData.timeToTakePlace)
  }


  function onCrewState(newStateData) {
    let placeObj = this.scene.findObject("healing_status")
    if (!checkObj(placeObj))
      return

    let showTimer = newStateData.healing
    placeObj.animation = showTimer ? "show" : "hide"
    if (!showTimer)
      return

    let timebarObj = placeObj.findObject("timer")
    ::g_time_bar.setPeriod(timebarObj, newStateData.totalHealingTime + 1)
    ::g_time_bar.setCurrentTime(timebarObj, newStateData.totalHealingTime - newStateData.timeToHeal)
  }


  function onRearm(debuffs_data) {
    let placeObj = this.scene.findObject(debuffs_data.object_name)
    if (!checkObj(placeObj))
      return

    let showTimer = debuffs_data.state == "rearming"
    placeObj.animation = showTimer ? "show" : "hide"

    if (!showTimer)
      return

    let timebarObj = placeObj.findObject("timer")
    ::g_time_bar.setDirectionForward(timebarObj)
    ::g_time_bar.setPeriod(timebarObj, debuffs_data.timeToLoadOne)
    ::g_time_bar.setCurrentTime(timebarObj, debuffs_data.currentLoadTime)
  }


  function onReplenish(debuffs_data) {
    let placeObj = this.scene.findObject("replenish_status")
    if (!checkObj(placeObj))
      return

    let showTimer = debuffs_data?.isReplenishActive ?? false
    placeObj.animation = showTimer ? "show" : "hide"

    let timebarObj = placeObj.findObject("timer")

    if (!showTimer) {
      ::g_time_bar.setPeriod(timebarObj, 0)
      ::g_time_bar.setCurrentTime(timebarObj, 0)
      return
    }

    ::g_time_bar.setDirectionBackward(timebarObj)
    ::g_time_bar.setPeriod(timebarObj, debuffs_data?.periodTime ?? 0, true)
    ::g_time_bar.setCurrentTime(timebarObj, debuffs_data?.currentLoadTime ?? 0)
  }


  function onRepair(debuffs_data) {
    this.destoyRepairUpdater()
    this.hideAnimTimer("repair_status")
    this.hideAnimTimer("repair_auto_status")

    if ((debuffs_data?.time ?? 0) <= REPAIR_SHOW_TIME_THRESHOLD && debuffs_data.state != "prepareRepair")
      return

    if (debuffs_data.state == "notInRepair")
      return

    let objId = debuffs_data.state == "repairingAuto" ? "repair_auto_status" : "repair_status"
    let placeObj = this.scene.findObject(objId)
    if (!checkObj(placeObj))
      return

    placeObj.animation = "show"

    let iconObj = placeObj.findObject("icon")
    let timebarObj = placeObj.findObject("timer")
    let timeTextObj = placeObj.findObject("time_text")
    timeTextObj.setValue("")

    placeObj.show(true)

    if (debuffs_data.state == "prepareRepair") {
      iconObj.wink = "fast"
      ::g_time_bar.setDirectionBackward(timebarObj)
    }
    else if (debuffs_data.state == "repairing" || debuffs_data.state == "repairingAuto") {
      iconObj.wink = "no"
      ::g_time_bar.setDirectionForward(timebarObj)
      let createTime = get_time_msec()
      this.repairUpdater = SecondsUpdater(timeTextObj, (@(debuffs_data, createTime) function(obj, _p) {
        let curTime = get_time_msec()
        let timeToShowSeconds = debuffs_data.time - time.millisecondsToSeconds(curTime - createTime)
        if (timeToShowSeconds < 0)
          return true

        obj.setValue(timeToShowSeconds.tointeger().tostring())
        return false
      })(debuffs_data, createTime))
    }

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function onMoveCooldown(debuffs_data) {
    let placeObj = this.scene.findObject("move_cooldown_status")
    if (!checkObj(placeObj))
      return

    let showTimer = debuffs_data.time >= 0
    placeObj.animation = showTimer ? "show" : "hide"

    let timebarObj = placeObj.findObject("timer")

    if (!showTimer) {
      ::g_time_bar.setPeriod(timebarObj, 0)
      ::g_time_bar.setCurrentTime(timebarObj, 0)
      return
    }

    ::g_time_bar.setDirectionBackward(timebarObj)
    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function onBattery(debuffs_data) {
    let placeObj = this.scene.findObject("battery_status")
    if (!checkObj(placeObj))
      return

    let showTimer = debuffs_data.charge < 100
    placeObj.animation = showTimer ? "show" : "hide"

    let timeTextObj = placeObj.findObject("time_text")
    timeTextObj.setValue(debuffs_data.charge.tointeger().tostring());
    let timebarObj = placeObj.findObject("timer")

    ::g_time_bar.setPeriod(timebarObj, 0)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function hideAnimTimer(objId) {
    let placeObj = this.scene.findObject(objId)
    if (!checkObj(placeObj))
      return
    placeObj.animation = "hide"
    placeObj.findObject("icon").wink = "no"
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
      ::g_time_bar.setDirectionBackward(timebarObj)

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function onRepairBreaches(debuffs_data) {
    if (debuffs_data.state == "notInRepair") {
      this.destoyRepairBreachesUpdater()
      this.hideAnimTimer("unwatering_status")
      this.hideAnimTimer("repair_breaches_status")
      return
    }

    let objId = debuffs_data.state == "unwatering" ? "unwatering_status" : "repair_breaches_status"
    let placeObj = this.scene.findObject(objId)
    if (!checkObj(placeObj))
      return


    placeObj.animation = "show"

    this.destoyRepairBreachesUpdater()
    let iconObj = placeObj.findObject("icon")
    let timebarObj = placeObj.findObject("timer")
    let timeTextObj = placeObj.findObject("time_text")
    timeTextObj.setValue("")

    placeObj.show(true)

    if (debuffs_data.state == "repairing" || debuffs_data.state == "unwatering") {
      iconObj.wink = "no"
      ::g_time_bar.setDirectionForward(timebarObj)
      let createTime = get_time_msec()
      this.repairBreachesUpdater = SecondsUpdater(timeTextObj, (@(debuffs_data, createTime) function(obj, _p) {
        let curTime = get_time_msec()
        let timeToShowSeconds = debuffs_data.time - time.millisecondsToSeconds(curTime - createTime)
        if (timeToShowSeconds < 0)
          return true

        obj.setValue(timeToShowSeconds.tointeger().tostring())
        return false
      })(debuffs_data, createTime))
    }

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function onCancelRepairBreaches(debuffs_data) {
    let placeObj = this.scene.findObject("cancel_repair_breaches_status")
    if (!checkObj(placeObj))
      return

    this.onCancelAction(debuffs_data, placeObj)
  }

  function onExtinguishAssist(debuffs_data) {
    let placeObj = this.scene.findObject("extinguish_assist")
    if (!checkObj(placeObj))
      return

    this.onCancelAction(debuffs_data, placeObj)
  }

  function onMineDetonation(debuffs_data) {
    let placeObj = this.scene.findObject("mine_detonation")
    if (!checkObj(placeObj))
      return

    let showTimer = (debuffs_data?.timer ?? -1) >= 0.0
    placeObj.animation = showTimer ? "show" : "hide"

    let timebarObj = placeObj.findObject("timer")

    if (!showTimer) {
      ::g_time_bar.setPeriod(timebarObj, 0)
      ::g_time_bar.setCurrentTime(timebarObj, 0)
      return
    }

    ::g_time_bar.setDirectionBackward(timebarObj)
    ::g_time_bar.setPeriod(timebarObj, debuffs_data?.periodTime ?? 0, true)
    ::g_time_bar.setCurrentTime(timebarObj, debuffs_data?.timer ?? 0)
  }

  function onExtinguish(debuffs_data) {
    let placeObj = this.scene.findObject("extinguish_status")
    if (!checkObj(placeObj))
      return

    let showTimer = debuffs_data.state != "notInExtinguish"
    placeObj.animation = showTimer ? "show" : "hide"

    this.destoyExtinguishUpdater()
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
      ::g_time_bar.setDirectionForward(timebarObj)
      let createTime = get_time_msec()
      this.extinguishUpdater = SecondsUpdater(timeTextObj, (@(debuffs_data, createTime) function(obj, _p) {
        let curTime = get_time_msec()
        let timeToShowSeconds = debuffs_data.time - time.millisecondsToSeconds(curTime - createTime)
        if (timeToShowSeconds < 0)
          return true

        obj.setValue(timeToShowSeconds.tointeger().tostring())
        return false
      })(debuffs_data, createTime))
    }

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function onCancelExtinguish(debuffs_data) {
    let placeObj = this.scene.findObject("cancel_extinguish_status")
    if (!checkObj(placeObj))
      return

    this.onCancelAction(debuffs_data, placeObj)
  }

  function destoyRepairUpdater() {
    if (this.repairUpdater == null)
      return

    this.repairUpdater.remove()
    this.repairUpdater = null
  }

  function destoyRepairBreachesUpdater() {
    if (this.repairBreachesUpdater == null)
      return

    this.repairBreachesUpdater.remove()
    this.repairBreachesUpdater = null
  }

  function destoyExtinguishUpdater() {
    if (this.extinguishUpdater == null)
      return

    this.extinguishUpdater.remove()
    this.extinguishUpdater = null
  }

  function onZoneCapturingEvent(eventData) {
    if (!eventData.isHeroAction && eventData.zoneName != this.curZoneCaptureName)
      return
    let placeObj = this.scene.findObject("capture_progress")
    if (!checkObj(placeObj))
      return

    let isZoneCapturing = eventData.isHeroAction
      && (eventData.eventId == MISSION_CAPTURE_ZONE_START || eventData.eventId == MISSION_CAPTURING_ZONE)
    placeObj.animation = isZoneCapturing ? "show" : "hide"
    this.curZoneCaptureName = isZoneCapturing ? eventData.zoneName : null
    if (!isZoneCapturing)
      return

    this.lastZoneCaptureUpdate = get_time_msec()
    let timebarObj = placeObj.findObject("timer")
    ::g_time_bar.setPeriod(timebarObj, 0)
    ::g_time_bar.setValue(timebarObj, fabs(eventData.captureProgress))

    let color = this.isCapturingZoneMy(eventData) ? "hudColorBlue" : "hudColorRed"
    timebarObj["background-color"] = this.guiScene.getConstantValue(color)

    let timerObj = placeObj.findObject("time_text")
    timerObj.setValue(this.curZoneCaptureName)

    //hide timer when no progress too long.
    //because we not receive self capture stop event, only team
    SecondsUpdater(timerObj, function(_obj, _p) {
      if (this.lastZoneCaptureUpdate + this.zoneCaptureOutdateTimeMsec > get_time_msec())
        return false

      if (checkObj(placeObj))
        placeObj.animation = "hide"
      return true
    }.bindenv(this))
  }

  isCapturingZoneMy = @(eventData) (::get_mp_local_team() == Team.A) == (eventData.captureProgress < 0)

  function isValid() {
    return checkObj(this.scene)
  }
}
