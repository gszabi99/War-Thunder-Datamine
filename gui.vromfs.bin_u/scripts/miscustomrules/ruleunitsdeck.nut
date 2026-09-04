import "%sqStdLibs/helpers/u.nut" as u
from "blkGetters" import get_current_mission_info_cached
from "%scripts/dagui_library.nut" import *
from "%scripts/misCustomRules/ruleConsts.nut" import RESPAWNS_UNLIMITED

let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { registerMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let RuleBase = require("%scripts/misCustomRules/ruleBase.nut")
let { UnitLimitByUnitName } = require("%scripts/misCustomRules/unitLimit.nut")

let UnitsDeck = class (RuleBase) {
  needLeftRespawnOnSlots = true

  function getLeftRespawns() {
    return RESPAWNS_UNLIMITED
  }

  function getRespawnInfoTextForUnitInfo(unit) {
    return loc("multiplayer/leftTeamUnit",
                 { num = this.getUnitLeftRespawns(unit) })
  }

  function getUnitLeftRespawns(unit, _teamDataBlk = null) {
    if (!unit)
      return 0
    let myState = this.getMyStateBlk()
    let limitedUnits = myState?.limitedUnits
    return (limitedUnits?[unit.name] ?? 0)
  }

  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk) {
    if (!unit)
      return 0

    return teamDataBlk?.limitedUnits?[unit.name] ?? RESPAWNS_UNLIMITED
  }

  function getSpecialCantRespawnMessage(unit) {
    let leftRespawns = this.getUnitLeftRespawns(unit)
    if (leftRespawns || this.isUnitAvailableBySpawnScore(unit))
      return null
    return loc("respawn/noUnitLeft", { unitName = colorize("userlogColoredText", getUnitName(unit)) })
  }

  function hasCustomUnitRespawns() {
    let myTeamDataBlk = this.getMyTeamDataBlk()
    return myTeamDataBlk != null
  }

  function calcFullUnitLimitsData(isTeamMine = true) {
    let res = base.calcFullUnitLimitsData()
    res.defaultUnitRespawnsLeft = 0

    let myTeamDataBlk = isTeamMine ? this.getMyTeamDataBlk() : this.getEnemyTeamDataBlk()
    let distributedBlk = myTeamDataBlk?.distributedUnits
    let limitedBlk = myTeamDataBlk?.limitedUnits
    let myTeamUnitsParamsBlk = isTeamMine
      ? this.getMyTeamDataBlk("unitsParamsList") : this.getEnemyTeamDataBlk("unitsParamsList")
    let weaponsLimitsBlk = this.getWeaponsLimitsBlk()
    let unitsGroups = this.getUnitsGroups()

    if (u.isDataBlock(limitedBlk))
      for (local i = 0; i < limitedBlk.paramCount(); i++) {
        let unitName = limitedBlk.getParamName(i)
        let teamUnitPreset = myTeamUnitsParamsBlk?[unitName]
        let userUnitPreset = weaponsLimitsBlk?[unitName]
        let weapon = teamUnitPreset?.weapon

        let presetData = {
          weaponPresetId = (weapon?.name ?? "")
          teamUnitPresetAmount = (weapon?.count ?? "")
          userUnitPresetAmount = (userUnitPreset?.respawnsLeft ?? 0)
        }

        let group = unitsGroups?[unitName]
        let limit = UnitLimitByUnitName(
          unitName,
          limitedBlk.getParamValue(i),
          {
            distributed = isTeamMine ? distributedBlk?[unitName] ?? 0 : null
            presetInfo = group == null ? presetData : null
            nameLocId = group?.name
          }
        )

        res.unitLimits.append(limit)
      }
    return res
  }

  function isUnitAvailableBySpawnScore(unit) {
    if (!unit)
      return false

    local missionUnit = unit
    let missionUnitName = this.getMyStateBlk()?.userUnitToUnitGroup[unit.name] ?? ""
    if (missionUnitName != "")
      missionUnit = getAircraftByName(missionUnitName)

    return this.getUnitLeftRespawns(unit) == 0
      && this.getUnitLeftRespawnsByTeamDataBlk(missionUnit, this.getMyTeamDataBlk()) != 0
      && this.isScoreRespawnEnabled
      && unit.getSpawnScore() > 0
  }

  function isEnemyLimitedUnitsVisible() {
    return get_current_mission_info_cached()?.customRules?.showEnemiesLimitedUnits == true
  }
}

registerMissionRules("UnitsDeck", UnitsDeck)
