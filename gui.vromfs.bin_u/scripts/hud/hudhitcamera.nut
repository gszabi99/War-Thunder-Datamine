from "hitCamera" import *
let { utf8ToUpper } = require("%sqstd/string.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

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
}

let debuffTemplates = {
  [::ES_UNIT_TYPE_TANK] = "%gui/hud/hudEnemyDebuffsTank.blk",
  [::ES_UNIT_TYPE_BOAT] = "%gui/hud/hudEnemyDebuffsShip.blk",
  [::ES_UNIT_TYPE_SHIP] = "%gui/hud/hudEnemyDebuffsShip.blk",
}

let damageStatusTemplates = {
  [::ES_UNIT_TYPE_BOAT] = "%gui/hud/hudEnemyDamageStatusShip.blk",
  [::ES_UNIT_TYPE_SHIP] = "%gui/hud/hudEnemyDamageStatusShip.blk",
}

let debuffsListsByUnitType = {}
let trackedPartNamesByUnitType = {}

local scene     = null
local titleObj  = null
local infoObj   = null
local damageStatusObj = null
local isEnabled = true
local isVisible = false
local stopFadeTimeS = -1
local hitResult = DM_HIT_RESULT_NONE
local curUnitId = -1
local curUnitVersion = -1
local curUnitType = ::ES_UNIT_TYPE_INVALID
local camInfo   = {}
local unitsInfo = {}

let getDamageStatusByHealth = @(health)
  health == 100 ? "none"
    : health >= 70  ? "minor"
    : health >= 40  ? "moderate"
    : health >= 10  ? "major"
    : health > 0    ? "critical"
    : health == 0   ? "fatal"
    : "none"

let function setDamageStatus(statusObjId, health) {
  if (!damageStatusObj?.isValid())
    return

  let obj = damageStatusObj.findObject(statusObjId)
  if (!obj?.isValid())
    return

  obj.damage = getDamageStatusByHealth(health)
}

let function onEnemyDamageState(event) {
  setDamageStatus("artillery_health", event.artilleryHealth)
  setDamageStatus("fire_status", event.hasFire ? 1 : -1)
  setDamageStatus("engine_health", event.engineHealth)
  setDamageStatus("torpedo_tubes_health", event.torpedoTubesHealth)
  setDamageStatus("rudders_health", event.ruddersHealth)
  setDamageStatus("breach_status", event.hasBreach ? 1 : -1)
}

let function updateFadeAnimation() {
  let needFade = stopFadeTimeS > 0
  scene["transp-time"] = needFade ? (stopFadeTimeS*1000).tointeger() : 1
  scene["transp-base"] = needFade ? 255 : 0
  scene["transp-end"]  = needFade ? 0 : 255
  scene.setFloatProp(animTimerPid, 0.0)
}

let getHitCameraAABB = @() ::get_dagui_obj_aabb(scene)
let isKillingHitResult = @(result) result >= DM_HIT_RESULT_KILL

let function reset() {
  isVisible = false
  stopFadeTimeS = -1
  hitResult = DM_HIT_RESULT_NONE
  curUnitId = -1
  curUnitVersion = -1
  curUnitType = ::ES_UNIT_TYPE_INVALID

  camInfo.clear()
  unitsInfo.clear()
}

let function update() {
  if (!(scene?.isValid() ?? false))
    return

  scene.show(isVisible)
  if (!isVisible)
    return

  updateFadeAnimation()
  if (!(titleObj?.isValid() ?? false))
    return

  let style = styles?[hitResult] ?? "none"
  scene.result = style
  let isVisibleTitle = hitResult != DM_HIT_RESULT_NONE
  titleObj.show(isVisibleTitle)
  if (isVisibleTitle)
    titleObj.setValue(utf8ToUpper(::loc($"hitcamera/result/{style}")))
}

let function hitCameraReinit() {
  isEnabled = ::get_option_xray_kill()
  update()
}

let function getTargetInfo(unitId, unitVersion, unitType, isUnitKilled) {
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
    }

  let info = unitsInfo[unitId]
  info.time = ::get_usefull_total_time()
  info.isKilled = info.isKilled || isUnitKilled

  return info
}

let function cleanupUnitsInfo() {
  let old = ::get_usefull_total_time() - 5.0
  let oldUnits = []
  foreach (unitId, info in unitsInfo)
    if (info.isKilled && info.time < old)
      oldUnits.append(unitId)
  foreach (unitId in oldUnits)
    delete unitsInfo[unitId]
}

let function updateDebuffItem(item, unitInfo, partName = null, dmgParams = null) {
  let data = item.getInfo(camInfo, unitInfo, partName, dmgParams)
  let isShow = data != null

  if (!(infoObj?.isValid() ?? false))
    return

  let obj = infoObj.findObject(item.id)
  if (!(obj?.isValid() ?? false))
    return
  obj.show(isShow)
  if (!isShow)
    return

  obj.state = data.state
  let labelObj = obj.findObject("label")
  if (labelObj?.isValid() ?? false)
    labelObj.setValue(data.label)
}

