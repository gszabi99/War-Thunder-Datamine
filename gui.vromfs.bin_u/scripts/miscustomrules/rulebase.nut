let { format } = require("string")
let { getAvailableRespawnBases } = require_native("guiRespawn")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { AMMO, getAmmoCost } = require("%scripts/weaponry/ammoInfo.nut")
let { isGameModeVersus } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { GUI } = require("%scripts/utils/configs.nut")

::mission_rules.Base <- class
{
  missionParams = null
  isSpawnDelayEnabled = false
  isScoreRespawnEnabled = false
  isTeamScoreRespawnEnabled = false
  isWarpointsRespawnEnabled = false
  hasRespawnCost = false
  needShowLockedSlots = true
  isWorldWar = false

  needLeftRespawnOnSlots = false

  customUnitRespawnsAllyListHeaderLocId  = "multiplayer/teamUnitsLeftHeader"
  customUnitRespawnsEnemyListHeaderLocId = "multiplayer/enemyTeamUnitsLeftHeader"

  fullUnitsLimitData = null
  fullEnemyUnitsLimitData = null

  constructor()
  {
    initMissionParams()
  }

  function initMissionParams()
  {
    missionParams = ::DataBlock()
    ::get_current_mission_desc(missionParams)

    let isVersus = isGameModeVersus(::get_game_mode())
    isSpawnDelayEnabled = isVersus && ::getTblValue("useSpawnDelay", missionParams, false)
    isTeamScoreRespawnEnabled = isVersus && ::getTblValue("useTeamSpawnScore", missionParams, false)
    isScoreRespawnEnabled = isTeamScoreRespawnEnabled || (isVersus && ::getTblValue("useSpawnScore", missionParams, false))
    isWarpointsRespawnEnabled = isVersus && ::getTblValue("multiRespawn", missionParams, false)
    hasRespawnCost = isScoreRespawnEnabled || isWarpointsRespawnEnabled
    isWorldWar = isVersus && ::getTblValue("isWorldWar", missionParams, false)
    needShowLockedSlots = missionParams?.needShowLockedSlots ?? true
  }

  function onMissionStateChanged()
  {
    fullUnitsLimitData = null
    fullEnemyUnitsLimitData = null
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getMaxRespawns()
  {
    return ::RESPAWNS_UNLIMITED
  }

  function getLeftRespawns()
  {
    local res = ::RESPAWNS_UNLIMITED
    if (!isScoreRespawnEnabled && ::getTblValue("maxRespawns", missionParams, 0) > 0)
      res = ::get_respawns_left() //code return spawn score here when spawn score enabled instead of respawns left
    return res
  }

  function hasCustomUnitRespawns()
  {
    return false
  }

  function getUnitLeftRespawns(unit, teamDataBlk = null)
  {
    if (!unit || !isUnitEnabledByRandomGroups(unit.name))
      return 0
    return getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk || getMyTeamDataBlk())
  }

  function getUnitLeftWeaponShortText(unit)
  {
    let weaponsLimits = getWeaponsLimitsBlk()
    let unitWeaponLimit = ::getTblValue(unit.name, weaponsLimits, null)
    if (!unitWeaponLimit)
      return ""

    let presetNumber = unitWeaponLimit.respawnsLeft
    if (!presetNumber)
      return ""

    let presetIconsText = ::get_weapon_icons_text(unit.name, unitWeaponLimit.name)
    if (::u.isEmpty(presetIconsText))
      return ""

    return presetNumber + presetIconsText
  }

  function getRespawnInfoTextForUnit(unit)
  {
    let unitLeftRespawns = getUnitLeftRespawns(unit)
    if (unitLeftRespawns == ::RESPAWNS_UNLIMITED || isUnitAvailableBySpawnScore(unit))
      return ""
    return ::loc("respawn/leftTeamUnit", { num = unitLeftRespawns })
  }

  function getRespawnInfoTextForUnitInfo(unit)
  {
    let unitLeftRespawns = getUnitLeftRespawns(unit)
    if (unitLeftRespawns == ::RESPAWNS_UNLIMITED)
      return ""
    return ::loc("unitInfo/team_left_respawns") + ::loc("ui/colon") + unitLeftRespawns
  }

  function getSpecialCantRespawnMessage(unit)
  {
    return null
  }

  //return bitmask is crew can respawn by mission custom state for more easy check is it changed
  function getCurCrewsRespawnMask()
  {
    local res = 0
    if (!hasCustomUnitRespawns() || !getLeftRespawns())
      return res

    let crewsList = ::get_crews_list_by_country(::get_local_player_country())
    let myTeamDataBlk = getMyTeamDataBlk()
    if (!myTeamDataBlk)
      return (1 << crewsList.len()) - 1

    foreach(idx, crew in crewsList)
      if (getUnitLeftRespawns(::g_crew.getCrewUnit(crew), myTeamDataBlk) != 0)
        res = res | (1 << idx)

    return res
  }

  /*
    {
      defaultUnitRespawnsLeft = 0 //respawns left for units not in list
      unitLimits = [] //::g_unit_limit_classes.LimitBase
    }
  */
  function getFullUnitLimitsData()
  {
    if (!fullUnitsLimitData)
      fullUnitsLimitData = calcFullUnitLimitsData()
    return fullUnitsLimitData
  }

  function getFullEnemyUnitLimitsData()
  {
    if (!fullEnemyUnitsLimitData)
      fullEnemyUnitsLimitData = calcFullUnitLimitsData(false)
    return fullEnemyUnitsLimitData
  }

  function getEventDescByRulesTbl(rulesTbl)
  {
    return ""
  }

  function isStayOnRespScreen()
  {
    return ::stay_on_respawn_screen()
  }

  function isAnyUnitHaveRespawnBases()
  {
    let country = ::get_local_player_country()

    let crewsInfo = ::g_crews_list.get()
    foreach(crew in crewsInfo)
      if (crew.country == country)
        foreach (slot in crew.crews)
        {
          let airName = ("aircraft" in slot) ? slot.aircraft : ""
          let air = ::getAircraftByName(airName)
          if (air
            && ::is_crew_available_in_session(slot.idInCountry, false)
            && ::is_crew_slot_was_ready_at_host(slot.idInCountry, airName, false)
            && isUnitEnabledBySessionRank(air)
          ) {
            let respBases = getAvailableRespawnBases(air.tags)
            if (respBases.len() != 0)
              return true
          }
        }
    return false
  }

  function getCurSpawnScore()
  {
    if (isTeamScoreRespawnEnabled)
      return ::getTblValue("teamSpawnScore", ::get_local_mplayer(), 0)
    return isScoreRespawnEnabled ? ::getTblValue("spawnScore", ::get_local_mplayer(), 0) : 0
  }

  function canRespawnOnUnitBySpawnScore(unit)
  {
    return isScoreRespawnEnabled ? unit.getSpawnScore() <= getCurSpawnScore() : true
  }

  function getMinimalRequiredSpawnScore()
  {
    local res = -1
    if (!isScoreRespawnEnabled)
      return res

    let crews = ::get_crews_list_by_country(::get_local_player_country())
    if (!crews)
      return res

    foreach(crew in crews)
    {
      let unit = ::g_crew.getCrewUnit(crew)
      if (!unit
        || !::is_crew_available_in_session(crew.idInCountry, false)
        || !::is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, false)
        || !isUnitEnabledBySessionRank(unit))
        continue

      let minScore = unit.getMinimumSpawnScore()
      if (res < 0 || res > minScore)
        res = minScore
    }
    return res
  }

  /*
  return [
    {
      unit = unit
      comment  = "" //what need to do to spawn on that unit
    }
    ...
  ]
  */
  function getAvailableToSpawnUnitsData()
  {
    let res = []
    if (!(::get_game_type() & (::GT_VERSUS | ::GT_COOPERATIVE)))
      return res
    if (::get_game_mode() == ::GM_SINGLE_MISSION || ::get_game_mode() == ::GM_DYNAMIC)
      return res
    if (!::g_mis_loading_state.isCrewsListReceived())
      return res
    if (getLeftRespawns() == 0)
      return res

    let crews = ::get_crews_list_by_country(::get_local_player_country())
    if (!crews)
      return res

    let curSpawnScore = getCurSpawnScore()
    foreach (c in crews)
    {
      local comment = ""
      let unit = ::g_crew.getCrewUnit(c)
      if (!unit)
        continue

      if (!::is_crew_available_in_session(c.idInCountry, false)
          || !::is_crew_slot_was_ready_at_host(c.idInCountry, unit.name, false)
          || !getAvailableRespawnBases(unit.tags).len()
          || !getUnitLeftRespawns(unit)
          || !isUnitEnabledBySessionRank(unit)
          || unit.disableFlyout)
        continue

      if (isScoreRespawnEnabled && curSpawnScore >= 0
        && curSpawnScore < unit.getSpawnScore())
      {
        if (curSpawnScore < unit.getMinimumSpawnScore())
          continue
        else
          comment = ::loc("respawn/withCheaperWeapon")
      }

      res.append({
        unit = unit
        comment = comment
      })
    }

    return res
  }

  function getUnitFuelPercent(unitName) //return 0 when fuel amount not fixed
  {
    let unitsFuelPercentList = ::getTblValue("unitsFuelPercentList", getCustomRulesBlk())
    return ::getTblValue(unitName, unitsFuelPercentList, 0)
  }

  function hasWeaponLimits()
  {
    return getWeaponsLimitsBlk() != null
  }

  function isUnitWeaponAllowed(unit, weapon)
  {
    return !needCheckWeaponsAllowed(unit) || getUnitWeaponRespawnsLeft(unit, weapon) != 0
  }

  function getUnitWeaponRespawnsLeft(unit, weapon)
  {
    let limitsBlk = getWeaponsLimitsBlk()
    return limitsBlk ? getWeaponRespawnsLeftByLimitsBlk(unit, weapon, limitsBlk) : -1
  }

  function needCheckWeaponsAllowed(unit)
  {
    return !isMissionByUnitsGroups() && (unit.isAir() || unit.isHelicopter())
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getMisStateBlk()
  {
    return ::get_mission_custom_state(false)
  }

  function getMyStateBlk()
  {
    return ::get_user_custom_state(::my_user_id_int64, false)
  }

  function getCustomRulesBlk()
  {
    return ::getTblValue("customRules", ::get_current_mission_info_cached())
  }

  function getTeamDataBlk(team, keyName)
  {
    let teamsBlk = ::getTblValue(keyName, getMisStateBlk())
    if (!teamsBlk)
      return null

    let res = ::getTblValue(::get_team_name_by_mp_team(team), teamsBlk)
    return ::u.isDataBlock(res) ? res : null
  }

  function getMyTeamDataBlk(keyName = "teams")
  {
    return getTeamDataBlk(::get_mp_local_team(), keyName)
  }

  function getEnemyTeamDataBlk(keyName = "teams")
  {
    let opponentTeamCode = ::g_team.getTeamByCode(::get_mp_local_team()).opponentTeamCode
    if (opponentTeamCode == Team.none || opponentTeamCode == Team.Any)
      return null

    return getTeamDataBlk(opponentTeamCode, keyName)
  }

  //return -1 when unlimited
  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk)
  {
    return ::RESPAWNS_UNLIMITED
  }

  function calcFullUnitLimitsData(isTeamMine = true)
  {
    return {
      defaultUnitRespawnsLeft = ::RESPAWNS_UNLIMITED
      unitLimits = [] //::g_unit_limit_classes.LimitBase
    }
  }

  function minRespawns(respawns1, respawns2)
  {
    if (respawns1 == ::RESPAWNS_UNLIMITED)
      return respawns2
    if (respawns2 == ::RESPAWNS_UNLIMITED)
      return respawns1
    return min(respawns1, respawns2)
  }

  function getWeaponsLimitsBlk()
  {
    return ::getTblValue("weaponList", getMyStateBlk())
  }

  //return -1 when unlimited
  function getWeaponRespawnsLeftByLimitsBlk(unit, weapon, weaponLimitsBlk)
  {
    if (getAmmoCost(unit, weapon.name, AMMO.WEAPON).isZero())
      return -1

    foreach(blk in weaponLimitsBlk % unit.name)
      if (blk?.name == weapon.name)
        return max(blk?.respawnsLeft ?? 0, 0)
    return 0
  }

  function getRandomUnitsGroupName(unitName)
  {
    let randomGroups = getMyStateBlk()?.random_units
    if (!randomGroups)
      return null
    foreach (unitsGroup in randomGroups)
    {
      if (unitName in unitsGroup)
        return unitsGroup.getBlockName()
    }
    return null
  }

  function getRandomUnitsList(groupName)
  {
    let unitsList = []
    let randomUnitsGroup = getMyStateBlk()?.random_units?[groupName]
    if (!randomUnitsGroup)
      return unitsList

    foreach (unitName, u in randomUnitsGroup)
    {
      unitsList.append(unitName)
    }
    return unitsList
  }

  function getRandomUnitsGroupLocName(groupName)
  {
    return ::loc("icon/dice/transparent") +
      ::loc(GUI.get()?.randomSpawnUnitPresets?[groupName]?.name
      ?? "respawn/randomUnitsGroup/name")
  }

  function getRandomUnitsGroupIcon(groupName)
  {
    return GUI.get()?.randomSpawnUnitPresets?[groupName]?.icon
      ?? "!#ui/unitskin#random_unit"
  }

  function isUnitEnabledByRandomGroups(unitName)
  {
    let randomGroups = getMyStateBlk()?.random_units
    if (!randomGroups)
      return true

    foreach (unitsGroup in randomGroups)
    {
      if (unitName in unitsGroup)
        return unitsGroup[unitName]
    }
    return true
  }

  function getRandomUnitsGroupLocBattleRating(groupName)
  {
    let randomGroups = getMyStateBlk()?.random_units?[groupName]
    if (!randomGroups)
      return ""

    let ediff = ::get_mission_difficulty_int()
    let getBR = @(unit) unit.getBattleRating(ediff)
    let valueBR = getRandomUnitsGroupValueRange(randomGroups, getBR)
    let minBR = valueBR.minValue
    let maxBR = valueBR.maxValue
    return (minBR != maxBR ? format("%.1f-%.1f", minBR, maxBR) : format("%.1f", minBR))
  }

  function getWeaponForRandomUnit(unit, weaponryName)
  {
    return missionParams?.editSlotbar?[unit.shopCountry]?[unit.name]?[weaponryName]
      ?? getLastWeapon(unit.name)
  }

  function getRandomUnitsGroupLocRank(groupName)
  {
    let randomGroups = getMyStateBlk()?.random_units?[groupName]
    if (!randomGroups)
      return ""

    let getRank = function(unit) {return unit.rank}
    let valueRank = getRandomUnitsGroupValueRange(randomGroups, getRank)
    let minRank = valueRank.minValue
    let maxRank = valueRank.maxValue
    return ::get_roman_numeral(minRank) + ((minRank != maxRank) ? "-" + ::get_roman_numeral(maxRank) : "")
  }

  function getRandomUnitsGroupValueRange(randomGroups, getValue)
  {
    local minValue
    local maxValue
    foreach(name, u in randomGroups)
    {
      let unit = ::getAircraftByName(name)

      if (!unit)
        continue

      let value = getValue(unit)
      minValue = (minValue == null) ? value : min(minValue, value)
      maxValue = (maxValue == null) ? value : max(maxValue, value)
    }
    return {
      minValue = minValue ?? 0
      maxValue = maxValue ?? 0
    }
  }

  function isUnitForcedVisible(unitName)
  {
    if (getMyStateBlk()?.ownAvailableUnits[unitName] == true)
      return true

    let missionUnitName = getMyStateBlk()?.userUnitToUnitGroup[unitName] ?? ""

    return missionUnitName != "" && (getMyTeamDataBlk()?.limitedUnits[missionUnitName] ?? -1) >= 0
  }

  function isWorldWarUnit(unitName)
  {
    return isWorldWar && getMyStateBlk()?.ownAvailableUnits?[unitName] == false
  }

  function isUnitAvailableBySpawnScore(unit)
  {
    return false
  }

  function isRespawnAvailable(unit)
  {
    return getUnitLeftRespawns(unit) != 0
      || (isUnitAvailableBySpawnScore(unit)
        && canRespawnOnUnitBySpawnScore(unit))
  }

  function isEnemyLimitedUnitsVisible()
  {
    return false
  }

  function isUnitForcedHiden(unitName)
  {
    return getMyStateBlk()?.forcedUnitsStates?[unitName]?.hidden ?? false
  }

  isMissionByUnitsGroups = @() missionParams?.unitGroups != null

  function getUnitsGroups() {
    let fullGroupsList = {}
    foreach (countryBlk in (missionParams?.unitGroups ?? []))
      for (local i = 0; i < countryBlk.blockCount(); i++)
      {
        let groupBlk = countryBlk.getBlock(i)
        let unitList = groupBlk?.unitList
        fullGroupsList[groupBlk.getBlockName()] <- {
          name = groupBlk?.name ?? ""
          defaultUnit = groupBlk?.defaultUnit ?? ""
          units = unitList != null ? (unitList % "unit") : []
        }
      }

    return fullGroupsList
  }

  function getOverrideCountryIconByTeam(team) {
    let icon = missionParams?[$"countryFlagTeam{team != Team.B ? "A" : "B"}"]
    return icon == "" ? null : icon
  }

  getMinSessionRank = @() missionParams?.ranks.min ?? 0
  function isUnitEnabledBySessionRank(unit) {
    if (!(missionParams?.disableUnitsOutOfSessionRank ?? false) || (unit == null))
      return true
    return unit.getEconomicRank(::get_mission_difficulty_int()) >= getMinSessionRank()
  }
}

//just for case when empty rules will not the same as base
::mission_rules.Empty <- class extends ::mission_rules.Base
{
}
