from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let { lerp } = require("%sqstd/math.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isDataBlock, eachBlock } = require("%sqstd/datablock.nut")
let { Point2 } = require("dagor.math")
let { getMeasureTypeByName } = require("%scripts/measureType.nut")

const DEFAULT_ARMOR_FOR_PENETRATION_RADIUS = 50
let RICOCHET_PROBABILITIES = [0.0, 0.5, 1.0]

local ricochetDataByPreset = null

let resetData = @() ricochetDataByPreset = null

let isPoint2 = @(p) type(p) == "instance" && p instanceof Point2

function getDmgModelBlk() {
  let blk = DataBlock()
  blk.load("config/damageModel.blk")
  return blk
}

function getExplosiveBlk() {
  let blk = DataBlock()
  blk.load("gameData/damage_model/explosive.blk")
  return blk
}

function getLinearValueFromP2blk(blk, x) {
  local pMin = null
  local pMax = null
  if (isDataBlock(blk))
    for (local i = 0; i < blk.paramCount(); i++) {
      let p2 = blk.getParamValue(i)
      if (!isPoint2(p2))
        continue

      if (p2.x == x)
        return p2.y

      if (p2.x < x && (!pMin || p2.x > pMin.x))
        pMin = p2
      if (p2.x > x && (!pMax || p2.x < pMax.x))
        pMax = p2
    }
  if (!pMin)
    return pMax?.y ?? 0.0
  if (!pMax)
    return pMin.y
  return pMin.y + (pMax.y - pMin.y) * (x - pMin.x) / (pMax.x - pMin.x)
}

/** Returns -1 if no such angle found. */
function getAngleByProbabilityFromP2blk(blk, x) {
  for (local i = 0; i < blk.paramCount() - 1; ++i) {
    let p1 = blk.getParamValue(i)
    let p2 = blk.getParamValue(i + 1)
    if (!isPoint2(p1) || !isPoint2(p2))
      continue
    let angle1 = p1.x
    let probability1 = p1.y
    let angle2 = p2.x
    let probability2 = p2.y
    if ((probability1 <= x && x <= probability2) || (probability2 <= x && x <= probability1)) {
      if (probability1 == probability2) {
        // This means that we are on the left side of
        // probability-by-angle curve.
        if (x == 1)
          return max(angle1, angle2)
        else
          return min(angle1, angle2)
      }
      return lerp(probability1, probability2, angle1, angle2, x)
    }
  }
  return -1
}

/** Returns -1 if nothing found. */
function getMaxProbabilityFromP2blk(blk) {
  local result = -1
  for (local i = 0; i < blk.paramCount(); ++i) {
    let p = blk.getParamValue(i)
    if (isPoint2(p))
      result = max(result, p.y)
  }
  return result
}

function getRichochetPresetBlk(presetData) {
  if (presetData == null)
    return null
  // First cycle through all preset blocks searching
  // for block with "caliberToArmor:r = 1".
  for (local i = 0; i < presetData.blockCount(); ++i) {
    let presetBlock = presetData.getBlock(i)
    if (presetBlock?.caliberToArmor == 1)
      return presetBlock
  }
  // If no such block found then try to find block
  // without "caliberToArmor" property.
  for (local i = 0; i < presetData.blockCount(); ++i) {
    let presetBlock = presetData.getBlock(i)
    if (!("caliberToArmor" in presetBlock))
      return presetBlock
  }
  // If still nothing found then return presetData
  // as it is a preset block itself.
  return presetData
}

function getRicochetDataByPreset(presetDataBlk) {
  let res = {
    angleProbabilityMap = []
  }
  let ricochetPresetBlk = getRichochetPresetBlk(presetDataBlk)
  if (ricochetPresetBlk != null) {
    local addMaxProbability = false
    for (local i = 0; i < RICOCHET_PROBABILITIES.len(); ++i) {
      let probability = RICOCHET_PROBABILITIES[i]
      let angle = getAngleByProbabilityFromP2blk(ricochetPresetBlk, probability)
      if (angle != -1) {
        res.angleProbabilityMap.append({
          probability = probability
          angle = 90.0 - angle
        })
      }
      else
        addMaxProbability = true
    }

    // If, say, we didn't find angle with 100% ricochet chance,
    // then showing angle for max possible probability.
    if (addMaxProbability) {
      let maxProbability = getMaxProbabilityFromP2blk(ricochetPresetBlk)
      let angleAtMaxProbability = getAngleByProbabilityFromP2blk(ricochetPresetBlk, maxProbability)
      if (maxProbability != -1 && angleAtMaxProbability != -1) {
        res.angleProbabilityMap.append({
          probability = maxProbability
          angle = 90.0 - angleAtMaxProbability
        })
      }
    }
  }
  return res
}

function initRicochetDataOnce() {
  if (ricochetDataByPreset)
    return

  ricochetDataByPreset = {}
  let blk = getDmgModelBlk()
  if (!blk)
    return

  let ricBlk = blk?.ricochetPresets
  if (!ricBlk) {
    assert(false, "ERROR: Can't load ricochetPresets from damageModel.blk")
    return
  }

  for (local i = 0; i < ricBlk.blockCount(); i++) {
    let presetDataBlk = ricBlk.getBlock(i)
    let presetName = presetDataBlk.getBlockName()
    ricochetDataByPreset[presetName] <- getRicochetDataByPreset(presetDataBlk)
  }
}

function calcDestroyRadiusNotArmored(shattersParamsBlk, fillingRatio, brisanceMass) {
  if (!isDataBlock(shattersParamsBlk) || !brisanceMass)
    return 0

  for (local i = 0; i < shattersParamsBlk.blockCount(); i++) {
    let blk = shattersParamsBlk.getBlock(i)
    if (fillingRatio > (blk?.fillingRatio ?? 0))
      continue

    return getLinearValueFromP2blk(blk?.explosiveMassToRadius, brisanceMass)
  }
  return 0
}

function getRicochetData(presetName) {
  initRicochetDataOnce()
  return ricochetDataByPreset?[presetName]
}

function getMeasuredExplosionText(weightValue) {
  local typeName = "kg"
  if (weightValue < 1.0) {
    typeName = "gr"
    weightValue *= 1000
  }
  return getMeasureTypeByName(typeName, true).getMeasureUnitsText(weightValue)
}

function getTntEquivalentDmg(explosiveType, explosiveMass) {
  if (explosiveType == "tnt" || !explosiveMass)
    return 0
  let blk = getExplosiveBlk()
  assert(!!blk?.explosiveTypes, "ERROR: Can't load explosiveTypes from explosive.blk")
  let explMassInTNT = blk?.explosiveTypes?[explosiveType]?.strengthEquivalent ?? 0
  return explosiveMass.tofloat() * explMassInTNT
}

function getTntEquivalentText(explosiveType, explosiveMass) {
  let explosiveDmg = getTntEquivalentDmg(explosiveType, explosiveMass)
  return explosiveDmg <= 0 ? "" : getMeasuredExplosionText(explosiveDmg)
}

function getDestructionInfoTexts(explosiveType, explosiveMass, ammoMass) {
  let res = {
    maxArmorPenetrationText = ""
    destroyRadiusArmoredText = ""
    destroyRadiusNotArmoredText = ""
  }

  let blk = getExplosiveBlk()
  let explTypeBlk = blk?.explosiveTypes?[explosiveType]
  if (!isDataBlock(explTypeBlk))
    return res

  //armored vehicles data
  let explMassInTNT = explosiveMass * (explTypeBlk?.strengthEquivalent ?? 0)

  let splashParamsBlk = blk?.explosiveTypeToSplashParams
  if (explMassInTNT && isDataBlock(splashParamsBlk)) {
    let maxPenetration = getLinearValueFromP2blk(splashParamsBlk?.explosiveMassToPenetration, explMassInTNT)
    let innerRadius = getLinearValueFromP2blk(splashParamsBlk?.explosiveMassToInnerRadius, explMassInTNT)
    let outerRadius = getLinearValueFromP2blk(splashParamsBlk?.explosiveMassToOuterRadius, explMassInTNT)
    let armorToShowRadus = blk?.penetrationToCalcDestructionRadius ?? DEFAULT_ARMOR_FOR_PENETRATION_RADIUS

    if (maxPenetration)
      res.maxArmorPenetrationText = getMeasureTypeByName("mm", true).getMeasureUnitsText(maxPenetration)
    if (maxPenetration >= armorToShowRadus) {
      let radius = innerRadius + (outerRadius - innerRadius) * (maxPenetration - armorToShowRadus) / maxPenetration
      res.destroyRadiusArmoredText = getMeasureTypeByName("dist_short", true).getMeasureUnitsText(radius)
    }
  }

  //not armored vehicles data
  let fillingRatio = ammoMass ? explosiveMass / ammoMass : 1.0
  let brisanceMass = explosiveMass * (explTypeBlk?.brisanceEquivalent ?? 0)

  let destroyRadiusNotArmored = calcDestroyRadiusNotArmored(blk?.explosiveTypeToShattersParams,
    fillingRatio, brisanceMass)
  if (destroyRadiusNotArmored > 0)
    res.destroyRadiusNotArmoredText = getMeasureTypeByName("dist_short", true).getMeasureUnitsText(destroyRadiusNotArmored)

  return res
}

function getMaxArmorPiercing(explosiveType, explosiveMass) {
  let blk = getExplosiveBlk()
  let explTypeBlk = blk?.explosiveTypes[explosiveType]
  if (explTypeBlk == null)
    return null

  let splashParamsBlk = blk?.explosiveTypeToSplashParams
  if (splashParamsBlk == null)
    return null

  let explMassInTNT = explosiveMass * (explTypeBlk?.strengthEquivalent ?? 0)
  if (explMassInTNT == 0)
    return null

  let maxPenetration = getLinearValueFromP2blk(splashParamsBlk?.explosiveMassToPenetration, explMassInTNT)
  return maxPenetration
}

local xrayFilterCached = null
function getXrayFilter() {
  if (xrayFilterCached)
    return xrayFilterCached

  xrayFilterCached = []
  let blk = getDmgModelBlk()
  let xrayFilterBlk = blk?.xrayFilter
  if ((xrayFilterBlk?.blockCount() ?? 0) == 0)
    return xrayFilterCached

  eachBlock(xrayFilterBlk, function(block, name, idx) {
    let { isTank = null, isShip = null } = block
    let isForAllUnitTypes = isTank == null && isShip == null
    let units = block % "unit"
    xrayFilterCached.append({
      name
      bit = 1 << idx
      isTank = isTank || isForAllUnitTypes
      isShip = isShip || isForAllUnitTypes
      units
    })
  })
  return xrayFilterCached
}

let getTankXrayFilter = @(unitName) getXrayFilter()
  .filter(@(f) f.isTank && (f.units.len() == 0 || f.units.contains(unitName)))

let getShipXrayFilter = @(unitName) getXrayFilter()
  .filter(@(f) f.isShip && (f.units.len() == 0 || f.units.contains(unitName)))

addListenersWithoutEnv({
  SignOut = @(_p) resetData()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getRicochetData
  getMeasuredExplosionText
  getTntEquivalentDmg
  getTntEquivalentText
  getDestructionInfoTexts
  getTankXrayFilter
  getShipXrayFilter
  getMaxArmorPiercing
}