let function onHitCameraEvent(mode, result, info) {
  let newUnitType = info?.unitType ?? curUnitType
  let needResetUnitType = newUnitType != curUnitType

  let needFade   = mode == HIT_CAMERA_FADE_OUT
  let isStarted  = mode == HIT_CAMERA_START
  isVisible      = isEnabled && (isStarted || needFade)
  stopFadeTimeS  = needFade ? (info?.stopFadeTime ?? -1) : -1
  hitResult      = result
  curUnitId      = info?.unitId ?? curUnitId
  curUnitVersion = info?.unitVersion ?? curUnitVersion
  curUnitType    = newUnitType
  if (isStarted)
    camInfo      = info

  if (needResetUnitType && (infoObj?.isValid() ?? false)) {
    let guiScene = infoObj.getScene()
    let markupFilename = debuffTemplates?[curUnitType]
    if (markupFilename)
      guiScene.replaceContent(infoObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(infoObj, "", 0, this)
  }

  if (needResetUnitType && damageStatusObj?.isValid()) {
    let guiScene = damageStatusObj.getScene()
    let markupFilename = damageStatusTemplates?[curUnitType]
    if (markupFilename)
      guiScene.replaceContent(damageStatusObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(damageStatusObj, "", 0, this)
  }

  if (isVisible) {
    let unitInfo = getTargetInfo(curUnitId, curUnitVersion,
      curUnitType, isKillingHitResult(hitResult))
    foreach (item in (debuffsListsByUnitType?[curUnitType] ?? []))
      updateDebuffItem(item, unitInfo)

    if (unitInfo.isKilled)
      unitInfo.isKillProcessed = true
  }
  else
    cleanupUnitsInfo()

  update()
}

let function onEnemyPartDamage(data) {
  if (!isEnabled)
    return

  let unitInfo = getTargetInfo(data?.unitId ?? -1, data?.unitVersion ?? -1,
    data?.unitType ?? ::ES_UNIT_TYPE_INVALID, data?.unitKilled ?? false)

  local partName = null
  local partDmName = null
  local isPartKilled = data?.partKilled ?? false

  if (!unitInfo.isKilled)
  {
    partName = data?.partName
    if (!partName || !::isInArray(partName, unitInfo.trackedPartNames))
      return

    let parts = unitInfo.parts
    if (!(partName in parts))
      parts[partName] <- { dmParts = {} }

    partDmName = data?.partDmName
    if (!(partDmName in parts[partName].dmParts))
      parts[partName].dmParts[partDmName] <- { partKilled = isPartKilled }
    let dmPart = parts[partName].dmParts[partDmName]

    isPartKilled = isPartKilled ||  dmPart.partKilled
    dmPart.partKilled = isPartKilled

    foreach (k, v in data)
      dmPart[k] <- v

    let isPartDead = dmPart?.partDead ?? false
    let partHpCur  = dmPart?.partHpCur ?? 1.0
    dmPart._hp <- (isPartKilled || isPartDead) ? 0.0 : partHpCur
  }

  if (isVisible && unitInfo.unitId == curUnitId) {
    let isKill = isPartKilled || (unitInfo.isKilled && !unitInfo.isKillProcessed)

    foreach (item in (debuffsListsByUnitType?[unitInfo.unitType] ?? []))
      if (!item.isUpdateOnKnownPartKillsOnly || (isKill && ::isInArray(partName, item.parts)))
        updateDebuffItem(item, unitInfo, partName, data)

    if (unitInfo.isKilled)
      unitInfo.isKillProcessed = true
  }
}

let function hitCameraInit(nest) {
  if (!(nest?.isValid() ?? false))
    return

  if ((scene?.isValid() ?? false) && scene.isEqual(nest))
    return

  scene = nest
  titleObj = scene.findObject("title")
  infoObj  = scene.findObject("info")
  damageStatusObj = scene.findObject("damageStatus")

  if (!::has_feature("HitCameraTargetStateIconsTank") && (::ES_UNIT_TYPE_TANK in debuffTemplates))
    delete debuffTemplates[::ES_UNIT_TYPE_TANK]

  foreach (unitType, fn in debuffTemplates) {
    debuffsListsByUnitType[unitType] <- ::g_hud_enemy_debuffs.getTypesArrayByUnitType(unitType)
    trackedPartNamesByUnitType[unitType] <- ::g_hud_enemy_debuffs.getTrackedPartNamesByUnitType(unitType)
  }

  ::g_hud_event_manager.subscribe("EnemyPartDamage", onEnemyPartDamage, this)
  ::g_hud_event_manager.subscribe("EnemyDamageState", onEnemyDamageState, this)

  reset()
  hitCameraReinit()
}

addListenersWithoutEnv({
  function LoadingStateChange(_) {
    if (!::is_in_flight())
      reset()
  }
})

::on_hit_camera_event <- function on_hit_camera_event(mode, result = DM_HIT_RESULT_NONE, info = {}) // called from client
{
  onHitCameraEvent(mode, result, info)

  if (isKillingHitResult(result))
    ::g_hud_event_manager.onHudEvent("HitcamTargetKilled", info)
}

::get_hit_camera_aabb <- getHitCameraAABB // called from client

return {
  hitCameraInit
  hitCameraReinit
  getHitCameraAABB
}
