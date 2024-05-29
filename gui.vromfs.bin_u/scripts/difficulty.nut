from "%scripts/dagui_natives.nut" import get_name_by_gamemode, get_difficulty_name
from "%scripts/dagui_library.nut" import *
from "%scripts/gameModes/gameModeConsts.nut" import BATTLE_TYPES

let { get_cd_preset } = require("guiOptions")
let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")
let { USEROPT_CONTENT_ALLOWED_PRESET, USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES,
  USEROPT_CONTENT_ALLOWED_PRESET_ARCADE, USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES,
  USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC, USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES,
  USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR } = require("%scripts/options/optionsExtNames.nut")
let { EDIFF_SHIFT } = require("%appGlobals/ranks_common_shared.nut")

let g_difficulty_cache = {
  byDiffCode = {}
  byName = {}
  byEgdCode = {}
  byEgdLowercaseName = {}
  byMatchingName = {}
  byCrewSkillName = {}
}


let g_difficulty = {
  types = []

  template = {
    diffCode = -1
    name = ""
    icon = ""
    locId = ""
    egdCode = EGD_NONE
    egdLowercaseName = get_name_by_gamemode(EGD_NONE, false) // none
    gameTypeName = ""
    matchingName = ""
    crewSkillName = "" // Used in crewSkillParameters.nut
    settingsName = "" // Used in _difficulty.blk difficulty_settings.
    clanReqOption = "" //Used in clan membership requirement
    clanDataEnding = ""
    clanRatingImage = "#ui/gameuiskin#lb_elo_rating.svg"
    contentAllowedPresetOption = USEROPT_CONTENT_ALLOWED_PRESET
    contentAllowedPresetOptionDefVal = "semihistorical"
    cdPresetValue = get_cd_preset(DIFFICULTY_CUSTOM)
    getEgdName = function(capital = true) { return get_name_by_gamemode(this.egdCode, capital) } //"none", "arcade", "historical", "simulation"
    getLocName = function() { return loc(this.locId) }

    abbreviation = ""
    choiceType = []
    arcadeCountry = false
    hasRespawns = false
    isAvailable = function(_gm = null) { return true }
    getEdiff = function(battleType = BATTLE_TYPES.AIR) {
      if (this.diffCode == -1)
        return -1

      let ediffShiftMul = battleType == BATTLE_TYPES.TANK ? 1
        : battleType == BATTLE_TYPES.SHIP ? 2
        : 0
      return this.diffCode + EDIFF_SHIFT * ediffShiftMul
    }
    getEdiffByUnitMask = function(unitTypesMask = 0) {
      if (this.diffCode == -1)
        return -1

      let ediffShiftMul = ((unitTypesMask & (1 << ES_UNIT_TYPE_TANK)) != 0) ? 1
        : ((unitTypesMask & (1 << ES_UNIT_TYPE_SHIP)) != 0 || (unitTypesMask & (1 << ES_UNIT_TYPE_BOAT)) != 0) ? 2
        : 0
      return this.diffCode + EDIFF_SHIFT * ediffShiftMul
    }
    needCheckTutorial = false
  }

  function getDifficultyByDiffCode(diffCode) {
    return enumsGetCachedType("diffCode", diffCode, g_difficulty_cache.byDiffCode, this, this.UNKNOWN)
  }

  function getDifficultyByName(name) {
    return enumsGetCachedType("name", name, g_difficulty_cache.byName, this, this.UNKNOWN)
  }

  function getDifficultyByEgdCode(egdCode) {
    return enumsGetCachedType("egdCode", egdCode, g_difficulty_cache.byEgdCode, this, this.UNKNOWN)
  }

  function getDifficultyByEgdLowercaseName(name) {
    return enumsGetCachedType("egdLowercaseName", name, g_difficulty_cache.byEgdLowercaseName,
                                          this, this.UNKNOWN)
  }

  function getDifficultyByMatchingName(name) {
    return enumsGetCachedType("matchingName", name, g_difficulty_cache.byMatchingName,
                                          this, this.UNKNOWN)
  }

  function getDifficultyByCrewSkillName(name) {
    return enumsGetCachedType("crewSkillName", name, g_difficulty_cache.byCrewSkillName,
                                        this, this.UNKNOWN)
  }

  function isDiffCodeAvailable(diffCode, gm = null) {
    return this.getDifficultyByDiffCode(diffCode).isAvailable(gm)
  }

  function getDifficultyByChoiceType(searchChoiceType = "") {
    foreach (t in this.types)
      if (isInArray(searchChoiceType, t.choiceType))
        return t

    return this.UNKNOWN
  }

}


