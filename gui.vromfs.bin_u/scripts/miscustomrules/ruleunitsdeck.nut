::mission_rules.UnitsDeck <- class extends ::mission_rules.Base
{
  needLeftRespawnOnSlots = true

  function getLeftRespawns()
  {
    return ::RESPAWNS_UNLIMITED
  }

  function getRespawnInfoTextForUnitInfo(unit)
  {
    return ::loc("multiplayer/leftTeamUnit",
                 { num = getUnitLeftRespawns(unit) })
  }

  function getUnitLeftRespawns(unit, teamDataBlk = null)
  {
    if (!unit)
      return 0
    let myState = getMyStateBlk()
    let limitedUnits = ::getTblValue("limitedUnits", myState)
    return ::getTblValue(unit.name, limitedUnits, 0)
  }

  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk)
  {
    if (!unit)
      return 0

    return teamDataBlk?.limitedUnits?[unit.name] ?? ::RESPAWNS_UNLIMITED
  }

  function getSpecialCantRespawnMessage(unit)
  {
    let leftRespawns = getUnitLeftRespawns(unit)
    if (leftRespawns || isUnitAvailableBySpawnScore(unit))
      return null
    return ::loc("respawn/noUnitLeft", { unitName = ::colorize("userlogColoredText", ::getUnitName(unit)) })
  }

  function hasCustomUnitRespawns()
  {
    let myTeamDataBlk = getMyTeamDataBlk()
    return myTeamDataBlk != null
  }

  function calcFullUnitLimitsData(isTeamMine = true)
  {
    let res = base.calcFullUnitLimitsData()
    res.defaultUnitRespawnsLeft = 0

    let myTeamDataBlk = isTeamMine ? getMyTeamDataBlk() : getEnemyTeamDataBlk()
    let distributedBlk = ::getTblValue("distributedUnits", myTeamDataBlk)
    let limitedBlk = ::getTblValue("limitedUnits", myTeamDataBlk)
    let myTeamUnitsParamsBlk = isTeamMine
      ? getMyTeamDataBlk("unitsParamsList") : getEnemyTeamDataBlk("unitsParamsList")
    let weaponsLimitsBlk = getWeaponsLimitsBlk()
    let unitsGroups = getUnitsGroups()

    if (::u.isDataBlock(limitedBlk))
      for(local i = 0; i < limitedBlk.paramCount(); i++)
      {
        let unitName = limitedBlk.getParamName(i)
        let teamUnitPreset = ::getTblValue(unitName, myTeamUnitsParamsBlk, null)
        let userUnitPreset = ::getTblValue(unitName, weaponsLimitsBlk, null)
        let weapon = ::getTblValue("weapon", teamUnitPreset, null)

        let presetData = {
          weaponPresetId = ::getTblValue("name", weapon, "")
          teamUnitPresetAmount = ::getTblValue("count", weapon, "")
          userUnitPresetAmount = ::getTblValue("respawnsLeft", userUnitPreset, 0)
        }

        let group = unitsGroups?[unitName]
        let limit = ::g_unit_limit_classes.LimitByUnitName(
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

  function isUnitAvailableBySpawnScore(unit)
  {
    if (!unit)
      return false

    local missionUnit = unit
    let missionUnitName = getMyStateBlk()?.userUnitToUnitGroup[unit.name] ?? ""
    if (missionUnitName != "")
      missionUnit = ::getAircraftByName(missionUnitName)

    return getUnitLeftRespawns(unit) == 0
      && getUnitLeftRespawnsByTeamDataBlk(missionUnit, getMyTeamDataBlk()) != 0
      && isScoreRespawnEnabled
      && unit.getSpawnScore() > 0
  }

  function isEnemyLimitedUnitsVisible()
  {
    return ::get_current_mission_info_cached()?.customRules?.showEnemiesLimitedUnits == true
  }
}
