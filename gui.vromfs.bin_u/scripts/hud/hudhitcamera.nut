::on_hit_camera_event <- function on_hit_camera_event(mode, result = ::DM_HIT_RESULT_NONE, info = {}) // called from client
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

  isEnabled = true

  isVisible = false
  hitResult = ::DM_HIT_RESULT_NONE
  unitId = -1
  unitVersion = -1
  unitType = ::ES_UNIT_TYPE_INVALID

  camInfo   = {}
  unitsInfo = {}

  debuffTemplates = {
    [::ES_UNIT_TYPE_TANK] = "gui/hud/hudEnemyDebuffsTank.blk",
    [::ES_UNIT_TYPE_BOAT] = "gui/hud/hudEnemyDebuffsShip.blk",
    [::ES_UNIT_TYPE_SHIP] = "gui/hud/hudEnemyDebuffsShip.blk",
  }
  debuffsListsByUnitType = {}
  trackedPartNamesByUnitType = {}

  styles = {
    [::DM_HIT_RESULT_NONE]      = "none",
    [::DM_HIT_RESULT_RICOSHET]  = "ricochet",
    [::DM_HIT_RESULT_BOUNCE]    = "bounce",
    [::DM_HIT_RESULT_HIT]       = "hit",
    [::DM_HIT_RESULT_BURN]      = "burn",
    [::DM_HIT_RESULT_CRITICAL]  = "critical",
    [::DM_HIT_RESULT_KILL]      = "kill",
    [::DM_HIT_RESULT_METAPART]  = "hull",
    [::DM_HIT_RESULT_AMMO]      = "ammo",
    [::DM_HIT_RESULT_FUEL]      = "fuel",
    [::DM_HIT_RESULT_CREW]      = "crew",
    [::DM_HIT_RESULT_TORPEDO]   = "torpedo",
    [::DM_HIT_RESULT_BREAKING]  = "breaking",
  }
}

g_hud_hitcamera.init <- function init(_nest)
{
  if (!::checkObj(_nest))
    return

  if (::checkObj(scene) && scene.isEqual(_nest))
    return

  scene = _nest
  titleObj = scene.findObject("title")
  infoObj  = scene.findObject("info")

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
  hitResult = ::DM_HIT_RESULT_NONE
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

  if (::check_obj(titleObj))
  {
    local style = ::getTblValue(hitResult, styles, "none")
    titleObj.show(hitResult != ::DM_HIT_RESULT_NONE)
    titleObj.setValue(::loc("hitcamera/result/" + style))
    scene.result = style
  }
}

g_hud_hitcamera.getAABB <- function getAABB()
{
  return ::get_dagui_obj_aabb(scene)
}

g_hud_hitcamera.isKillingHitResult <- function isKillingHitResult(result)
{
  return result >= ::DM_HIT_RESULT_KILL
}

g_hud_hitcamera.onHitCameraEvent <- function onHitCameraEvent(mode, result, info)
{
  local newUnitType = ::getTblValue("unitType", info, unitType)
  local needResetUnitType = newUnitType != unitType

  isVisible   = isEnabled && mode == ::HIT_CAMERA_START
  hitResult   = result
  unitId      = ::getTblValue("unitId", info, unitId)
  unitVersion = ::getTblValue("unitVersion", info, unitVersion)
  unitType    = newUnitType
  camInfo     = info

  if (needResetUnitType && ::check_obj(infoObj))
  {
    local guiScene = infoObj.getScene()
    local markupFilename = ::getTblValue(unitType, debuffTemplates)
    if (markupFilename)
      guiScene.replaceContent(infoObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(infoObj, "", 0, this)
  }

  if (isVisible)
  {
    local unitInfo = getTargetInfo(unitId, unitVersion, unitType, isKillingHitResult(hitResult))
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

  local info = unitsInfo[unitId]
  info.time = ::get_usefull_total_time()
  info.isKilled = info.isKilled || isUnitKilled

  return info
}

g_hud_hitcamera.cleanupUnitsInfo <- function cleanupUnitsInfo()
{
  local old = ::get_usefull_total_time() - 5.0
  foreach (unitId, info in unitsInfo)
    if (info.isKilled && info.time < old)
      delete unitsInfo[unitId]
}

g_hud_hitcamera.updateDebuffItem <- function updateDebuffItem(item, camInfo, unitInfo, partName = null, dmgParams = null)
{
  local data = item.getInfo(camInfo, unitInfo, partName, dmgParams)
  local isShow = data != null

  local obj = ::check_obj(infoObj) ? infoObj.findObject(item.id) : null
  if (!::check_obj(obj))
    return
  obj.show(isShow)
  if (!isShow)
    return

  obj.state = data.state
  local labelObj = obj.findObject("label")
  if (::check_obj(labelObj))
    labelObj.setValue(data.label)
}

g_hud_hitcamera.onEnemyPartDamage <- function onEnemyPartDamage(data)
{
  if (!isEnabled)
    return

  local unitInfo = getTargetInfo(
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

    local parts = unitInfo.parts
    if (!(partName in parts))
      parts[partName] <- { dmParts = {} }

    partDmName = ::getTblValue("partDmName", data)
    if (!(partDmName in parts[partName].dmParts))
      parts[partName].dmParts[partDmName] <- { partKilled = isPartKilled }
    local dmPart = parts[partName].dmParts[partDmName]

    isPartKilled = isPartKilled ||  dmPart.partKilled
    dmPart.partKilled = isPartKilled

    foreach (k, v in data)
      dmPart[k] <- v

    local isPartDead   = ::getTblValue("partDead", dmPart, false)
    local partHpCur  = ::getTblValue("partHpCur", dmPart, 1.0)
    dmPart._hp <- (isPartKilled || isPartDead) ? 0.0 : partHpCur
  }

  if (isVisible && unitInfo.unitId == unitId)
  {
    local isKill = isPartKilled || (unitInfo.isKilled && !unitInfo.isKillProcessed)

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
