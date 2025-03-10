from "%scripts/dagui_natives.nut" import get_player_army_for_hud
from "%scripts/dagui_library.nut" import *

let { getLocIdsArray } = require("%scripts/langUtils/localization.nut")
let DataBlock = require("DataBlock")
let { get_current_mission_desc } = require("guiMission")
let { g_team } = require("%scripts/teams.nut")
let { get_game_mode, get_game_type } = require("mission")
let { isStringInteger, isStringFloat, capitalize } = require("%sqstd/string.nut")
let { format } = require("string")

let customWeatherLocIds = {
  thin_clouds = "options/weatherthinclouds"
  thunder = "options/weatherstorm"
}

let getWeatherLocName = @(weather)
  loc(customWeatherLocIds?[weather] ?? $"options/weather{weather}")

function getMissionTimeText(missionTime) {
  if (isStringInteger(missionTime))
    return format("%d:00", missionTime.tointeger())
  if (isStringFloat(missionTime))
    missionTime = missionTime.replace(".", ":")
  return loc($"options/time{capitalize(missionTime)}")
}

let getMissionLocName = @(config, key = "locId") "".join(getLocIdsArray(config?[key])
  .map(@(locId) locId.len() == 1 ? locId : loc(locId)))

function getCombineLocNameMission(missionInfo) {
  let misInfoName = missionInfo?.name ?? ""
  local locName = ""
  if ((missionInfo?["locNameTeamA"].len() ?? 0) > 0)
    locName = getMissionLocName(missionInfo, "locNameTeamA")
  else if ((missionInfo?.locName.len() ?? 0) > 0)
    locName = getMissionLocName(missionInfo, "locName")
  else
    locName = loc($"missions/{misInfoName}", "")

  if (locName == "") {
    let misInfoPostfix = missionInfo?.postfix ?? ""
    if (misInfoPostfix != "" && misInfoName.indexof(misInfoPostfix)) {
      let name = misInfoName.slice(0, misInfoName.indexof(misInfoPostfix))
      locName = "".concat("[", loc($"missions/{misInfoPostfix}"), "] ", loc($"missions/{name}"))
    }
  }

  
  if (locName == "")
    locName = $"missions/{misInfoName}"
  return locName
}

function locCurrentMissionName(needComment = true) {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  let teamId = g_team.getTeamByCode(get_player_army_for_hud()).id
  let locNameByTeamParamName = $"locNameTeam{teamId}"
  local ret = ""

  if ((misBlk?[locNameByTeamParamName].len() ?? 0) > 0)
    ret = getMissionLocName(misBlk, locNameByTeamParamName)
  else if ((misBlk?.locName.len() ?? 0) > 0)
    ret = getMissionLocName(misBlk, "locName")
  else if ((misBlk?.loc_name ?? "") != "")
    ret = loc($"missions/{misBlk.loc_name}", "")
  if (ret == "")
    ret = getCombineLocNameMission(misBlk)
  if (needComment && (get_game_type() & GT_VERSUS)) {
    if (misBlk?.maxRespawns == 1)
      ret = "".concat(ret, " ", loc("template/noRespawns"))
    else if ((misBlk?.maxRespawns ?? 1) > 1)
      ret = "".concat(ret, " ",
        loc("template/limitedRespawns/num/plural", { num = misBlk.maxRespawns }))
  }
  return ret
}

function buildRewardText(name, reward, highlighted = false, _coloredIcon = false, additionalReward = false) {
  local rewText = reward.tostring()
  if (rewText != "") {
    if (highlighted)
      rewText = colorize("highlightedTextColor", additionalReward ? $"+({rewText})" : rewText)
    rewText = "".concat(name, name != "" ? loc("ui/colon") : "", rewText)
  }
  return rewText
}

function getMissionName(missionId, config, locNameKey = "locName") {
  let locNameValue = config?[locNameKey] ?? ""
  if (locNameValue != "")
    return getMissionLocName(config, locNameKey)

  return loc($"missions/{missionId}")
}

function loc_current_mission_desc() {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  let teamId = g_team.getTeamByCode(get_player_army_for_hud()).id
  let locDecsByTeamParamName = $"locDescTeam{teamId}"

  local locDesc = ""
  if ((misBlk?[locDecsByTeamParamName].len() ?? 0) > 0)
    locDesc = getMissionLocName(misBlk, locDecsByTeamParamName)
  else if ((misBlk?.locDesc.len() ?? 0) > 0)
    locDesc = getMissionLocName(misBlk, "locDesc")
  else {
    local missionLocName = misBlk.name
    if ("loc_name" in misBlk && misBlk.loc_name != "")
      missionLocName = misBlk.loc_name
    locDesc = loc($"missions/{missionLocName}/desc", "")
  }
  if (get_game_type() & GT_VERSUS) {
    if (misBlk.maxRespawns == 1) {
      if (get_game_mode() != GM_DOMINATION)
        locDesc = "".concat(locDesc, "\n\n", loc("template/noRespawns/desc"))
    }
    else if ((misBlk.maxRespawns != null) && (misBlk.maxRespawns > 1))
      locDesc = "".concat(locDesc, "\n\n", loc("template/limitedRespawns/desc"))
  }
  return locDesc
}

return {
  getWeatherLocName
  getMissionTimeText
  locCurrentMissionName
  buildRewardText
  getMissionLocName
  getCombineLocNameMission
  getMissionName
  loc_current_mission_desc
}