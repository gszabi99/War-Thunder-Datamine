from "%scripts/dagui_natives.nut" import is_crew_slot_was_ready_at_host, stay_on_respawn_screen, get_user_custom_state, get_local_player_country, get_mission_custom_state
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { g_mis_loading_state } = require("%scripts/respawn/misLoadingState.nut")
let { get_team_name_by_mp_team } = require("%appGlobals/ranks_common_shared.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let DataBlock = require("DataBlock")
let { getAvailableRespawnBases } = require("guiRespawn")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { AMMO, getAmmoCost } = require("%scripts/weaponry/ammoInfo.nut")
let { isGameModeVersus } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { get_game_mode, get_game_type, get_local_mplayer, get_mp_local_team } = require("mission")
let { get_mission_difficulty_int, get_respawns_left,
  get_current_mission_desc } = require("guiMission")
let { get_current_mission_info_cached, get_warpoints_blk  } = require("blkGetters")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { isCrewAvailableInSession } = require("%scripts/respawn/respawnState.nut")
let { registerMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { isMissionExtrByName } = require("%scripts/missions/missionsUtils.nut")

let Base = class {
  missionParams = null
  isSpawnDelayEnabled = false
  isScoreRespawnEnabled = false
  isTeamScoreRespawnEnabled = false
  isRageTokensRespawnEnabled = false
  isWarpointsRespawnEnabled = false
  hasRespawnCost = false
  needShowLockedSlots = true
  isWorldWar = false

  needLeftRespawnOnSlots = false

  customUnitRespawnsAllyListHeaderLocId  = "multiplayer/teamUnitsLeftHeader"
  customUnitRespawnsEnemyListHeaderLocId = "multiplayer/enemyTeamUnitsLeftHeader"

  fullUnitsLimitData = null
  fullEnemyUnitsLimitData = null

  constructor() {
    this.initMissionParams()
  }

  function initMissionParams() {
    this.missionParams = DataBlock()
    get_current_mission_desc(this.missionParams)

    let isVersus = isGameModeVersus(get_game_mode())
    this.isSpawnDelayEnabled = isVersus && getTblValue("useSpawnDelay", this.missionParams, false)
    this.isTeamScoreRespawnEnabled = isVersus && getTblValue("useTeamSpawnScore", this.missionParams, false)
    this.isScoreRespawnEnabled = this.isTeamScoreRespawnEnabled || (isVersus && getTblValue("useSpawnScore", this.missionParams, false))
    this.isRageTokensRespawnEnabled = isMissionExtrByName(this.missionParams?.name ?? "")
    this.isWarpointsRespawnEnabled = isVersus && getTblValue("multiRespawn", this.missionParams, false)
    this.hasRespawnCost = this.isScoreRespawnEnabled || this.isWarpointsRespawnEnabled
    this.isWorldWar = isVersus && getTblValue("isWorldWar", this.missionParams, false)
    this.needShowLockedSlots = this.missionParams?.needShowLockedSlots ?? true
  }

  function onMissionStateChanged() {
    this.fullUnitsLimitData = null
    this.fullEnemyUnitsLimitData = null
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getMaxRespawns() {
    return ::RESPAWNS_UNLIMITED
  }

  function getLeftRespawns() {
    local res = ::RESPAWNS_UNLIMITED
    if (!this.isScoreRespawnEnabled && getTblValue("maxRespawns", this.missionParams, 0) > 0)
      res = get_respawns_left() //code return spawn score here when spawn score enabled instead of respawns left
    return res
  }

  function hasCustomUnitRespawns() {
    return false
  }

  function getUnitLeftRespawns(unit, teamDataBlk = null) {
    if (!unit || !this.isUnitEnabledByRandomGroups(unit.name))
      return 0
    return this.getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk || this.getMyTeamDataBlk())
  }

  function getUnitLeftWeaponShortText(unit) {
    let weaponsLimits = this.getWeaponsLimitsBlk()
    let unitWeaponLimit = getTblValue(unit.name, weaponsLimits, null)
    if (!unitWeaponLimit)
      return ""

    let presetNumber = unitWeaponLimit.respawnsLeft
    if (!presetNumber)
      return ""

    let presetIconsText = ::get_weapon_icons_text(unit.name, unitWeaponLimit.name)
    if (u.isEmpty(presetIconsText))
      return ""

    return $"{presetNumber}{presetIconsText}"
  }

  function getRespawnInfoTextForUnit(unit) {
    let unitLeftRespawns = this.getUnitLeftRespawns(unit)
    if (unitLeftRespawns == ::RESPAWNS_UNLIMITED || this.isUnitAvailableBySpawnScore(unit))
      return ""
    return loc("respawn/leftTeamUnit", { num = unitLeftRespawns })
  }

  function getRespawnInfoTextForUnitInfo(unit) {
    let unitLeftRespawns = this.getUnitLeftRespawns(unit)
    if (unitLeftRespawns == ::RESPAWNS_UNLIMITED)
      return ""
    return "".concat(loc("unitInfo/team_left_respawns"), loc("ui/colon"), unitLeftRespawns)
  }

  function getSpecialCantRespawnMessage(_unit) {
    return null
  }

  //return bitmask is crew can respawn by mission custom state for more easy check is it changed
  function getCurCrewsRespawnMask() {
    local res = 0
    if (!this.hasCustomUnitRespawns() || !this.getLeftRespawns())
      return res

    let crewsList = getCrewsListByCountry(get_local_player_country())
    let myTeamDataBlk = this.getMyTeamDataBlk()
    if (!myTeamDataBlk)
      return (1 << crewsList.len()) - 1

    foreach (idx, crew in crewsList)
      if (this.getUnitLeftRespawns(getCrewUnit(crew), myTeamDataBlk) != 0)
        res = res | (1 << idx)

    return res
  }

  function clearUnitsLimitData() {
    this.fullUnitsLimitData = null
  }

  function getFullUnitLimitsData() {
    if (!this.fullUnitsLimitData)
      this.fullUnitsLimitData = this.calcFullUnitLimitsData()
    return this.fullUnitsLimitData
  }

  function getFullEnemyUnitLimitsData() {
    if (!this.fullEnemyUnitsLimitData)
      this.fullEnemyUnitsLimitData = this.calcFullUnitLimitsData(false)
    return this.fullEnemyUnitsLimitData
  }

  function getEventDescByRulesTbl(_rulesTbl) {
    return ""
  }

  function isStayOnRespScreen() {
    return stay_on_respawn_screen()
  }

  function isAnyUnitHaveRespawnBases() {
    let country = get_local_player_country()

    let crewsInfo = ::g_crews_list.get()
    foreach (crew in crewsInfo)
      if (crew.country == country)
        foreach (slot in crew.crews) {
          let airName = ("aircraft" in slot) ? slot.aircraft : ""
          let air = getAircraftByName(airName)
          if (air
            && isCrewAvailableInSession(slot, air)
            && is_crew_slot_was_ready_at_host(slot.idInCountry, airName, false)
            && this.isUnitEnabledBySessionRank(air)
          ) {
            let respBases = getAvailableRespawnBases(air.tags)
            if (respBases.len() != 0)
              return true
          }
        }
    return false
  }

  function getCurSpawnScore() {
    if (this.isTeamScoreRespawnEnabled)
      return getTblValue("teamSpawnScore", get_local_mplayer(), 0)
    return this.isScoreRespawnEnabled ? getTblValue("spawnScore", get_local_mplayer(), 0) : 0
  }

  function canRespawnOnUnitBySpawnScore(unit) {
    return this.isScoreRespawnEnabled ? unit.getSpawnScore() <= this.getCurSpawnScore() : true
  }

  function getMinimalRequiredSpawnScore() {
    local res = -1
    if (!this.isScoreRespawnEnabled)
      return res

    let crews = getCrewsListByCountry(get_local_player_country())
    if (!crews)
      return res

    foreach (crew in crews) {
      let unit = getCrewUnit(crew)
      if (!unit
        || !isCrewAvailableInSession(crew, unit)
        || !is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, false)
        || !this.isUnitEnabledBySessionRank(unit))
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
  function getAvailableToSpawnUnitsData() {
    let res = []
    if (!(get_game_type() & (GT_VERSUS | GT_COOPERATIVE)))
      return res
    if (get_game_mode() == GM_SINGLE_MISSION || get_game_mode() == GM_DYNAMIC)
      return res
    if (!g_mis_loading_state.isCrewsListReceived())
      return res
    if (this.getLeftRespawns() == 0)
      return res

    let crews = getCrewsListByCountry(get_local_player_country())
    if (!crews)
      return res

    let curSpawnScore = this.getCurSpawnScore()
    foreach (c in crews) {
      local comment = ""
      let unit = getCrewUnit(c)
      if (!unit)
        continue

      if (!isCrewAvailableInSession(c, unit)
          || !is_crew_slot_was_ready_at_host(c.idInCountry, unit.name, false)
          || !getAvailableRespawnBases(unit.tags).len()
          || !this.getUnitLeftRespawns(unit)
          || !this.isUnitEnabledBySessionRank(unit)
          || unit.disableFlyout)
        continue

      if (this.isScoreRespawnEnabled && curSpawnScore >= 0
        && curSpawnScore < unit.getSpawnScore()) {
        if (curSpawnScore < unit.getMinimumSpawnScore())
          continue
        else
          comment = loc("respawn/withCheaperWeapon")
      }

      if (!this.canRespawnOnUnitByRageTokens(unit))
        continue

      res.append({
        unit = unit
        comment = comment
      })
    }

    return res
  }

  function getUnitFuelPercent(unitName) { //return 0 when fuel amount not fixed
    let unitsFuelPercentList = getTblValue("unitsFuelPercentList", this.getCustomRulesBlk())
    return getTblValue(unitName, unitsFuelPercentList, 0)
  }

  function hasWeaponLimits() {
    return this.getWeaponsLimitsBlk() != null
  }

  function isUnitWeaponAllowed(unit, weapon) {
    return !this.needCheckWeaponsAllowed(unit) || this.getUnitWeaponRespawnsLeft(unit, weapon) != 0
  }

  function getUnitWeaponRespawnsLeft(unit, weapon) {
    let limitsBlk = this.getWeaponsLimitsBlk()
    return limitsBlk ? this.getWeaponRespawnsLeftByLimitsBlk(unit, weapon, limitsBlk) : -1
  }

  function needCheckWeaponsAllowed(unit) {
    return !this.isMissionByUnitsGroups() && (unit.isAir() || unit.isHelicopter())
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getMisStateBlk() {
    return get_mission_custom_state(false)
  }

  function getMyStateBlk() {
    return get_user_custom_state(userIdInt64.value, false)
  }

  function getCustomRulesBlk() {
    return getTblValue("customRules", get_current_mission_info_cached())
  }

  function getTeamDataBlk(team, keyName) {
    let teamsBlk = getTblValue(keyName, this.getMisStateBlk())
    if (!teamsBlk)
      return null

    let res = getTblValue(get_team_name_by_mp_team(team), teamsBlk)
    return u.isDataBlock(res) ? res : null
  }

  function getMyTeamDataBlk(keyName = "teams") {
    return this.getTeamDataBlk(get_mp_local_team(), keyName)
  }

  function getEnemyTeamDataBlk(keyName = "teams") {
    let opponentTeamCode = ::g_team.getTeamByCode(get_mp_local_team()).opponentTeamCode
    if (opponentTeamCode == Team.none || opponentTeamCode == Team.Any)
      return null

    return this.getTeamDataBlk(opponentTeamCode, keyName)
  }

  //return -1 when unlimited
  function getUnitLeftRespawnsByTeamDataBlk(_unit, _teamDataBlk) {
    return ::RESPAWNS_UNLIMITED
  }

  function calcFullUnitLimitsData(_isTeamMine = true) {
    return {
      defaultUnitRespawnsLeft = ::RESPAWNS_UNLIMITED
      unitLimits = [] //unitLimitBaseClass
    }
  }

  function minRespawns(respawns1, respawns2) {
    if (respawns1 == ::RESPAWNS_UNLIMITED)
      return respawns2
    if (respawns2 == ::RESPAWNS_UNLIMITED)
      return respawns1
    return min(respawns1, respawns2)
  }

  function getWeaponsLimitsBlk() {
    return getTblValue("weaponList", this.getMyStateBlk())
  }

  //return -1 when unlimited
  function getWeaponRespawnsLeftByLimitsBlk(unit, weapon, weaponLimitsBlk) {
    if (getAmmoCost(unit, weapon.name, AMMO.WEAPON).isZero())
      return -1

    foreach (blk in weaponLimitsBlk % unit.name)
      if (blk?.name == weapon.name)
        return max(blk?.respawnsLeft ?? 0, 0)
    return 0
  }

  function getRandomUnitsGroupName(unitName) {
    let randomGroups = this.getMyStateBlk()?.random_units
    if (!randomGroups)
      return null
    foreach (unitsGroup in randomGroups) {
      if (unitName in unitsGroup)
        return unitsGroup.getBlockName()
    }
    return null
  }

  function getRandomUnitsList(groupName) {
    let unitsList = []
    let randomUnitsGroup = this.getMyStateBlk()?.random_units?[groupName]
    if (!randomUnitsGroup)
      return unitsList

    foreach (unitName, _u in randomUnitsGroup) {
      unitsList.append(unitName)
    }
    return unitsList
  }

  function getRandomUnitsGroupLocName(groupName) {
    return "".concat(loc("icon/dice/transparent"),
      loc(GUI.get()?.randomSpawnUnitPresets?[groupName]?.name
      ?? "respawn/randomUnitsGroup/name"))
  }

  function getRandomUnitsGroupIcon(groupName) {
    return GUI.get()?.randomSpawnUnitPresets?[groupName]?.icon
      ?? "!#ui/unitskin#random_unit.ddsx"
  }

  function isUnitEnabledByRandomGroups(unitName) {
    let randomGroups = this.getMyStateBlk()?.random_units
    if (!randomGroups)
      return true

    foreach (unitsGroup in randomGroups) {
      if (unitName in unitsGroup)
        return unitsGroup[unitName]
    }
    return true
  }

  function getRandomUnitsGroupLocBattleRating(groupName) {
    let randomGroups = this.getMyStateBlk()?.random_units?[groupName]
    if (!randomGroups)
      return ""

    let ediff = get_mission_difficulty_int()
    let getBR = @(unit) unit.getBattleRating(ediff)
    let valueBR = this.getRandomUnitsGroupValueRange(randomGroups, getBR)
    let minBR = valueBR.minValue
    let maxBR = valueBR.maxValue
    return (minBR != maxBR ? format("%.1f-%.1f", minBR, maxBR) : format("%.1f", minBR))
  }

  function getWeaponForRandomUnit(unit, weaponryName) {
    return this.missionParams?.editSlotbar?[unit.shopCountry]?[unit.name]?[weaponryName]
      ?? getLastWeapon(unit.name)
  }

  function getRandomUnitsGroupLocRank(groupName) {
    let randomGroups = this.getMyStateBlk()?.random_units?[groupName]
    if (!randomGroups)
      return ""

    let getRank = function(unit) { return unit.rank }
    let valueRank = this.getRandomUnitsGroupValueRange(randomGroups, getRank)
    let minRank = valueRank.minValue
    let maxRank = valueRank.maxValue
    let minRankText = get_roman_numeral(minRank)
    return minRank == maxRank ? minRankText : $"{minRankText}-{get_roman_numeral(maxRank)}"
  }

  function getRandomUnitsGroupValueRange(randomGroups, getValue) {
    local minValue
    local maxValue
    foreach (name, _u in randomGroups) {
      let unit = getAircraftByName(name)

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

  function isUnitForcedVisible(unitName) {
    if (this.getMyStateBlk()?.ownAvailableUnits[unitName] == true)
      return true

    let missionUnitName = this.getMyStateBlk()?.userUnitToUnitGroup[unitName] ?? ""

    return missionUnitName != "" && (this.getMyTeamDataBlk()?.limitedUnits[missionUnitName] ?? -1) >= 0
  }

  function isWorldWarUnit(unitName) {
    return this.isWorldWar && this.getMyStateBlk()?.ownAvailableUnits?[unitName] == false
  }

  function isUnitAvailableBySpawnScore(_unit) {
    return false
  }

  function isRespawnAvailable(unit) {
    return this.getUnitLeftRespawns(unit) != 0
      || (this.isUnitAvailableBySpawnScore(unit)
        && this.canRespawnOnUnitBySpawnScore(unit))
  }

  function isEnemyLimitedUnitsVisible() {
    return false
  }

  function isUnitForcedHiden(unitName) {
    return this.getMyStateBlk()?.forcedUnitsStates?[unitName]?.hidden ?? false
  }

  isMissionByUnitsGroups = @() this.missionParams?.unitGroups != null

  function getUnitsGroups() {
    let fullGroupsList = {}
    foreach (countryBlk in (this.missionParams?.unitGroups ?? []))
      for (local i = 0; i < countryBlk.blockCount(); i++) {
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
    let icon = this.missionParams?[$"countryFlagTeam{team != Team.B ? "A" : "B"}"]
    return icon == "" ? null : icon
  }

  getMinSessionRank = @() this.missionParams?.ranks.min ?? 0
  function isUnitEnabledBySessionRank(unit) {
    if (!(this.missionParams?.disableUnitsOutOfSessionRank ?? false) || (unit == null))
      return true
    return unit.getEconomicRank(get_mission_difficulty_int()) >= this.getMinSessionRank()
  }

  isAllowSpareInMission = @() this.missionParams?.allowSpare ?? false

  getSpawnRageTokens = @() this.isRageTokensRespawnEnabled ? get_local_mplayer()?.rageTokens ?? 0 : 0
  getUnitSpawnRageTokens = @(unit) this.isRageTokensRespawnEnabled ? get_warpoints_blk()?.rageCost[unit.name] ?? 0 : 0
  canRespawnOnUnitByRageTokens = @(unit) !this.isRageTokensRespawnEnabled
    || this.getUnitSpawnRageTokens(unit) <= this.getSpawnRageTokens()
}

registerMissionRules("Base", Base)

//just for case when empty rules will not the same as base
registerMissionRules("Empty", class (Base) {})

return Base
