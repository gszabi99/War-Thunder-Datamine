from "%scripts/dagui_natives.nut" import get_option_xray_kill
from "%scripts/dagui_library.nut" import *
from "hitCamera" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { get_mission_time } = require("mission")
let { g_hud_enemy_debuffs } = require("%scripts/hud/hudEnemyDebuffsType.nut")
let { updateCrewLifebar, setCrewLostText } = require("%scripts/hud/hudCrewLifebarUtils.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { setInterval, setTimeout, clearTimer, deferOnce, resetTimeout } = require("dagor.workcycle")
let { get_game_params_blk } = require("blkGetters")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let { get_mission_difficulty_int } = require("guiMission")
let { getDaguiObjAabb } = require("%sqDagui/daguiUtil.nut")
let { isInFlight } = require("gameplayBinding")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { register_command } = require("console")
let { get_charserver_time_sec } = require("chard")
let { rnd_int, rnd_float } = require("dagor.random")

const TIME_TITLE_SHOW_SEC = 3
const TIME_TO_SUM_CREW_LOST = 0.15

let animTimerPid = dagui_propid_add_name_id("_transp-timer")
let animSizeTimerPid = dagui_propid_add_name_id("_size-timer")

let styles = {
  [DM_HIT_RESULT_NONE]      = "none",
  [DM_HIT_RESULT_RICOSHET]  = "ricochet",
  [DM_HIT_RESULT_BOUNCE]    = "bounce",
  [DM_HIT_RESULT_HIT]       = "hit",
  [DM_HIT_RESULT_BURN]      = "burn",
  [DM_HIT_RESULT_CRITICAL]  = "critical",
  [DM_HIT_RESULT_KILL]      = "kill",
  [DM_HIT_RESULT_METAPART]  = "hull",
  [DM_HIT_RESULT_AMMO]      = "ammo",
  [DM_HIT_RESULT_FUEL]      = "fuel",
  [DM_HIT_RESULT_CREW]      = "crew",
  [DM_HIT_RESULT_TORPEDO]   = "torpedo",
  [DM_HIT_RESULT_BREAKING]  = "breaking",
  [DM_HIT_RESULT_INVULNERABLE] = "invulnerable",
}

let debuffTemplates = {
  [ES_UNIT_TYPE_TANK] = "%gui/hud/hudEnemyDebuffsTank.blk",
  [ES_UNIT_TYPE_BOAT] = "%gui/hud/hudEnemyDebuffsShip.blk",
  [ES_UNIT_TYPE_SHIP] = "%gui/hud/hudEnemyDebuffsShip.blk",
}

let damageStatusTemplates = {
  [ES_UNIT_TYPE_BOAT] = "%gui/hud/hudEnemyDamageStatusShip.blk",
  [ES_UNIT_TYPE_SHIP] = "%gui/hud/hudEnemyDamageStatusShip.blk",
}

let importantEventKeys = ["partEvent", "ammoEvent", "specialEvent"]

let debuffsListsByUnitType = {}
let trackedPartNamesByUnitType = {}
let fireIndicators = {}

local hitCamNest  = null
local titleObj  = null
local infoObj   = null
local damageStatusObj = null
local isEnabled = true
local isVisible = false
local continueShowingOnSwitchHud = false
local stopFadeTimeS = -1
local hitResult = DM_HIT_RESULT_NONE
local curUnitId = -1
local curUnitVersion = -1
local curUnitType = ES_UNIT_TYPE_INVALID
let camInfo   = {}
local unitsInfo = {}
local minAliveCrewCount = 2
local canShowCritAnimation = false
local hasImportantTitle = false
local canAddLossText = false

function canAddLossTextTimer() {
  canAddLossText = false
}

function getMinAliveCrewCount() {
  let diffCode = get_mission_difficulty_int()
  let settingsName = g_difficulty.getDifficultyByDiffCode(diffCode).settingsName
  let path = $"difficulty_settings/baseDifficulty/{settingsName}/changeCrewTime"
  let changeCrewTime = getBlkValueByPath(get_game_params_blk(), path)
  return changeCrewTime != null ? 1 : 2
}

function stopDamageStatusBlink(statusObjId) {
  let obj = damageStatusObj?.isValid() ? damageStatusObj.findObject(statusObjId) : null
  if (obj?.isValid())
    obj._blink = "no"
}

function setDamageStatus(statusObjId, health, isCritical = true) {
  if (!damageStatusObj?.isValid())
    return

  let obj = damageStatusObj.findObject(statusObjId)
  if (!obj?.isValid())
    return

  let newStatus = health == 100 || health < 0 ? "none"
    : isCritical ? "critical" : "moderate"

  if (newStatus == obj.damage)
    return

  obj.damage = newStatus
  obj._blink = "yes"
  setTimeout(10, @() stopDamageStatusBlink(statusObjId))
}

function updateDebuffItem(item, unitInfo, partName = null, dmgParams = null) {
  let data = item.getInfo(camInfo, unitInfo, partName, dmgParams)

  let isShow = data != null
  if (item?.needShowChange)
    unitInfo.crewCurrCount = data?.value ?? unitInfo.crewPrevCount

  if (!(infoObj?.isValid() ?? false))
    return

  let obj = infoObj.findObject(item.id)
  if (!(obj?.isValid() ?? false))
    return
  obj.show(isShow)
  if (!isShow)
    return

  if (data?.state)
    obj.state = data.state

  if (!data?.label)
    return
  let labelObj = obj.findObject("label")
  if (labelObj?.isValid() ?? false)
    labelObj.setValue(data.label)

  if (data?.maxSizeLabel == null)
    return
  let labelNestObj = obj.findObject("label_nest")
  if (labelNestObj?.isValid() ?? false)
    labelNestObj.setValue(data?.maxSizeLabel)
}

function updateFadeAnimation() {
  let needFade = stopFadeTimeS > 0
  hitCamNest["transp-time"] = needFade ? (stopFadeTimeS * 1000).tointeger() : 1
  hitCamNest["transp-base"] = needFade ? 255 : 0
  hitCamNest["transp-end"]  = needFade ? 0 : 255
  hitCamNest.setFloatProp(animTimerPid, 0.0)
}

let getHitCameraAABB = @() getDaguiObjAabb(hitCamNest)
let isKillingHitResult = @(result) result >= DM_HIT_RESULT_KILL && result != DM_HIT_RESULT_INVULNERABLE

function reset() {
  isVisible = false
  stopFadeTimeS = -1
  hitResult = DM_HIT_RESULT_NONE
  curUnitId = -1
  curUnitVersion = -1
  curUnitType = ES_UNIT_TYPE_INVALID
  canShowCritAnimation = false
  fireIndicators.clear()
  camInfo.clear()
  unitsInfo.clear()
}

function getTargetInfo(unitId, unitVersion, unitType, isUnitKilled, unitName = null) {
  if (!(unitId in unitsInfo) || unitsInfo[unitId].unitVersion != unitVersion)
    unitsInfo[unitId] <- {
      unitId
      unitVersion
      unitType
      parts = {}
      trackedPartNames = trackedPartNamesByUnitType?[unitType] ?? []
      isKilled = isUnitKilled
      isKillProcessed = false
      time = 0
      crewTotalCount = 0
      crewPrevCount = -1
      crewCurrCount = -1
      importantEvents = {}
      unitName
    }

  let info = unitsInfo[unitId]
  info.time = get_mission_time()
  info.isKilled = info.isKilled || isUnitKilled

  return info
}

function cleanupUnitsInfo() {
  let old = get_mission_time() - 5.0
  let oldUnits = []
  foreach (unitId, info in unitsInfo) {
    info.importantEvents.clear()
    if (info.isKilled && info.time < old)
      oldUnits.append(unitId)
  }
  foreach (unitId in oldUnits)
    unitsInfo.$rawdelete(unitId)
}

function getNextImportantTitle() {
  let curInfo = getTargetInfo(curUnitId, curUnitVersion, curUnitType,
    isKillingHitResult(hitResult))

  let ammoEvent = curInfo.importantEvents?.ammoEvent[0]
  if (ammoEvent != null) {
    curInfo.importantEvents.ammoEvent.remove(0)
    return loc($"part_destroyed/{ammoEvent.munition}")
  }

  let partEvent = curInfo.importantEvents?.partEvent[0]
  if (partEvent != null) {
    curInfo.importantEvents.partEvent.remove(0)
    return loc($"part_destroyed/{partEvent.partName}")
  }

  let specialEvent = curInfo.importantEvents?.specialEvent[0]
  if (specialEvent != null) {
    curInfo.importantEvents.specialEvent.remove(0)
    return loc($"special_hit_event/{specialEvent.type}")
  }

  return ""
}

function showCritAnimation() {
  if (!canShowCritAnimation || !(hitCamNest?.isValid() ?? false))
    return

  canShowCritAnimation = false
  let animObj = hitCamNest.findObject("critAnim")
  animObj["_size-timer"] = "0"
  animObj.width = 1
  animObj.setFloatProp(animSizeTimerPid, 0.0)
  animObj.setFloatProp(animTimerPid, 0.0)
  animObj["color-factor"] = "255"
  animObj.needAnim = "yes"
}

function updateTitle() {
  clearTimer(updateTitle)
  if (!isVisible || !(titleObj?.isValid() ?? false) || hasImportantTitle)
    return

  let style = styles?[hitResult] ?? "none"
  hitCamNest.result = style
  let isVisibleTitle = hitResult != DM_HIT_RESULT_NONE
  titleObj.show(isVisibleTitle)
  if (isVisibleTitle) {
    titleObj.setValue(utf8ToUpper(loc($"hitcamera/result/{style}")))
    setTimeout(TIME_TITLE_SHOW_SEC, updateTitle)
    hitResult = DM_HIT_RESULT_NONE
  }
}

function updateImportantTitle() {
  clearTimer(updateImportantTitle)
  if (!isVisible || !(titleObj?.isValid() ?? false))
    return

  let title = getNextImportantTitle()
  if (title != "") {
    setTimeout(TIME_TITLE_SHOW_SEC, updateImportantTitle)
    hitCamNest.result = "kill"
    titleObj.show(true)
    titleObj.setValue(title)
    hasImportantTitle = true
    return
  }

  hasImportantTitle = false

  updateTitle()
}

function showCrewLoss() {
  let unitInfo = getTargetInfo(curUnitId, curUnitVersion, curUnitType, isKillingHitResult(hitResult))
  let { crewPrevCount, crewCurrCount, crewTotalCount } = unitInfo
  if (crewPrevCount <= 0) {
    unitInfo.crewPrevCount = crewCurrCount
    return
  }
  let crewLostCount = crewCurrCount - crewPrevCount
  if (!crewLostCount || crewLostCount > -1 || !(hitCamNest?.isValid() ?? false))
    return

  unitInfo.crewPrevCount = crewCurrCount

  let nest = hitCamNest.findObject("crew_lifebar_nest").findObject("lost_text_nest")
  let leftPos = (crewCurrCount + crewPrevCount)/2.0/crewTotalCount.tofloat() * 100

  setCrewLostText(nest, crewLostCount, leftPos, canAddLossText)
  canAddLossText = true
  resetTimeout(1.5, canAddLossTextTimer)
}

function updateCrewCount(unitInfo, data = null, isInitUpdate = false) {
  clearTimer(showCrewLoss)
  if (!(hitCamNest?.isValid() ?? false))
    return
  let isShowCrew = !unitInfo.isKilled
    && (curUnitType == ES_UNIT_TYPE_SHIP || curUnitType == ES_UNIT_TYPE_BOAT)
  if (!isShowCrew)
    return

  let { crewPrevCount, crewCurrCount } = unitInfo
  if (isInitUpdate || crewPrevCount <= 0)
    unitInfo.crewPrevCount = crewCurrCount

  let crewLost = crewCurrCount - crewPrevCount
  let needSkipAnim = isInitUpdate || crewLost == 0

  unitInfo.crewTotalCount = data?.crewTotalCount ?? camInfo?.crewTotal ?? -1
  let aliveCount = data?.crewAliveCount ?? camInfo?.crewAlive ?? -1

  minAliveCrewCount = data?.crewAliveMin ?? camInfo?.crewAliveMin ?? minAliveCrewCount

  let crewNestObj = hitCamNest.findObject("crew_lifebar_nest")
  let alivePercent = unitInfo.crewTotalCount > 0 ? aliveCount / unitInfo.crewTotalCount.tofloat() : 1
  let minAliveCrewPercent = unitInfo.crewTotalCount > 0 ? minAliveCrewCount / unitInfo.crewTotalCount.tofloat() : 0
  updateCrewLifebar(crewNestObj, alivePercent, { minAliveCrewPercent, needSkipAnim })

  if (isInitUpdate) {
    clearTimer(canAddLossTextTimer)
    canAddLossText = false
    return
  }
  setTimeout(TIME_TO_SUM_CREW_LOST, showCrewLoss)
}

let fullHealthColor = "#909E35"
let healthColorConfig = [
  { remainingHp = 0.25, color = "#FD0001" }
  { remainingHp = 0.75,  color = "#F6B236" }
]



























function sendHudHitCameraState() {
  eventbus_send("setHudHitCameraState", getHitCameraAABB())
}

function update() {
  if (!(hitCamNest?.isValid() ?? false))
    return

  hitCamNest.show(isVisible)
  if (!isVisible)
    return

  updateFadeAnimation()
  updateTitle()

  deferOnce(sendHudHitCameraState)
}

function hitCameraReinit() {
  isEnabled = get_option_xray_kill()
  update()
}

function updateHitcamContentBlk() {
  if (infoObj?.isValid() ?? false) {
    let guiScene = infoObj.getScene()
    let markupFilename = debuffTemplates?[curUnitType]
    if (markupFilename)
      guiScene.replaceContent(infoObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(infoObj, "", 0, this)
  }
  if (damageStatusObj?.isValid() ?? false) {
    let guiScene = damageStatusObj.getScene()
    let markupFilename = damageStatusTemplates?[curUnitType]
    if (markupFilename)
      guiScene.replaceContent(damageStatusObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(damageStatusObj, "", 0, this)
  }
}

function onHitCameraEvent(mode, result, info) {
  let newUnitType = info?.unitType ?? curUnitType
  let needResetUnitType = newUnitType != curUnitType

  let needFade   = mode == HIT_CAMERA_FADE_OUT
  let isStarted  = mode == HIT_CAMERA_START
  isVisible      = isEnabled && (isStarted || needFade || mode == HIT_CAMERA_FADE_IN || mode == HIT_CAMERA_START)
  stopFadeTimeS  = needFade ? (info?.stopFadeTime ?? -1) : -1
  hitResult      = result
  curUnitId      = info?.unitId ?? curUnitId
  curUnitVersion = info?.unitVersion ?? curUnitVersion
  curUnitType    = newUnitType
  continueShowingOnSwitchHud = isVisible && (info?.continueShowingOnSwitchHud ?? false)

  if (isStarted) {
    camInfo.replace_with(clone info)
    if ((hitCamNest?.isValid() ?? false)) {
      let animObj = hitCamNest.findObject("critAnim")
      animObj["color-factor"] = "0"
      animObj.needAnim = "no"
    }
    canShowCritAnimation = true
  }

  if (needResetUnitType)
    updateHitcamContentBlk()

  if (isVisible) {
    let isFirstEvent = unitsInfo?[curUnitId] == null
    local unitInfo = getTargetInfo(curUnitId, curUnitVersion,
      curUnitType, isKillingHitResult(hitResult), info?.unitName)

    foreach (item in (debuffsListsByUnitType?[curUnitType] ?? [])) {
      updateDebuffItem(item, unitInfo)

      if (item?.needShowChange && (!isStarted || needFade)) {
        unitInfo.crewPrevCount = unitInfo.crewCurrCount
      }
    }

    if (unitInfo.isKilled)
      unitInfo.isKillProcessed = true
    updateCrewCount(unitInfo, null, isFirstEvent)
  }
  else
    cleanupUnitsInfo()

  update()
}

function addFireIndicator(fireData) {
  let iconBlk = handyman.renderCached("%gui/hud/hitCamIndicator.tpl",
    {
      posX = fireData.screenPosX.tointeger(), posY = fireData.screenPosY.tointeger(),
      icon = "#ui/gameuiskin#fire_indicator.avif",
      outlineIcon = "#ui/gameuiskin#fire_indicator_outline.avif",
      icWidth = "0.5@enemyDmgStatusWidth", icHeight = "0.5@enemyDmgStatusWidth",
      id = $"fire_{fireData.partId}"
    }
  )

  let camRenderObj = hitCamNest.findObject("indicators_nest")
  hitCamNest.getScene().appendWithBlk(camRenderObj, iconBlk, null)
  let indicator = hitCamNest.findObject($"fire_{fireData.partId}")
  fireIndicators[$"{fireData.partId}"] <- {data = fireData, obj = indicator, waitRemove = false}
}

function removeFireIndicator(fireName) {
  let fire = fireIndicators[fireName]
  if (fire.obj.isValid())
    hitCamNest.getScene().destroyElement(fire.obj)
  fireIndicators.$rawdelete(fireName)
}

function removeAllFireIndicators() {
  foreach (fire in fireIndicators) {
    hitCamNest.getScene().destroyElement(fire.obj)
  }
  fireIndicators.clear()
}

function onHitCameraUpdateFiresEvent(fireArr, hasCriticalFire) {
  if (hitCamNest == null || !hitCamNest.isValid())
    return

  if ((fireArr?.len() ?? 0) == 0) {
    if (fireIndicators.len() != 0)
      removeAllFireIndicators()
    return
  }

  foreach (fire in fireIndicators)
    fire.waitRemove = true

  foreach (fireData in fireArr) {
    let fireName = $"{fireData.partId}"
    if (!fireIndicators?[fireName]) {
      addFireIndicator(fireData)
    } else {
      let fire = fireIndicators[fireName]
      if (!fire.obj.isValid()) {
        fireIndicators.$rawdelete(fireName)
        continue
      }
      fire.waitRemove = false
      if (!u.isEqual(fireData, fire.data))
        fire.obj.pos = $"{fireData.screenPosX.tointeger()}, {fireData.screenPosY.tointeger()}"
    }
  }
  setDamageStatus("fire_status", 1, hasCriticalFire)

  foreach (fireName, fire in fireIndicators)
    if (fire.waitRemove)
      removeFireIndicator(fireName)
}

function onEnemyPartDamage(data) {
  if (!isEnabled)
    return

  let unitInfo = getTargetInfo(data?.unitId ?? -1, data?.unitVersion ?? -1,
    data?.unitType ?? ES_UNIT_TYPE_INVALID, data?.unitKilled ?? false)

  local partName = null
  local partDmName = null
  local isPartKilled = data?.partKilled ?? false

  if (!unitInfo.isKilled) {
    partName = data?.partName
    if (!partName || !isInArray(partName, unitInfo.trackedPartNames))
      return

    let parts = unitInfo.parts
    if (!(partName in parts))
      parts[partName] <- { dmParts = {} }

    partDmName = data?.partDmName
    if (partDmName != null) {
      if (!(partDmName in parts[partName].dmParts))
        parts[partName].dmParts[partDmName] <- { partKilled = isPartKilled }
      let dmPart = parts[partName].dmParts[partDmName]

      isPartKilled = isPartKilled ||  dmPart.partKilled
      dmPart.partKilled = isPartKilled

      foreach (k, v in data)
        dmPart[k] <- v

      let isPartDead = dmPart?.partDead ?? false
      let partHp  = dmPart?.partHp ?? 1.0
      dmPart._hp <- (isPartKilled || isPartDead) ? 0.0 : partHp
    }
  }

  if (isVisible && unitInfo.unitId == curUnitId) {
    let isKill = isPartKilled || (unitInfo.isKilled && !unitInfo.isKillProcessed)

    foreach (item in (debuffsListsByUnitType?[unitInfo.unitType] ?? []))
      if (!item.isUpdateByEnemyDamageState && isKill && item.parts.contains(partName))
        updateDebuffItem(item, unitInfo, partName, data)

    if (unitInfo.isKilled)
      unitInfo.isKillProcessed = true
  }
}

function onHitCameraImportantEvents(data) {
  if (!isVisible)
    return

  let { unitId, unitVersion, unitType } = data
  let unitInfo = getTargetInfo(unitId, unitVersion,
    unitType, isKillingHitResult(hitResult))
  foreach (key in importantEventKeys) {
    let events = data?[key] ?? []
    if (events.len() == 0)
      continue
    let unitInfoEvents = unitInfo.importantEvents?[key] ?? []
    if (type(events) == "table") {
      unitInfoEvents.append(events)
      if (key == "ammoEvent")
        setDamageStatus(events.damageType == 0 ? "ammo_fire_status" : "ammo_explosion_status", 1)
    } else {
      unitInfoEvents.extend(events)
      if (key == "ammoEvent") {
        foreach (event in events)
          setDamageStatus(event.damageType == 0 ? "ammo_fire_status" : "ammo_explosion_status", 1)
      }
    }
    unitInfo.importantEvents[key] <- unitInfoEvents
  }

  showCritAnimation()
  updateImportantTitle()
}

function onEnemyDamageState(event) {
  let needResetUnitType = curUnitType != event?.unitType
  let isNewUnit = curUnitId != event?.unitId
  curUnitId = event?.unitId ?? curUnitId
  curUnitType = event?.unitType ?? curUnitType
  curUnitVersion = event?.unitVersion ?? curUnitVersion

  if (needResetUnitType)
    updateHitcamContentBlk()

  if (curUnitType in (damageStatusTemplates)) {
    let { artilleryHealth = 100, auxiliaryHealth = 100, hasFire = false,
    hasCriticalFire = false, engineHealth = 100, torpedoTubesHealth = 100, ruddersHealth = 100, hasBreach = false } = event
    setDamageStatus("artillery_health", artilleryHealth)
    setDamageStatus("auxiliary_health", auxiliaryHealth)
    setDamageStatus("fire_status", hasFire ? 1 : -1, hasCriticalFire)
    setDamageStatus("engine_health", engineHealth)
    setDamageStatus("torpedo_tubes_health", torpedoTubesHealth)
    setDamageStatus("rudders_health", ruddersHealth)
    setDamageStatus("breach_status", hasBreach ? 1 : -1)
  }

  let unitInfo = getTargetInfo(curUnitId, curUnitVersion,
    curUnitType, isKillingHitResult(hitResult))

  foreach (item in (debuffsListsByUnitType?[curUnitType] ?? []))
    if (item.isUpdateByEnemyDamageState)
      updateDebuffItem(item, unitInfo, null, event)

  updateCrewCount(unitInfo, event, isNewUnit)
  


}

function hitCameraInit(nest) {
  if (!(nest?.isValid() ?? false))
    return

  if ((hitCamNest?.isValid() ?? false) && hitCamNest.isEqual(nest))
    return

  hitCamNest = nest
  titleObj = hitCamNest.findObject("title")
  infoObj = hitCamNest.findObject("info")
  damageStatusObj = hitCamNest.findObject("damageStatus")

  if (!hasFeature("HitCameraTargetStateIconsTank") && (ES_UNIT_TYPE_TANK in debuffTemplates))
    debuffTemplates.$rawdelete(ES_UNIT_TYPE_TANK)

  foreach (unitType, _fn in debuffTemplates) {
    debuffsListsByUnitType[unitType] <- g_hud_enemy_debuffs.getTypesArrayByUnitType(unitType)
    trackedPartNamesByUnitType[unitType] <- g_hud_enemy_debuffs.getTrackedPartNamesByUnitType(unitType)
  }

  minAliveCrewCount = getMinAliveCrewCount()

  g_hud_event_manager.subscribe("EnemyDamageState", onEnemyDamageState, hitCamNest)
  g_hud_event_manager.subscribe("HitCameraImportanEvents", onHitCameraImportantEvents, hitCamNest)
  g_hud_event_manager.subscribe("LocalPlayerDead", @(_eventData) reset(), hitCamNest)

  if (!continueShowingOnSwitchHud)
    reset()
  hitCameraReinit()
}

addListenersWithoutEnv({
  function LoadingStateChange(_) {
    if (!isInFlight())
      reset()
  }
})

let debugFireReference = {
  partId = 821
  screenPosY = 130.218
  screenPosX = 203.477
  timeToShowSec = 0
}
local debugFires = []
function debugUpdateFireEvents() {
  let curTime = get_charserver_time_sec()
  debugFires = debugFires.filter(@(v) v.timeToShowSec >= curTime)
    .map(@(v) v.__merge({screenPosY = v.screenPosY + rnd_float(-5.0, 5.0), screenPosX = v.screenPosX + rnd_float(-5.0, 5.0)}))
  if (debugFires.len() < 100)
    debugFires.append(debugFireReference.__merge({ timeToShowSec = curTime + rnd_int(30, 100), partId = rnd_int(815, 850)
      screenPosX = rnd_float(0.983, 420.763), screenPosY = rnd_float(0.123, 220.123) }))
  onHitCameraUpdateFiresEvent(debugFires.map(@(v) {}.__merge(v)), false)
}

register_command(@() setInterval(0.3, debugUpdateFireEvents), "ui.debug.start_hit_camera_fire_events")
register_command(
  function() {
    clearTimer(debugUpdateFireEvents)
    debugFires.clear()
  },
  "ui.debug.stop_hit_camera_fire_events")

eventbus_subscribe("EnemyPartsDamage", function(allDamageData) {
  foreach (data in allDamageData) {
    onEnemyPartDamage(data)
  }
})

eventbus_subscribe("on_hit_camera_event", function(event) {
  let {mode, result, info} = event
  onHitCameraEvent(mode, result, info)
  if (isKillingHitResult(result))
    g_hud_event_manager.onHudEvent("HitcamTargetKilled", info)
})

eventbus_subscribe("on_hitcamera_update_fires_event", function(event) {
  let {fireArr, hasCriticalFire} = event
  if (debugFires.len() > 0)
    return
  onHitCameraUpdateFiresEvent(fireArr, hasCriticalFire)
})

function debugCreateEnemyDamage(crewTotal, alivePercent) {
  let data = {
    unitId = curUnitId >= 0 ? curUnitId : 0
    unitVersion = 0
    unitType = 2
    hasFire = false
    hasCriticalFire = false
    crewAliveMin = 100
    crewAliveCount = (crewTotal * alivePercent).tointeger()
    crewTotalCount = crewTotal
    buoyancy = 1.0
    hasBreach = false
    engineHealth = 100
    torpedoTubesHealth = 100
    artilleryHealth = 100
    auxiliaryHealth = 100
    ruddersHealth = 100
    curRelativeHealth = 1.0
    updateDebuffsOnly = true
    coverPartsRelHp = {
      val = [ 1.0
      ,1.0
      ,1.0
      ,1.0
      ,1.0
      ,1.0
      ,1.0
      ,1.0]
    }
  }
  g_hud_event_manager.onHudEvent("EnemyDamageState", data)
}

function dropEnemyDamage(crewTotal, alivePercent) {
  debugCreateEnemyDamage(crewTotal, alivePercent/100.0)
}

register_command(@(crewTotal, alivePercent) dropEnemyDamage(crewTotal, alivePercent), "hud.simCrewDamage")

registerForNativeCall("get_hit_camera_aabb", getHitCameraAABB)

return {
  hitCameraInit
  hitCameraReinit
  getHitCameraAABB
}