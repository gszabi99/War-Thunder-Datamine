from "%scripts/dagui_library.nut" import *
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { register_command } = require("console")
let { buildMissileTrajectoryData } = require("unitCalculcation")
let { Point3 } = require("dagor.math")
let { round_by_value } = require("%sqstd/math.nut")
let { isMissileWeapon, isMissileBullet, isGuidedBomb } = require("%scripts/weaponry/weaponryInfo.nut")
let { graphColorList, getBulletCacheSaveId } = require("%scripts/weaponry/graphCompareBullets/bulletsGraphState.nut")
let { GraphCompareBulletsWnd } = require("%scripts/weaponry/graphCompareBullets/graphCompareBulletsWnd.nut")
let { mkSliderMarkup } = require("%scripts/weaponry/graphCompareBullets/bulletsBallisticOptionsView.nut")
let { getStatCardInfo } = require("%scripts/unit/statCardInfo.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { eventbus_subscribe} = require("eventbus")

function canRequestTrajectorysData(bullet) {
  return isMissileWeapon(bullet?.weaponType)
    || isGuidedBomb(bullet?.weaponType)
    || isMissileBullet(bullet?.bulletParams.bulletType)
}

function requestMissileTrajectoryData(bullet, settings, handlerCb) {
  let { weaponBlkName, bulletName } = bullet
  if (canRequestTrajectorysData(bullet)) {
    let { carrierAlt, targetAlt, targetDist, carrierSpeed, targetSpeed } = settings
    let cb = @(trajectoryData) handlerCb({
      weaponBlkName, bulletName, carrierAlt, targetAlt, targetDist, carrierSpeed, targetSpeed, trajectoryData
    })
    buildMissileTrajectoryData(weaponBlkName, bulletName,
      Point3(0, carrierAlt, 0), Point3(targetDist, targetAlt, 0),
      Point3(carrierSpeed, 0, 0), Point3(targetSpeed, 0, 0), cb)
  }
  else
    handlerCb({ weaponBlkName, bulletName })
}

function getTrajectoryData(compareBulletsList, cacheBulletsData) {
  let res = []
  foreach (idx, bullet in compareBulletsList) {
    let trajectoryData = cacheBulletsData?[getBulletCacheSaveId(bullet)].trajectoryData ?? []
    if (trajectoryData.len() == 0)
      continue
    res.append({
      graphColor = graphColorList[idx].int
      graphData  = trajectoryData
    })
  }
  return res
}

function needActualizemissileTrajectoryData(cacheData, settings, bullet) {
  if (canRequestTrajectorysData(bullet))
    return cacheData?.carrierAlt != settings.carrierAlt
      || cacheData?.targetAlt != settings.targetAlt
      || cacheData?.targetDist != settings.targetDist
      || cacheData?.carrierSpeed != settings.carrierSpeed
      || cacheData?.targetSpeed != settings.targetSpeed
  return cacheData == null
}

let defaultPageParameters = {
  cacheDataId = "pageTrajectoryData"
  locId = "mainmenu/missileTrajectory"
  requestGraphData = requestMissileTrajectoryData
  needActualize = needActualizemissileTrajectoryData
  getGraphDataFromCache = getTrajectoryData
  hasShotSetting = true
}

let missileParametersPages = [
  {
    id = "missileTrajectory"
    hasPlayerPanel = true
  }
  {
    id = "missileTelemetry"
    locId = "mainmenu/missileTelemetry"
    subPages = [{
      id = "missileTelemetryDistance"
      locId = "distance"
    }
    {
      id = "missileTelemetrySpeed"
      locId = "options/measure_units_speed"
    }]
  }
].map(@(v) defaultPageParameters.__merge(v))


let metersToKmFloat = @(value) $"{round_by_value(value * 0.001, 0.1)}{loc("measureUnits/km_dist")}"

let shotSettings = [
  {
    locId = "mainmenu/targetParameters"
    isHeader = true
  }
  {
    id = "targetSpeed"
    locId = "options/measure_units_speed"
    minValue = -700
    maxValue = 700
    step = 10
    value = 0
    getValueText = @(value) $"{value}{loc("measureUnits/metersPerSecond_climbSpeed")}"
    getControlMarkup = mkSliderMarkup
  }
  {
    id = "targetAlt"
    locId = "options/measure_units_alt"
    minValue = 100
    maxValue = 30000
    step = 100
    value = 3000
    getValueText = metersToKmFloat
    getControlMarkup = mkSliderMarkup
  }
  {
    id = "targetDist"
    locId = "mainmenu/distanceFromTargetToCarrier"
    minValue = 1000
    maxValue = 150000
    step = 1000
    value = 10000
    getValueText = @(value) $"{value/1000}{loc("measureUnits/km_dist")}"
    getControlMarkup = mkSliderMarkup
  }
  {
    locId = "mainmenu/carrierParameters"
    isHeader = true
  }
  {
    id = "carrierSpeed"
    locId = "options/measure_units_speed"
    minValue = 0
    maxValue = 500
    step = 10
    value = 250
    getValueText = @(value) $"{value}{loc("measureUnits/metersPerSecond_climbSpeed")}"
    getControlMarkup = mkSliderMarkup
  }
  {
    id = "carrierAlt"
    locId = "options/measure_units_alt"
    minValue = 100
    maxValue = 30000
    step = 100
    value = 3000
    getValueText = metersToKmFloat
    getControlMarkup = mkSliderMarkup
  }
]


function getUnitRocketStructure() {
  let structure = {}
  let statCardInfo = getStatCardInfo()

  foreach (unit in getAllUnits()) {
    if (!unit.isVisibleInShop())
      continue

    let { name, esUnitType, shopCountry, rank } = unit
    if (!(statCardInfo?[name].hasRockets ?? false))
      continue

    if (esUnitType not in structure)
      structure[esUnitType] <- {}

    if (shopCountry not in structure[esUnitType])
      structure[esUnitType][shopCountry] <- {}

    if (rank not in structure[esUnitType][shopCountry])
      structure[esUnitType][shopCountry][rank] <- {}

    if (name not in structure[esUnitType][shopCountry][rank])
      structure[esUnitType][shopCountry][rank][name] <- true
  }

  return structure
}


let openMissileTrajectoryWnd = @(p)
  handlersManager.loadHandler(GraphCompareBulletsWnd, p.__merge({
    pagesConfig = missileParametersPages
    shotSettings
    structure = getUnitRocketStructure()
  }))

eventbus_subscribe("trajectory_btn_clicked", @(p) openMissileTrajectoryWnd(p))

register_command(@() openMissileTrajectoryWnd({ unit = getAircraftByName("f_14b") }), "debug.open_missile_trajectory_wnd")

return {
  openMissileTrajectoryWnd
}
