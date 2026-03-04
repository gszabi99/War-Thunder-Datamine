from "%scripts/dagui_library.nut" import *
from "%scripts/misCustomRules/ruleConsts.nut" import RESPAWNS_UNLIMITED

let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { get_ds_ut_name_unit_type, get_team_name_by_mp_team } = require("%appGlobals/ranks_common_shared.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getUnitClassTypeByExpClass } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { registerMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let RuleBase = require("%scripts/misCustomRules/ruleBase.nut")
let { UnitLimitByUnitName, UnitLimitByUnitExpClass,
  UnitLimitByUnitType } = require("%scripts/misCustomRules/unitLimit.nut")
let { get_mp_local_team } = require("mission")

let ActiveUnitsPool = class (RuleBase) {
  needLeftRespawnOnSlots = true

  function calcLeftRespawnByKeys(teamDataBlk, limitedKey, unlimitedKey, name) {
    let limited = teamDataBlk?[limitedKey]
    let unlimited = teamDataBlk?[unlimitedKey]
    if (limited == null && unlimited == null)
      return RESPAWNS_UNLIMITED
    if (unlimited?[name] != null)
      return RESPAWNS_UNLIMITED
    return limited?[name] ?? 0
  }

  function hasCustomUnitRespawns() {
    let teamBlk = this.getMyTeamDataBlk()
    if (!teamBlk)
      return false
    return "limitedTypes" in teamBlk || "limitedClasses" in teamBlk
        || "limitedUnits" in teamBlk || "unlimitedTypes" in teamBlk
        || "unlimitedClasses" in teamBlk || "unlimitedUnits" in teamBlk
  }

  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk) {
    if (!unit)
      return 0

    local res = RESPAWNS_UNLIMITED
    res = this.minRespawns(res, this.calcLeftRespawnByKeys(teamDataBlk,
      "limitedTypes", "unlimitedTypes", get_ds_ut_name_unit_type(getEsUnitType(unit))))
    res = this.minRespawns(res, this.calcLeftRespawnByKeys(teamDataBlk,
      "limitedClasses", "unlimitedClasses", unit.expClass.getExpClass()))
    res = this.minRespawns(res, this.calcLeftRespawnByKeys(teamDataBlk,
      "limitedUnits", "unlimitedUnits", unit.name))
    return res
  }

  function getRespawnInfoTextForUnit(unit) {
    if (!unit)
      return ""

    let teamBlk = this.getMyTeamDataBlk()
    if (!teamBlk)
      return ""

    let parts = []

    let typesLeft = this.calcLeftRespawnByKeys(teamBlk,
      "limitedTypes", "unlimitedTypes", get_ds_ut_name_unit_type(getEsUnitType(unit)))
    if (typesLeft != RESPAWNS_UNLIMITED)
      parts.append($"{unit.unitType.fontIcon}{typesLeft}")

    let classesLeft = this.calcLeftRespawnByKeys(teamBlk,
      "limitedClasses", "unlimitedClasses", unit.expClass.getExpClass())
    if (classesLeft != RESPAWNS_UNLIMITED) {
      let expClassType = getUnitClassTypeByExpClass(unit.expClass.getExpClass())
      parts.append($"{expClassType.getFontIcon()}{classesLeft}")
    }

    let unitsLeft = this.calcLeftRespawnByKeys(teamBlk,
      "limitedUnits", "unlimitedUnits", unit.name)
    if (unitsLeft != RESPAWNS_UNLIMITED)
      parts.append($"{getUnitName(unit)}{unitsLeft}")

    return colorize("@activeTextColor", loc("ui/comma").join(parts))
  }

  function getSpecialCantRespawnMessage(unit) {
    if (!unit)
      return null

    let teamBlk = this.getMyTeamDataBlk()
    if (!teamBlk)
      return null

    let dsUnitType = get_ds_ut_name_unit_type(getEsUnitType(unit))
    if (this.calcLeftRespawnByKeys(teamBlk, "limitedTypes", "unlimitedTypes", dsUnitType) == 0)
      return loc("multiplayer/cant_spawn/all_active_at_once", {
        name = colorize("activeTextColor", unit.unitType.getArmyLocName())
        amountText = this.getOriginalLimitText("limitedTypes", dsUnitType)
      })

    let unitClass = unit.expClass.getExpClass()
    if (this.calcLeftRespawnByKeys(teamBlk, "limitedClasses", "unlimitedClasses", unitClass) == 0)
      return loc("multiplayer/cant_spawn/all_active_at_once", {
        name = colorize("activeTextColor", unit.expClass.getName())
        amountText = this.getOriginalLimitText("limitedClasses", unitClass)
      })

    if (this.calcLeftRespawnByKeys(teamBlk, "limitedUnits", "unlimitedUnits", unit.name) == 0)
      return loc("multiplayer/noTeamUnitLeft", {
        unitName = colorize("userlogColoredText", getUnitName(unit))
      })

    return null
  }

  function calcFullUnitLimitsData(_isTeamMine = true) {
    let res = base.calcFullUnitLimitsData()
    let teamBlk = this.getMyTeamDataBlk()
    if (!teamBlk)
      return res

    let limitedTypes = teamBlk?.limitedTypes
    let unlimitedTypes = teamBlk?.unlimitedTypes
    if (limitedTypes != null) {
      let checkedDsTypes = []
      foreach (unitType in unitTypes.types) {
        if (!unitType.isAvailable())
          continue
        let dsName = get_ds_ut_name_unit_type(unitType.esUnitType)
        if (checkedDsTypes.contains(dsName))
          continue
        checkedDsTypes.append(dsName)
        if (unlimitedTypes?[dsName] != null)
          continue
        let count = limitedTypes?[dsName]
        if (count != null)
          res.unitLimits.append(UnitLimitByUnitType(unitType.typeName, count))
      }
    }

    let limitedClasses = teamBlk?.limitedClasses
    let unlimitedClasses = teamBlk?.unlimitedClasses
    if (limitedClasses != null) {
      let total = limitedClasses.paramCount()
      for (local i = 0; i < total; i++) {
        let expClassName = limitedClasses.getParamName(i)
        if (unlimitedClasses?[expClassName] != null)
          continue
        if (getUnitClassTypeByExpClass(expClassName).isValid())
          res.unitLimits.append(UnitLimitByUnitExpClass(expClassName, limitedClasses.getParamValue(i)))
      }
    }

    let limitedUnits = teamBlk?.limitedUnits
    let unlimitedUnits = teamBlk?.unlimitedUnits
    if (limitedUnits != null) {
      let unitsGroups = this.getUnitsGroups()
      for (local i = 0; i < limitedUnits.paramCount(); i++) {
        let name = limitedUnits.getParamName(i)
        if (unlimitedUnits?[name] != null)
          continue
        res.unitLimits.append(UnitLimitByUnitName(name, limitedUnits.getParamValue(i),
          { nameLocId = unitsGroups?[name]?.name }))
      }
    }

    if (unlimitedUnits != null) {
      let unitsGroups = this.getUnitsGroups()
      for (local i = 0; i < unlimitedUnits.paramCount(); i++)
        res.unitLimits.append(UnitLimitByUnitName(unlimitedUnits.getParamName(i), RESPAWNS_UNLIMITED,
          { nameLocId = unitsGroups?[unlimitedUnits.getParamName(i)]?.name }))
      res.defaultUnitRespawnsLeft = 0
    }

    return res
  }

  function getOriginalLimitText(category, key) {
    let teamName = get_team_name_by_mp_team(get_mp_local_team())
    let maxLimit = this.getCustomRulesBlk()?.teams?[teamName]?[category]?[key]
    return maxLimit != null ? maxLimit.tostring() : ""
  }
}

registerMissionRules("ActiveUnitsPool", ActiveUnitsPool)
