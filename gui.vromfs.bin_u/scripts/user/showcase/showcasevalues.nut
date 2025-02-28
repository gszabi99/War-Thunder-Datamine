from "%scripts/dagui_library.nut" import *

let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { measureType } = require("%scripts/measureType.nut")
let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

let defaultShowcaseType = "air_arcade"
let diffNames = ["arcade", "historical", "simulation"]
let gamemodesNoAiStats = ["tank_arcade", "tank_realistic", "tank_simulation", "test_ship_arcade", "test_ship_realistic"]
let selectUnitWndFilters = {}

function getStatsValue(params, value, scorePeriod) {
  let gameType = params?.showcaseType ?? defaultShowcaseType
  let valFromTerseInfo = params.terseInfo?.showcase[gameType][value.valueId]
  if (valFromTerseInfo != null)
    return max(0, valFromTerseInfo)

  let stats = params.stats?.leaderboard[gameType][scorePeriod]
  let val = stats?[value.valueId][scorePeriod] ?? 0
  return val == -1 ? 0 : val
}

function getUnitNameFromTerseInfo(terseInfo, unitIdx) {
  if (terseInfo.schType == "favorite_unit")
    return terseInfo?.showcase.unit ?? ""

  if (terseInfo.schType == "unit_collector")
    return terseInfo?.showcase.units[unitIdx] ?? ""
  return ""
}

function getUnitFromTerseInfo(terseInfo, unitIdx = 0) {
  let unitName = getUnitNameFromTerseInfo(terseInfo, unitIdx)
  return unitName != "" ? getAircraftByName(unitName) : null
}

function getAtomicAceValue(terseInfo) {
  return terseInfo?.showcase.atomic_ace__counter ?? 0
}

function getPeacefulAtomValue(terseInfo) {
  return terseInfo?.showcase.peacemaker__counter ?? 0
}

function getPosInLeaderboard(params, value, scorePeriod) {
  let gameType = params?.showcaseType ?? defaultShowcaseType
  let stats = params.stats?.leaderboard[gameType][scorePeriod]
  let stat = stats?[value.valueId]
  if (stat == null)
    return 0

  foreach (lbCategory in ::leaderboards_list)
    if (lbCategory.field == value.valueId) {
      let lbVal = stat.idx < 0 ? -1 : stat.idx + 1
      let text = lbCategory.getItemCell(lbVal, null, false, lbDataType.PLACE)?.text ?? "0"
      return to_integer_safe(text, 0, false)
    }

  return 0
}

function findUnitStats(stats, unitName, diff) {
  let statArr = stats?[diff].total
  return statArr?.findvalue(@(v) v.name == unitName)
}

function getUnitStat(unitName, value, params) {
  let unitStats = params?.unitStats ?? findUnitStats(params?.stats.userstat, unitName, params.terseInfo.showcase?.difficulty ?? diffNames[0])
  return unitStats?[value.valueId] ?? 0
}