enumsAddTypes(g_difficulty, {
  UNKNOWN = {
    name = "unknown"
    isAvailable = function(...) { return false }
  }

  ARCADE = {
    diffCode = DIFFICULTY_ARCADE
    name = get_difficulty_name(DIFFICULTY_ARCADE) // arcade
    icon = "#ui/gameuiskin#mission_complete_arcade"
    locId = "mainmenu/arcadeInstantAction"
    egdCode = EGD_ARCADE
    egdLowercaseName = get_name_by_gamemode(EGD_ARCADE, false) // arcade
    gameTypeName = "arcade"
    matchingName = "arcade"
    crewSkillName = "arcade"
    settingsName = "easy"
    clanReqOption = USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES
    clanDataEnding = "_arc"
    clanRatingImage = "#ui/gameuiskin#lb_elo_rating_arcade.svg"
    contentAllowedPresetOption = USEROPT_CONTENT_ALLOWED_PRESET_ARCADE
    cdPresetValue = get_cd_preset(DIFFICULTY_ARCADE)
    abbreviation = "clan/shortArcadeBattle"
    choiceType = ["AirAB", "TankAB", "ShipAB"]
    arcadeCountry = true
    hasRespawns = true
  }

  REALISTIC = {
    diffCode = DIFFICULTY_REALISTIC
    name = get_difficulty_name(DIFFICULTY_REALISTIC) // realistic
    icon = "#ui/gameuiskin#mission_complete_realistic"
    locId = "mainmenu/instantAction"
    egdCode = EGD_HISTORICAL
    egdLowercaseName = get_name_by_gamemode(EGD_HISTORICAL, false) // historical
    gameTypeName = "historical"
    matchingName = "realistic"
    crewSkillName = "historical"
    settingsName = "medium"
    clanReqOption = USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES
    clanDataEnding = "_hist"
    contentAllowedPresetOption = USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC
    cdPresetValue = get_cd_preset(DIFFICULTY_REALISTIC)
    abbreviation = "clan/shortHistoricalBattle"
    choiceType = ["AirRB", "TankRB", "ShipRB"]
    arcadeCountry = true
    hasRespawns = false
    needCheckTutorial = true
  }

  SIMULATOR = {
    diffCode = DIFFICULTY_HARDCORE
    name = get_difficulty_name(DIFFICULTY_HARDCORE) // hardcore
    icon = "#ui/gameuiskin#mission_complete_simulator"
    locId = "mainmenu/fullRealInstantAction"
    egdCode = EGD_SIMULATION
    egdLowercaseName = get_name_by_gamemode(EGD_SIMULATION, false) // simulation
    gameTypeName = "realistic"
    matchingName = "simulation"
    crewSkillName = "fullreal"
    settingsName = "hard"
    clanReqOption = USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES
    clanDataEnding = "_sim"
    contentAllowedPresetOption = USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR
    contentAllowedPresetOptionDefVal = "historical"
    cdPresetValue = get_cd_preset(DIFFICULTY_HARDCORE)
    abbreviation = "clan/shortFullRealBattles"
    choiceType = ["AirSB", "TankSB", "ShipSB"]
    arcadeCountry = false
    hasRespawns = false
    needCheckTutorial = true
    isAvailable = function(gm = null) {
      return !hasFeature("SimulatorDifficulty") ? false :
        gm == GM_DOMINATION ? hasFeature("SimulatorDifficultyInRandomBattles") :
        true
    }
  }
})

g_difficulty.types.sort(function(a, b) {
  if (a.diffCode != b.diffCode)
    return a.diffCode > b.diffCode ? 1 : -1
  return 0
})


function get_battle_type_by_ediff(ediff) {
  if (ediff >= EDIFF_SHIFT * 2)
    return BATTLE_TYPES.SHIP
  if (ediff >= EDIFF_SHIFT)
    return BATTLE_TYPES.TANK
  return BATTLE_TYPES.AIR
}

function get_difficulty_by_ediff(ediff) {
  let diffCode = ediff % EDIFF_SHIFT
  foreach (difficulty in g_difficulty.types)
    if (difficulty.diffCode == diffCode)
      return difficulty
  return g_difficulty.ARCADE
}

return {
  g_difficulty
  get_difficulty_by_ediff
  get_battle_type_by_ediff
}