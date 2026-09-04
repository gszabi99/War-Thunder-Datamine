from "console" import register_command
from "unitCalculcation" import buildBallisticTrajectoryAngleData, buildBallisticTrajectoryRangeData
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isMissileWeapon, isMissileBullet, isGuidedBomb } = require("%scripts/weaponry/weaponryInfo.nut")
let { graphColorList, getBulletCacheSaveId } = require("%scripts/weaponry/graphCompareBullets/bulletsGraphState.nut")
let { GraphCompareBulletsWnd } = require("%scripts/weaponry/graphCompareBullets/graphCompareBulletsWnd.nut")
let { mkSliderMarkup, mkModeButtonsMarkup } = require("%scripts/weaponry/graphCompareBullets/bulletsBallisticOptionsView.nut")
let { requestArmorPenetrationData } = require("%scripts/weaponry/graphCompareBullets/armorPenetrationDataRequest.nut")

enum ShotMode {
  ANGLE
  RANGE
}

let unitsTypesBulletsCanBeCompared = { 
  [ES_UNIT_TYPE_AIRCRAFT]   = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER],
  [ES_UNIT_TYPE_HELICOPTER] = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER],
  [ES_UNIT_TYPE_TANK]       = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER],
  [ES_UNIT_TYPE_SHIP]       = [ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT],
  [ES_UNIT_TYPE_BOAT]       = [ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT],
}.map(@(l) l.reduce(@(res, v) res.$rawset(v, true), {}))

function canRequestBallisticsData(weaponType, bulletType, hasNestedRocketBlk) {
  return !hasNestedRocketBlk
    && !isMissileWeapon(weaponType)
    && !isGuidedBomb(weaponType)
    && !isMissileBullet(bulletType)
}

let canRequestBulletBallisticsData = @(bullet)
  canRequestBallisticsData(bullet?.weaponType, bullet?.bulletParams.bulletType, bullet?.hasNestedRocketBlk ?? false)


function canBeComparedBulletsByUnitType(bullet, compareBulletsList) {
  if (compareBulletsList.len() == 0)
    return true
  let curBulletUniTypesList = unitsTypesBulletsCanBeCompared?[bullet.esUnitType]
  if (curBulletUniTypesList == null)
    return false

  return compareBulletsList.findvalue(@(v) v.esUnitType not in curBulletUniTypesList) == null
}

let shotAngleSetting = {
  id = "shotAngle"
  locId = "mainmenu/angle"
  minValue = 1
  maxValue = 60
  step = 1
  value = 10
  getValueText = @(value) $"{value}{loc("measureUnits/deg")}"
  getControlMarkup = mkSliderMarkup
  isVisible = @(settings) settings.shotMode == ShotMode.ANGLE
}

let targetRangeSetting = {
  id = "targetRange"
  locId = "distance"
  minValue = 100
  maxValue = 40000
  step = 100
  value = 1000
  getValueText = @(value) $"{value}{loc("measureUnits/meters_alt")}"
  getControlMarkup = mkSliderMarkup
  isVisible = @(settings) settings.shotMode == ShotMode.RANGE
}

let shotModeParams = {
  [ShotMode.ANGLE] = {
    setting = shotAngleSetting,
    buildTrajectoryData = buildBallisticTrajectoryAngleData
  },
  [ShotMode.RANGE] = {
    setting = targetRangeSetting,
    buildTrajectoryData = buildBallisticTrajectoryRangeData
  },
}

let getShotModeValue = @(settings) settings[shotModeParams[settings.shotMode].setting.id]

function requestBallisticsData(bullet, settings, handlerCb) {
  let { weaponBlkName, bulletName } = bullet
  if (!canRequestBulletBallisticsData(bullet)) {
    handlerCb({ weaponBlkName, bulletName })
    return
  }

  let { shotMode } = settings
  let shotModeValue = getShotModeValue(settings)
  let cb = @(ballisticsData) handlerCb({
    weaponBlkName, bulletName, shotMode, shotModeValue, ballisticsData
  })
  shotModeParams[shotMode].buildTrajectoryData(weaponBlkName, bulletName, shotModeValue, cb)
}

function needActualizeBallisticsData(cacheData, settings, bullet) {
  if (!canRequestBulletBallisticsData(bullet))
    return cacheData == null

  if (cacheData == null)
    return true

  return cacheData.shotMode != settings.shotMode
    || cacheData.shotModeValue != getShotModeValue(settings)
}

function getBallisticsData(compareBulletsList, cacheBulletsData) {
  let res = []
  foreach (idx, bullet in compareBulletsList) {
    let ballisticsData = cacheBulletsData?[getBulletCacheSaveId(bullet)].ballisticsData ?? []
    if (ballisticsData.len() == 0)
      continue
    res.append({
      graphColor = graphColorList[idx].int
      graphData  = ballisticsData
    })
  }
  return res
}

function getPenetrationData(compareBulletsList, cacheBulletsData) {
  let res = []
  foreach (idx, bullet in compareBulletsList) {
    let penetrationData = cacheBulletsData?[getBulletCacheSaveId(bullet)].penetrationData ?? []
    if (penetrationData.len() == 0)
      continue
    res.append({
      graphColor = graphColorList[idx].int
      graphData  = penetrationData
    })
  }
  return res
}

let bulletsParametersPages = [
  {
    id = "bulletBallistics"
    cacheDataId = "pageBallisticsData"
    locId = "mainmenu/ballistics"
    requestGraphData = requestBallisticsData
    needActualize = needActualizeBallisticsData
    getGraphDataFromCache = getBallisticsData
    hasShotSetting = true
  }
  {
    id = "bulletPenetration"
    cacheDataId = "pageArmorPenetrationData"
    locId = "bullet_properties/armorPiercing"
    requestGraphData = requestArmorPenetrationData
    needActualize = @(cacheData, _settings, _bullet) cacheData == null
    getGraphDataFromCache = getPenetrationData
    hasShotSetting = false
  }
]

let shotSettings = [
  shotAngleSetting
  targetRangeSetting
  {
    id = "shotMode"
    value = ShotMode.ANGLE
    values = [ShotMode.ANGLE, ShotMode.RANGE]
    getItemText = @(value) loc(shotModeParams[value].setting.locId)
    getControlMarkup = mkModeButtonsMarkup
  }
]

let openBulletsBallisticParametersWnd = @(p)
  handlersManager.loadHandler(GraphCompareBulletsWnd, p.__merge({
    pagesConfig = bulletsParametersPages
    canBeComparedBulletsByUnitType
    shotSettings
    bulletsFilter = canRequestBallisticsData
  }))

register_command(@() openBulletsBallisticParametersWnd({ unit = getAircraftByName("us_mbt_70") }), "debug.open_bullets_ballistic_parameters_wnd")

return {
  openBulletsBallisticParametersWnd
}
