local stdMath = require("std/math.nut")

const RICOCHET_DATA_ANGLE = 30
const DEFAULT_ARMOR_FOR_PENETRATION_RADIUS = 50

::g_dmg_model <- {
  RICOCHET_PROBABILITIES = [0.0, 0.5, 1.0]

  ricochetDataByBulletType = null
}

/*************************************************************************************************/
/*************************************PUBLIC FUNCTIONS *******************************************/
/*************************************************************************************************/

g_dmg_model.getDmgModelBlk <- function getDmgModelBlk()
{
  return ::DataBlock("config/damageModel.blk")
}

g_dmg_model.getExplosiveBlk <- function getExplosiveBlk()
{
  return ::DataBlock("gameData/damage_model/explosive.blk")
}

g_dmg_model.getRicochetData <- function getRicochetData(bulletType)
{
  initRicochetDataOnce()
  return ::getTblValue(bulletType, ricochetDataByBulletType)
}

g_dmg_model.getTntEquivalentText <- function getTntEquivalentText(explosiveType, explosiveMass)
{
  if(explosiveType == "tnt")
    return ""
  local blk = getExplosiveBlk()
  ::dagor.assertf(!!blk?.explosiveTypes, "ERROR: Can't load explosiveTypes from explosive.blk")
  local explMassInTNT = blk?.explosiveTypes?[explosiveType]?.strengthEquivalent ?? 0
  if (!explosiveMass || explMassInTNT <= 0)
    return ""
  return ::g_dmg_model.getMeasuredExplosionText(explosiveMass.tofloat() * explMassInTNT)
}

g_dmg_model.getMeasuredExplosionText <- function getMeasuredExplosionText(weightValue)
{
  local typeName = "kg"
  if (weightValue < 1.0)
  {
    typeName = "gr"
    weightValue *= 1000
  }
  return ::g_measure_type.getTypeByName(typeName, true).getMeasureUnitsText(weightValue)
}

g_dmg_model.getDestructionInfoTexts <- function getDestructionInfoTexts(explosiveType, explosiveMass, ammoMass)
{
  local res = {
    maxArmorPenetrationText = ""
    destroyRadiusArmoredText = ""
    destroyRadiusNotArmoredText = ""
  }

  local blk = getExplosiveBlk()
  local explTypeBlk = blk?.explosiveTypes?[explosiveType]
  if (!::u.isDataBlock(explTypeBlk))
    return res

  //armored vehicles data
  local explMassInTNT = explosiveMass * (explTypeBlk?.strengthEquivalent ?? 0)
  local splashParamsBlk = blk?.explosiveTypeToSplashParams
  if (explMassInTNT && ::u.isDataBlock(splashParamsBlk))
  {
    local maxPenetration = getLinearValueFromP2blk(splashParamsBlk?.explosiveMassToPenetration, explMassInTNT)
    local innerRadius = getLinearValueFromP2blk(splashParamsBlk?.explosiveMassToInnerRadius, explMassInTNT)
    local outerRadius = getLinearValueFromP2blk(splashParamsBlk?.explosiveMassToOuterRadius, explMassInTNT)
    local armorToShowRadus = blk?.penetrationToCalcDestructionRadius ?? DEFAULT_ARMOR_FOR_PENETRATION_RADIUS

    if (maxPenetration)
      res.maxArmorPenetrationText = ::g_measure_type.getTypeByName("mm", true).getMeasureUnitsText(maxPenetration)
    if (maxPenetration >= armorToShowRadus)
    {
      local radius = innerRadius + (outerRadius - innerRadius) * (maxPenetration - armorToShowRadus) / maxPenetration
      res.destroyRadiusArmoredText = ::g_measure_type.getTypeByName("dist_short", true).getMeasureUnitsText(radius)
    }
  }

  //not armored vehicles data
  local fillingRatio = ammoMass ? explosiveMass / ammoMass : 1.0
  local brisanceMass = explosiveMass * (explTypeBlk?.brisanceEquivalent ?? 0)
  local destroyRadiusNotArmored = calcDestroyRadiusNotArmored(blk?.explosiveTypeToShattersParams,
                                                              fillingRatio,
                                                              brisanceMass)
  if (destroyRadiusNotArmored > 0)
    res.destroyRadiusNotArmoredText = ::g_measure_type.getTypeByName("dist_short", true).getMeasureUnitsText(destroyRadiusNotArmored)

  return res
}

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

g_dmg_model.resetData <- function resetData()
{
  ricochetDataByBulletType = null
}

