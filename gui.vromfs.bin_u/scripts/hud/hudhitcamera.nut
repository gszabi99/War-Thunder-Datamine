from "hitCamera" import *
let { utf8ToUpper } = require("%sqstd/string.nut")

let animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

::on_hit_camera_event <- function on_hit_camera_event(mode, result = DM_HIT_RESULT_NONE, info = {}) // called from client
{
  ::g_hud_hitcamera.onHitCameraEvent(mode, result, info)

  if (::g_hud_hitcamera.isKillingHitResult(result))
    ::g_hud_event_manager.onHudEvent("HitcamTargetKilled", info)
}

::get_hit_camera_aabb <- function get_hit_camera_aabb() // called from client
{
  return ::g_hud_hitcamera.getAABB()
}

::g_hud_hitcamera <- {
  scene     = null
  titleObj  = null
  infoObj   = null
  damageStatusObj = null

  isEnabled = true

  isVisible = false
  stopFadeTimeS = -1
  hitResult = DM_HIT_RESULT_NONE
  unitId = -1
  unitVersion = -1
  unitType = ::ES_UNIT_TYPE_INVALID

  camInfo   = {}
  unitsInfo = {}

  debuffTemplates = {
    [::ES_UNIT_TYPE_TANK] = "%gui/hud/hudEnemyDebuffsTank.blk",
    [::ES_UNIT_TYPE_BOAT] = "%gui/hud/hudEnemyDebuffsShip.blk",
    [::ES_UNIT_TYPE_SHIP] = "%gui/hud/hudEnemyDebuffsShip.blk",
  }

  damageStatusTemplates = {
    [::ES_UNIT_TYPE_BOAT] = "%gui/hud/hudEnemyDamageStatusShip.blk",
    [::ES_UNIT_TYPE_SHIP] = "%gui/hud/hudEnemyDamageStatusShip.blk",
  }

  debuffsListsByUnitType = {}
  trackedPartNamesByUnitType = {}

  styles = {
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

  function onEnemyDamageState(event) {
    setDamageStatus("artillery_health", event.artilleryHealth)
    setDamageStatus("fire_status", event.hasFire ? 1 : -1)
    setDamageStatus("engine_health", event.engineHealth)
    setDamageStatus("torpedo_tubes_health", event.torpedoTubesHealth)
    setDamageStatus("rudders_health", event.ruddersHealth)
    setDamageStatus("breach_status", event.hasBreach ? 1 : -1)
  }

  function setDamageStatus(statusObjId, health) {
    if (!damageStatusObj?.isValid())
      return

    let obj = damageStatusObj.findObject(statusObjId)
    if (!obj?.isValid())
      return

    obj.damage = getDamageStatusByHealth(health)
  }

  function getDamageStatusByHealth(health) {
    return health == 100 ? "none"
         : health >= 70  ? "minor"
         : health >= 40  ? "moderate"
         : health >= 10  ? "major"
         : health > 0    ? "critical"
         : health == 0   ? "fatal"
         : "none"
  }

  function updateFadeAnimation() {
    let needFade = stopFadeTimeS > 0
    scene["transp-time"] = needFade ? (stopFadeTimeS*1000).tointeger() : 1
    scene["transp-base"] = needFade ? 255 : 0
    scene["transp-end"]  = needFade ? 0 : 255
    scene.setFloatProp(animTimerPid, 0.0)
  }
}

g_hud_hitcamera.init <- function init(nest)
{
  if (!::checkObj(nest))
    return

  if (::checkObj(scene) && scene.isEqual(nest))
    return

  scene = nest
  titleObj = scene.findObject("title")
  infoObj  = scene.findObject("info")
  damageStatusObj = scene.findObject("damageStatus")

  if (!::has_feature("HitCameraTargetStateIconsTank") && (::ES_UNIT_TYPE_TANK in debuffTemplates))
    delete debuffTemplates[::ES_UNIT_TYPE_TANK]

  foreach (unitType, fn in debuffTemplates)
  {
    debuffsListsByUnitType[unitType] <- ::g_hud_enemy_debuffs.getTypesArrayByUnitType(unitType)
    trackedPartNamesByUnitType[unitType] <- ::g_hud_enemy_debuffs.getTrackedPartNamesByUnitType(unitType)
  }

  ::g_hud_event_manager.subscribe("EnemyPartDamage", function (params) {
      onEnemyPartDamage(params)
    }, this)
  ::g_hud_event_manager.subscribe("EnemyDamageState", onEnemyDamageState, this)

  reset()
  reinit()
}

g_hud_hitcamera.reinit <- function reinit()
{
  isEnabled = ::get_option_xray_kill()
  update()
}

g_hud_hitcamera.reset <- function reset()
{
  isVisible = false
  stopFadeTimeS = -1
  hitResult = DM_HIT_RESULT_NONE
  unitId = -1
  unitVersion = -1
  unitType = ::ES_UNIT_TYPE_INVALID

  camInfo   = {}
  unitsInfo = {}
}

g_hud_hitcamera.update <- function update()
{
  if (!::checkObj(scene))
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

g_hud_hitcamera.getAABB <- function getAABB()
{
  return ::get_dagui_obj_aabb(scene)
}

g_hud_hitcamera.isKillingHitResult <- function isKillingHitResult(result)
{
  return result >= DM_HIT_RESULT_KILL
}

g_hud_hitcamera.onHitCameraEvent <- function onHitCameraEvent(mode, result, info)
{
  let newUnitType = ::getTblValue("unitType", info, unitType)
  let needResetUnitType = newUnitType != unitType

  let needFade = mode == HIT_CAMERA_FADE_OUT
  isVisible   = isEnabled && (mode == HIT_CAMERA_START || needFade)
  stopFadeTimeS = needFade ? (info?.stopFadeTime ?? -1) : -1
  hitResult   = result
  unitId      = ::getTblValue("unitId", info, unitId)
  unitVersion = ::getTblValue("unitVersion", info, unitVersion)
  unitType    = newUnitType
  camInfo     = info

  if (needResetUnitType && ::check_obj(infoObj))
  {
    let guiScene = infoObj.getScene()
    let markupFilename = ::getTblValue(unitType, debuffTemplates)
    if (markupFilename)
      guiScene.replaceContent(infoObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(infoObj, "", 0, this)
  }

  if (needResetUnitType && damageStatusObj?.isValid()) {
    let guiScene = damageStatusObj.getScene()
    let markupFilename = damageStatusTemplates?[unitType]
    if (markupFilename)
      guiScene.replaceContent(damageStatusObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(damageStatusObj, "", 0, this)
  }

  if (isVisible)
  {
    let unitInfo = getTargetInfo(unitId, unitVersion, unitType, isKillingHitResult(hitResult))
    foreach (item in ::getTblValue(unitType, debuffsListsByUnitType, []))
      updateDebuffItem(item, camInfo, unitInfo)

    if (unitInfo.isKilled)
      unitInfo.isKillProcessed = true
  }
  else
    cleanupUnitsInfo()

  update()
}

g_hud_hitcamera.getTargetInfo <- function getTargetInfo(unitId, unitVersion, unitType, isUnitKilled)
{
  if (!(unitId in unitsInfo) || unitsInfo[unitId].unitVersion != unitVersion)
    unitsInfo[unitId] <- {
      unitId = unitId
      unitVersion = unitVersion
      unitType = unitType
      parts = {}
      trackedPartNames = ::getTblValue(unitType, trackedPartNamesByUnitType, [])
      isKilled = isUnitKilled
      isKillProcessed = false
      time = 0
    }

  let info = unitsInfo[unitId]
  info.time = ::get_usefull_total_time()
  info.isKilled = info.isKilled || isUnitKilled

  return info
}

g_hud_hitcamera.cleanupUnitsInfo <- function cleanupUnitsInfo()
{
  let old = ::get_usefull_total_time() - 5.0
  let oldUnits = []
  foreach (unitId, info in unitsInfo)
    if (info.isKilled && info.time < old)
      oldUnits.append(unitId)
  foreach (unitId in oldUnits)
    delete unitsInfo[unitId]
}

g_hud_hitcamera.updateDebuffItem <- function updateDebuffItem(item, camInfo, unitInfo, partName = null, dmgParams = null)
{
  let data = item.getInfo(camInfo, unitInfo, partName, dmgParams)
  let isShow = data != null

  let obj = ::check_obj(infoObj) ? infoObj.findObject(item.id) : null
  if (!::check_obj(obj))
    return
  obj.show(isShow)
  if (!isShow)
    return

  obj.state = data.state
  let labelObj = obj.findObject("label")
  if (::check_obj(labelObj))
    labelObj.setValue(data.label)
}

g_hud_hitcamera.onEnemyPartDamage <- function onEnemyPartDamage(data)
{
  if (!isEnabled)
    return

  let unitInfo = getTargetInfo(
    ::getTblValue("unitId", data, -1),
    ::getTblValue("unitVersion", data, -1),
    ::getTblValue("unitType", data, ::ES_UNIT_TYPE_INVALID),
    ::getTblValue("unitKilled", data, false)
    )

  local partName = null
  local partDmName = null
  local isPartKilled = ::getTblValue("partKilled", data, false)

  if (!unitInfo.isKilled)
  {
    partName = ::getTblValue("partName", data)
    if (!partName || !::isInArray(partName, unitInfo.trackedPartNames))
      return

    let parts = unitInfo.parts
    if (!(partName in parts))
      parts[partName] <- { dmParts = {} }

    partDmName = ::getTblValue("partDmName", data)
    if (!(partDmName in parts[partName].dmParts))
      parts[partName].dmParts[partDmName] <- { partKilled = isPartKilled }
    let dmPart = parts[partName].dmParts[partDmName]

    isPartKilled = isPartKilled ||  dmPart.partKilled
    dmPart.partKilled = isPartKilled

    foreach (k, v in data)
      dmPart[k] <- v

    let isPartDead   = ::getTblValue("partDead", dmPart, false)
    let partHpCur  = ::getTblValue("partHpCur", dmPart, 1.0)
    dmPart._hp <- (isPartKilled || isPartDead) ? 0.0 : partHpCur
  }

  if (isVisible && unitInfo.unitId == unitId)
  {
    let isKill = isPartKilled || (unitInfo.isKilled && !unitInfo.isKillProcessed)

    foreach (item in ::getTblValue(unitInfo.unitType, debuffsListsByUnitType, []))
      if (!item.isUpdateOnKnownPartKillsOnly || (isKill && ::isInArray(partName, item.parts)))
        updateDebuffItem(item, camInfo, unitInfo, partName, data)

    if (unitInfo.isKilled)
      unitInfo.isKillProcessed = true
  }
}

g_hud_hitcamera.onEventLoadingStateChange <- function onEventLoadingStateChange(params)
{
  if (!::is_in_flight())
    reset()
}

::subscribe_handler(::g_hud_hitcamera, ::g_listener_priority.DEFAULT_HANDLER)