let showcaseValues = {
  battles = {
    type = "stat"
    icon = "lb_each_player_session"
    locId = "multiplayer/each_player_session"
    valueId = "each_player_session"
  },
  victories = {
    type = "stat"
    icon = "lb_each_player_victories"
    locId = "multiplayer/each_player_victories"
    valueId = "each_player_victories"
  },
  respawns = {
    type = "stat"
    icon = "lb_flyouts"
    locId = "multiplayer/flyouts"
    valueId = "flyouts"
  },
  playerVehicleDestroys = {
    type = "stat"
    icon = "lb_average_active_kills"
    locId = "multiplayer/lb_kills_player"
    valueId = "kills_player_or_bot"
  },
  aiVehicleDestroys = {
    type = "stat"
    icon = "lb_average_script_kills"
    locId = "multiplayer/lb_kills_ai"
    valueId = "kills_ai"
    canShow = @(params) !gamemodesNoAiStats.contains(params.showcaseType)
  },
  totalScore = {
    type = "stat"
    icon = "lb_total_score"
    locId = "debriefing/totalscore"
    valueId = "score"
  },
  kill_by_spawns = {
    type = "stat"
    icon = "lb_average_active_kills_by_spawn"
    locId = "stats/average_active_kills_by_deaths"
    valueId = "efficiency_vs_players"
  },
  ai_kill_by_spawns = {
    type = "stat"
    icon = "lb_average_script_kills_by_spawn"
    locId = "stats/average_script_kills_by_deaths"
    valueId = "efficiency_vs_ai"
    canShow = @(params) !gamemodesNoAiStats.contains(params.showcaseType)
  },
  average_score = {
    type = "stat"
    icon = "lb_average_score"
    locId = "multiplayer/averageScore"
    valueId = "average_score"
  },
  pvpRating = {
    type = "textStat"
    locId = "multiplayer/pvp_ratio_short"
    valueId = "pvp_ratio"
    getValue = function(params, val) {
      let v = getStatsValue(params, val, "value_inhistory")
      return v == 0
        ? loc("leaderboards/notAvailable")
        : $"{decimalFormat(v)}"
    }
    getTooltip = function(params, val) {
      let v = getStatsValue(params, val, "value_inhistory")
      return v == 0
        ? "multiplayer/victories_battles_na_tooltip"
        : "multiplayer/pvp_ratio"
    }
  },
  vehicle_hangar = {
    type = "textStat"
    locId = "conditions/char_aircrafts_count"
    valueId = ""
    getValue = function (params, _val) {
      local vehiclesCount = 0
      if (params.terseInfo.showcase?.counts)
        foreach (country in params.terseInfo.showcase.counts)
          vehiclesCount += country
      return $"{vehiclesCount}"
    }
  },
  collectionUnitFlags = {
    type = "flags"
    getValue = function (params, _val) {
      let flags = []
      let countByCountries = params.terseInfo.showcase?.counts
      foreach (country in shopCountriesList) {
        let count = countByCountries?[country]
        flags.append({
          flag = getCountryFlagImg(country),
          value = count ? to_integer_safe(count) : "-"
        })
      }
      return flags
    }
  },
  placeInLeaderboard = {
    type = "textStat"
    locId = "multiplayer/place_in_leaderboard"
    valueId = "pvp_ratio"
    getValue = function(params, val) {
      let pos = getPosInLeaderboard(params, val, "value_inhistory")
      return pos == 0 ? loc("leaderboards/notAvailable") : decimalFormat(pos)
    }
    getTooltip = function(params, val) {
      let pos = getPosInLeaderboard(params, val, "value_inhistory")
      return pos == 0
        ? "multiplayer/victories_battles_na_tooltip"
        : "multiplayer/place_in_leaderboard_desc"
    }
  },
  atomic_ace = {
    type = "stat_big"
    icon = "!#ui/gameuiskin#atomic_ace_icon.svg"
    valueId = null
    getText = @(params, _val) loc("showcase/nuclear_bombs_dropped", {num = getAtomicAceValue(params?.terseInfo)})
    getValue = @(params, _val) getAtomicAceValue(params?.terseInfo)
  },
  peaceful_atom = {
    type = "stat_big"
    icon = "!#ui/gameuiskin#peacemaker_icon.svg"
    valueId = null
    getText = @(params, _val) loc("showcase/nuclear_carriers_shotdown", {num = getPeacefulAtomValue(params?.terseInfo)})
    getValue = @(params, _val) getPeacefulAtomValue(params?.terseInfo)
  },
  favUnit = {
    type = "unitImage"
    width = "0.9@accountHeaderWidth"
    height = "@favoriteUnitImageHeight"
    getMargin = @(scale) $"{scale}*13@sf/@pf, 0"
    getImage = function (params, _unitIdx) {
      let unit = getUnitFromTerseInfo(params.terseInfo)
      return unit ? getUnitTooltipImage(unit) : null
    }
    valueId = null
  },
  collection_unit = {
    type = "unitImage"
    width = "0.45@accountHeaderWidth"
    height = "160@sf/@pf"
    getMargin = @(scale) $"{scale}@showcaseLinePadding"
    getImage = function (params, unitIdx) {
      let unit = getUnitFromTerseInfo(params.terseInfo, unitIdx)
      return unit ? getUnitTooltipImage(unit) : null
    }
    valueId = null
  },
  unit_victories = {
    type = "stat", icon = "lb_each_player_victories",
    getText = @(params, val) loc("stats/victories", {num = getUnitStat(params?.unit.name, val, params)})
    valueId = "victories", getValue = @(params, val) getUnitStat(params?.unit.name, val, params)
  }
  unit_battles = {
    type = "stat", icon = "lb_each_player_session",
    getText = @(params, val) loc("stats/battles", {num = getUnitStat(params?.unit.name, val, params)})
    valueId = "sessions", getValue = @(params, val) getUnitStat(params?.unit.name, val, params)
  }
  unit_respawns = {
    type = "stat", icon = "lb_flyouts",
    getText = @(params, val) loc("stats/flyouts", {num = getUnitStat(params?.unit.name, val, params)})
    valueId = "flyouts", getValue = @(params, val) getUnitStat(params?.unit.name, val, params)
  }
  unit_kills = {
    type = "stat", icon = "lb_average_script_kills",
    valueId = "kills",
    getText = @(params, val) loc("stats/targetsDestroyed", {num = getUnitStat(params?.unit.name, val, params)})
    getValue = function(params, _val) {
      let unitStats = params?.unitStats ?? findUnitStats(params?.stats.userstat, params?.unit.name, params?.diff)
      if (!unitStats)
        return 0
      return unitStats.naval_kills + unitStats.ground_kills + unitStats.air_kills
    }
  }
  unit_deaths = {
    type = "stat", icon = "lb_deaths",
    getText = @(params, val) loc("stats/deaths", {num = getUnitStat(params?.unit.name, val, params)})
    valueId = "deaths", getValue = @(params, val) getUnitStat(params?.unit.name, val, params)
  }
  diff_label = {
    type = "label",
    getText = @(params, _val) loc($"difficulty{diffNames.indexof(params.terseInfo.showcase?.difficulty) ?? 0}")
    valueId = "",
    getComboBox = function(params, _val) {
      let data = {width = "1@accountHeaderWidth - 50@sf/@pf", onSelect = "onSelectFavUnitDiff"}
      let values = []
      let currDiffIdx = diffNames.indexof(params.terseInfo.showcase?.difficulty) ?? 0
      foreach (idx, _diff in diffNames)
        values.append({text = loc($"difficulty{idx}"), selected = idx == currDiffIdx})
      data.options <- values
      return data
    }
  }
  averageRelativePosition = {
    type = "stat"
    icon = "lb_average_relative_position"
    locId = "showcase/averageRelativePosition"
    valueId = "avg_rel_position"
    getValue = @(params, val) measureType.PERCENT_FLOAT.getMeasureUnitsText(getStatsValue(params, val, params.scorePeriod) * 0.001)
  }
}

return {
  showcaseValues
  defaultShowcaseType
  getStatsValue
  getUnitFromTerseInfo
  diffNames
  findUnitStats
  selectUnitWndFilters
}