g_dmg_model.getLinearValueFromP2blk <- function getLinearValueFromP2blk(blk, x)
{
  local pMin = null
  local pMax = null
  if (::u.isDataBlock(blk))
    for (local i = 0; i < blk.paramCount(); i++)
    {
      local p2 = blk.getParamValue(i)
      if (typeof p2 != "instance" || !(p2 instanceof ::Point2))
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
g_dmg_model.getAngleByProbabilityFromP2blk <- function getAngleByProbabilityFromP2blk(blk, x)
{
  for (local i = 0; i < blk.paramCount() - 1; ++i)
  {
    local p1 = blk.getParamValue(i)
    local p2 = blk.getParamValue(i + 1)
    if (typeof p1 != "instance" || !(p1 instanceof ::Point2) ||
        typeof p2 != "instance" || !(p2 instanceof ::Point2))
      continue
    local angle1 = p1.x
    local probability1 = p1.y
    local angle2 = p2.x
    local probability2 = p2.y
    if ((probability1 <= x && x <= probability2) || (probability2 <= x && x <= probability1))
    {
      if (probability1 == probability2)
      {
        // This means that we are on the left side of
        // probability-by-angle curve.
        if (x == 1)
          return ::max(angle1, angle2)
        else
          return ::min(angle1, angle2)
      }
      return stdMath.lerp(probability1, probability2, angle1, angle2, x)
    }
  }
  return -1
}

/** Returns -1 if nothing found. */
g_dmg_model.getMaxProbabilityFromP2blk <- function getMaxProbabilityFromP2blk(blk)
{
  local result = -1
  for (local i = 0; i < blk.paramCount(); ++i)
  {
    local p = blk.getParamValue(i)
    if (typeof p == "instance" && p instanceof ::Point2)
      result = ::max(result, p.y)
  }
  return result
}

g_dmg_model.initRicochetDataOnce <- function initRicochetDataOnce()
{
  if (ricochetDataByBulletType)
    return

  ricochetDataByBulletType = {}
  local blk = getDmgModelBlk()
  if (!blk)
    return

  local typesList = blk?.bulletTypes
  local ricBlk = blk?.ricochetPresets
  if (!typesList || !ricBlk)
  {
    ::dagor.assertf(false, "ERROR: Can't load ricochet params from damageModel.blk")
    return
  }

  local defaultData = getRicochetDataByPreset({
                        ricochetPreset = "default"
                      },
                      ricBlk)
  ricochetDataByBulletType[""] <- defaultData

  for (local i = 0; i < typesList.blockCount(); i++)
  {
    local presetBlk = typesList.getBlock(i)
    local bulletType = presetBlk.getBlockName()
    ricochetDataByBulletType[bulletType] <- getRicochetDataByPreset(presetBlk, ricBlk, defaultData)
  }
}

g_dmg_model.getRicochetDataByPreset <- function getRicochetDataByPreset(preset, ricBlk, defaultData = null)
{
  local res = {
    angleProbabilityMap = []
  }
  local rPreset = preset.ricochetPreset
  local ricochetPresetBlk = getRichochetPresetBlkByName(rPreset, ricBlk)
  if (ricochetPresetBlk != null)
  {
    local addMaxProbability = false
    for (local i = 0; i < RICOCHET_PROBABILITIES.len(); ++i)
    {
      local probability = RICOCHET_PROBABILITIES[i]
      local angle = getAngleByProbabilityFromP2blk(ricochetPresetBlk, probability)
      if (angle != -1)
      {
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
    if (addMaxProbability)
    {
      local maxProbability = getMaxProbabilityFromP2blk(ricochetPresetBlk)
      local angleAtMaxProbability = getAngleByProbabilityFromP2blk(ricochetPresetBlk, maxProbability)
      if (maxProbability != -1 && angleAtMaxProbability != -1)
      {
        res.angleProbabilityMap.append({
          probability = maxProbability
          angle = 90.0 - angleAtMaxProbability
        })
      }
    }
  }
  return res
}

g_dmg_model.getRichochetPresetBlkByName <- function getRichochetPresetBlkByName(presetName, ricBlk)
{
  if (presetName == null || ricBlk?[presetName] == null)
    return null
  local presetData = ricBlk[presetName]
  // First cycle through all preset blocks searching
  // for block with "caliberToArmor:r = 1".
  for (local i = 0; i < presetData.blockCount(); ++i)
  {
    local presetBlock = presetData.getBlock(i)
    if (presetBlock?.caliberToArmor == 1)
      return presetBlock
  }
  // If no such block found then try to find block
  // without "caliberToArmor" property.
  for (local i = 0; i < presetData.blockCount(); ++i)
  {
    local presetBlock = presetData.getBlock(i)
    if (!("caliberToArmor" in presetBlock))
      return presetBlock
  }
  // If still nothing found then return presetData
  // as it is a preset block itself.
  return presetData
}

g_dmg_model.calcDestroyRadiusNotArmored <- function calcDestroyRadiusNotArmored(shattersParamsBlk, fillingRatio, brisanceMass)
{
  if (!::u.isDataBlock(shattersParamsBlk) || !brisanceMass)
    return 0

  for (local i = 0; i < shattersParamsBlk.blockCount(); i++)
  {
    local blk = shattersParamsBlk.getBlock(i)
    if (fillingRatio > (blk?.fillingRatio ?? 0))
      continue

    return getLinearValueFromP2blk(blk?.explosiveMassToRadius, brisanceMass)
  }
  return 0
}

g_dmg_model.onEventSignOut <- function onEventSignOut(p)
{
  resetData()
}

::subscribe_handler(::g_dmg_model, ::g_listener_priority.CONFIG_VALIDATION)