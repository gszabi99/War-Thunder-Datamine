import "%sqStdLibs/helpers/u.nut" as u
from "%sqstd/string.nut" import cutPrefix, endsWith
from "mission" import get_mplayers_count, get_mp_local_team
from "%scripts/dagui_library.nut" import *
from "%scripts/misCustomRules/ruleConsts.nut" import RESPAWNS_UNLIMITED

let { getUnitClassTypeByExpClass } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { registerMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let RuleBase = require("%scripts/misCustomRules/ruleBase.nut")
let { UnitLimitByUnitName, UnitLimitByUnitRole, UnitLimitByUnitExpClass, ActiveLimitByUnitExpClass, UnitLimitByUnitType } = require("%scripts/misCustomRules/unitLimit.nut")

let SharedPool = class (RuleBase) {
  function getMaxRespawns() {
    return (this.getMyTeamDataBlk()?.playerMaxSpawns ?? RESPAWNS_UNLIMITED)
  }

  function getLeftRespawns() {
    let maxRespawns = this.getMaxRespawns()
    if (maxRespawns == RESPAWNS_UNLIMITED)
      return RESPAWNS_UNLIMITED

    let spawnsBlk = this.getMisStateBlk()?.spawns
    let usedSpawns = (spawnsBlk?[userIdStr.get()] ?? 0)
    return max(0, maxRespawns - usedSpawns)
  }

  function getRespawnInfoTextForUnit(unit) {
    let res = base.getRespawnInfoTextForUnit(unit)
    if (!unit)
      return res

    let limitText = this.getExpClassLimitTextByUnit(unit)
    return "".concat(res, ((res.len() && limitText.len()) ? loc("ui/comma") : ""), limitText)
  }

  function getSpecialCantRespawnMessage(unit) {
    let expClassName = unit.expClass.getExpClass()
    let activeAtOnce = this.getActiveAtOnceExpClass(expClassName)
    if (activeAtOnce != RESPAWNS_UNLIMITED
        && activeAtOnce <= this.getCurActiveExpClassAmount(expClassName))
      return loc("multiplayer/cant_spawn/all_active_at_once",
                   {
                     name = colorize("activeTextColor", unit.expClass.getName())
                     amountText = this.getExpClassLimitTextByUnit(unit)
                   })

    let leftRespawns = this.getUnitLeftRespawns(unit)
    if (!leftRespawns)
      return loc("multiplayer/noTeamUnitLeft", { unitName = colorize("userlogColoredText", getUnitName(unit)) })

    return null
  }

  function getExpClassLimitTextByUnit(unit) {
    let expClassName = unit.expClass.getExpClass()
    let activeAtOnce = this.getActiveAtOnceExpClass(expClassName)
    if (activeAtOnce == RESPAWNS_UNLIMITED)
      return ""

    let limit = ActiveLimitByUnitExpClass(
                    expClassName,
                    activeAtOnce,
                    { distributed = this.getCurActiveExpClassAmount(expClassName) }
                 )
    return limit.getText()
  }

  function hasCustomUnitRespawns() {
    let myTeamDataBlk = this.getMyTeamDataBlk()
    return "limitedUnits" in myTeamDataBlk || "unlimitedUnits" in myTeamDataBlk
           || "limitedClasses" in myTeamDataBlk || "limitedTags" in myTeamDataBlk
           || "limitedActiveClasses" in myTeamDataBlk
  }

  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk) {
    if (!unit)
      return 0

    local res = RESPAWNS_UNLIMITED
    let limitedClasses = teamDataBlk?.limitedClasses
    if (u.isDataBlock(limitedClasses)) {
      let total = limitedClasses.paramCount()
      for (local i = 0; i < total; i++) {
        let expClassName = limitedClasses.getParamName(i)
        let expClass = getUnitClassTypeByExpClass(expClassName)
        if (expClass != unit.expClass)
          continue

        res = limitedClasses.getParamValue(i)
        break
      }
    }

    let limitedTags = teamDataBlk?.limitedTags
    if (u.isDataBlock(limitedTags)) {
      let total = limitedTags.paramCount()
      for (local i = 0; i < total; i++)
        if (isInArray(limitedTags.getParamName(i), unit.tags))
          res = this.minRespawns(res, limitedTags.getParamValue(i))
    }

    let limitedUnits = teamDataBlk?.limitedUnits
    res = this.minRespawns(res, (limitedUnits?[unit.name] ?? RESPAWNS_UNLIMITED))

    if (res != RESPAWNS_UNLIMITED)
      return res

    let unlimitedUnits = teamDataBlk?.unlimitedUnits
    if (unlimitedUnits && !(unit.name in unlimitedUnits))
      res = 0
    return res
  }

  function calcFullUnitLimitsData(_isTeamMine = true) {
    let res = base.calcFullUnitLimitsData()

    let myTeamDataBlk = this.getMyTeamDataBlk()
    res.defaultUnitRespawnsLeft = "unlimitedUnits" in myTeamDataBlk ? 0 : RESPAWNS_UNLIMITED

    let limitedClasses = myTeamDataBlk?.limitedClasses
    if (u.isDataBlock(limitedClasses)) {
      let total = limitedClasses.paramCount()
      for (local i = 0; i < total; i++) {
        let expClassName = limitedClasses.getParamName(i)
        if (getUnitClassTypeByExpClass(expClassName).isValid())
          res.unitLimits.append(UnitLimitByUnitExpClass(expClassName, limitedClasses.getParamValue(i)))
      }
    }

    let limitedTags = myTeamDataBlk?.limitedTags
    if (u.isDataBlock(limitedTags)) {
      let total = limitedTags.paramCount()
      for (local i = 0; i < total; i++) {
        let tag = limitedTags.getParamName(i)
        let respLeft = limitedTags.getParamValue(i)

        let unitType = unitTypes.getByTag(tag)
        if (unitType != unitTypes.INVALID) {
          res.unitLimits.append(UnitLimitByUnitType(unitType.typeName, respLeft))
          continue
        }

        let role = cutPrefix(tag, "type_", null)
        if (role)
          res.unitLimits.append(UnitLimitByUnitRole(role, respLeft))
      }
    }

    let unitsGroups = this.getUnitsGroups()
    local blk = myTeamDataBlk?.limitedUnits
    if (u.isDataBlock(blk))
      for (local i = 0; i < blk.paramCount(); i++)
        res.unitLimits.append(UnitLimitByUnitName(blk.getParamName(i), blk.getParamValue(i),
          { nameLocId = unitsGroups?[blk.getParamName(i)]?.name }))

    blk = myTeamDataBlk?.unlimitedUnits
    if (u.isDataBlock(blk))
      for (local i = 0; i < blk.paramCount(); i++)
        res.unitLimits.append(UnitLimitByUnitName(blk.getParamName(i), RESPAWNS_UNLIMITED,
          { nameLocId = unitsGroups?[blk.getParamName(i)]?.name }))

    let activeLimitsBlk = myTeamDataBlk?.limitedActiveClasses
    if (u.isDataBlock(activeLimitsBlk)) {
      let limitByExpClassName = {}
      let total = activeLimitsBlk.paramCount()
      for (local i = 0; i < total; i++) {
        local value = activeLimitsBlk.getParamValue(i)
        local expClassName = activeLimitsBlk.getParamName(i)
        if (endsWith(expClassName, "_perc")) {
          value = this.getAmountByTeamPercent(value)
          expClassName = expClassName.slice(0, expClassName.len() - 5)
        }
        if (expClassName in limitByExpClassName)
          limitByExpClassName[expClassName] = min(value, limitByExpClassName[expClassName])
        else
          limitByExpClassName[expClassName] <- value
      }

      let activeBlk = myTeamDataBlk?.activeClasses
      foreach (expClassName, maxAmount in limitByExpClassName)
        res.unitLimits.append(
          ActiveLimitByUnitExpClass(
            expClassName,
            maxAmount,
            { distributed = activeBlk?[expClassName] ?? 0 }
          )
        )
    }

    return res
  }

  function getAmountByTeamPercent(percent) {
    return ((percent * get_mplayers_count(get_mp_local_team(), false)) / 100).tointeger()
  }

  function getActiveAtOnceExpClass(expClassName) {
    local res = RESPAWNS_UNLIMITED
    let activeLimitsBlk = this.getMyTeamDataBlk()?.limitedActiveClasses
    if (!activeLimitsBlk)
      return res

    res = this.minRespawns(res, (activeLimitsBlk?[expClassName] ?? RESPAWNS_UNLIMITED))
    let percent = (activeLimitsBlk?[$"{expClassName}_perc"] ?? -1)
    if (percent >= 0)
      res = this.minRespawns(res, this.getAmountByTeamPercent(percent))
    return res
  }

  function getCurActiveExpClassAmount(expClassName) {
    let activeBlk = this.getMyTeamDataBlk()?.activeClasses
    return (activeBlk?[expClassName] ?? 0)
  }
}

registerMissionRules("SharedPool", SharedPool)
