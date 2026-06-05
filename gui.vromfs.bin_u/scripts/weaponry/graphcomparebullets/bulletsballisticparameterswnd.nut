from "%scripts/dagui_library.nut" import *
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { register_command } = require("console")
let { buildBallisticTrajectoryData, buildArmorPenetrationData } = require("unitCalculcation")
let { isMissileWeaponType, isMissileBullet, isGuidedBomb } = require("%scripts/weaponry/weaponryInfo.nut")
let { graphColorList, getBulletCacheSaveId } = require("%scripts/weaponry/graphCompareBullets/bulletsGraphState.nut")
let { GraphCompareBulletsWnd } = require("%scripts/weaponry/graphCompareBullets/graphCompareBulletsWnd.nut")
let { mkSliderMarkup } = require("%scripts/weaponry/graphCompareBullets/bulletsBallisticOptionsView.nut")

const DEFAULT_MAX_DISTANCE = 2000.0
let maxDistanceByEsUnitType = {
  [ES_UNIT_TYPE_SHIP] = 15000.0,
  [ES_UNIT_TYPE_BOAT] = 15000.0,
}

let getMaxDistance = @(esUnitType) maxDistanceByEsUnitType?[esUnitType] ?? DEFAULT_MAX_DISTANCE

let unitsTypesBulletsCanBeCompared = { 
  [ES_UNIT_TYPE_AIRCRAFT]   = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER],
  [ES_UNIT_TYPE_HELICOPTER] = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER],
  [ES_UNIT_TYPE_TANK]       = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER],
  [ES_UNIT_TYPE_SHIP]       = [ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT],
  [ES_UNIT_TYPE_BOAT]       = [ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT],
}.map(@(l) l.reduce(@(res, v) res.$rawset(v, true), {}))

function canRequestBallisticsData(bullet) {
  return isMissileWeaponType(bullet?.weaponType)
    || isGuidedBomb(bullet?.weaponType)
    || isMissileBullet(bullet?.bulletParams.bulletType)
}

function canBeComparedBulletsByUnitType(bullet, compareBulletsList) {
  if (compareBulletsList.len() == 0)
    return true
  let curBulletUniTypesList = unitsTypesBulletsCanBeCompared?[bullet.esUnitType]
  if (curBulletUniTypesList == null)
    return false

  return compareBulletsList.findvalue(@(v) v.esUnitType not in curBulletUniTypesList) == null
}

function requestArmorPenetrationData(bullet, _settings, handlerCb) {
  let { weaponBlkName, bulletName, esUnitType } = bullet
  let cb = @(penetrationData) handlerCb({ weaponBlkName, bulletName, penetrationData })
  buildArmorPenetrationData(weaponBlkName, bulletName, getMaxDistance(esUnitType), cb)
}

function requestBallisticsData(bullet, settings, handlerCb) {
  let { weaponBlkName, bulletName } = bullet
  if (canRequestBallisticsData(bullet))
    handlerCb({ weaponBlkName, bulletName })
  else {
    let { shotAngle } = settings
    let cb = @(ballisticsData) handlerCb({ weaponBlkName, bulletName, shotAngle, ballisticsData })
    buildBallisticTrajectoryData(weaponBlkName, bulletName, shotAngle, cb)
  }
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
    needActualize = function(cacheData, settings, bullet) {
      if (canRequestBallisticsData(bullet))
        return cacheData == null
      return cacheData?.shotAngle != settings.shotAngle
    }
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
  {
    id = "shotAngle"
    locId = "mainmenu/angle"
    minValue = 1
    maxValue = 60
    step = 1
    value = 10
    getValueText = @(value) $"{value}{loc("measureUnits/deg")}"
    getControlMarkup = mkSliderMarkup
  }
]

let openBulletsBallisticParametersWnd = @(p)
  handlersManager.loadHandler(GraphCompareBulletsWnd, p.__merge({
    pagesConfig = bulletsParametersPages
    canBeComparedBulletsByUnitType
    shotSettings
  }))

register_command(@() openBulletsBallisticParametersWnd({ unit = getAircraftByName("us_mbt_70") }), "debug.open_bullets_ballistic_parameters_wnd")

return {
  openBulletsBallisticParametersWnd
}
