import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/events/eventsManager.nut" import events
from "%scripts/events/eventTeamsInfo.nut" import getAlowedCrafts, getForbiddenCrafts, getRequiredCrafts
from "%scripts/slotbar/slotbarOverride.nut" import isSlotbarOverrided
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/teams.nut" import g_team
from "%scripts/options/optionsExtNames.nut" import USEROPT_TIME_LIMIT, USEROPT_LIMITED_FUEL, USEROPT_LIMITED_AMMO, USEROPT_VERSUS_RESPAWN, USEROPT_IS_BOTS_ALLOWED, USEROPT_ALLOW_EMPTY_TEAMS, USEROPT_CLUSTERS
  , USEROPT_DISABLE_AIRFIELDS, USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, USEROPT_CONTENT_ALLOWED_PRESET
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/matchingRooms/sessionLobbyState.nut" import isInSessionRoom, isInSessionLobbyEventRoom, getSessionLobbyGameType, isUserMission, isUrlMissionByRoom
from "%scripts/missions/missionsText.nut" import getMissionTimeText, getWeatherLocName
from "%scripts/matchingRooms/matchingGameModesUtils.nut" import getCustomDifficultyOptions
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import getSessionLobbyMissionNameText, getSessionLobbyTimeLimit, getRoomRequiredCrafts, getRoomMGameMode, getRoomTeamsCountries
  , getRoomTeamData
from "%scripts/missions/missionsUtilsModule.nut" import getSessionLobbyMissionName
from "%scripts/options/optionsExt.nut" import get_option
from "%scripts/matchingRooms/fillCountriesList.nut" import fillCountriesList
from "guiOptions" import get_cd_preset, set_cd_preset
from "%globalScripts/gameTypeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%globalScripts/difficultyConsts.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%appGlobals/missions/respawnCountModes.nut" import RESPAWN_COUNT_MODE

let unitTypes = require("%scripts/unit/unitTypesList.nut")

const infoRowIds = [
  "session_mapName"
  "session_creator"
  "session_difficulty"
  "session_hasPassword"
  "session_teamLimit"
  "session_battleRating"
  "session_environment"
  "session_timeLimit"
  "session_respawn"
  "session_takeoff"
  "limited_fuel"
  "limited_ammo"
  "session_allow_empty_teams"
  "session_jip"
  "session_cluster"
  "session_allowbots"
  "spawn_ai_tank_on_tank_maps"
  "disable_airfields"
  "session_laps"
  "session_winners"
  "session_can_shoot"
  "content_allowed_preset"
]

function createInfoRows(scene) {
  let rowsObj = scene.findObject("session_info_rows")
  if (!rowsObj?.isValid() || rowsObj.childrenCount() > 0)
    return

  let markup = handyman.renderCached("%gui/mpLobby/sessionInfoRows.tpl",
    { rows = infoRowIds.map(@(id) { id }) })
  scene.getScene().replaceContentFromText(rowsObj, markup, markup.len(), null)
}

function clearInfo(scene) {
  showObjById("session_info_list", false, scene)
  showObjById("session_vehicles", false, scene)
}

function setTextToObj(obj, title, value) {
  if (!obj?.isValid())
    return

  if (u.isBool(value))
    value = loc("options/{0}".subst(value ? "yes" : "no"))

  let isVisible = !u.isEmpty(value)
  obj.show(isVisible)
  if (!isVisible)
    return

  obj.findObject("title").setValue(title)
  obj.findObject("value").setValue(value.tostring())
}

let setTextToObjByOption = function(objId, optionId, value) {
  let obj = this.scene.findObject(objId)
  if (!checkObj(obj))
    return

  let option = get_option(optionId)
  let displayValue = option.getValueLocText(value)
  setTextToObj(obj, "".concat(option.getTitle(), loc("ui/colon")), displayValue)
}

function getCustomDifficultyTooltipText(custDifficulty) {
  let wasDiff = get_cd_preset(DIFFICULTY_CUSTOM)
  set_cd_preset(custDifficulty)

  local text = ""
  let options = getCustomDifficultyOptions()
  foreach (o in options) {
    let opt = get_option(o[0])
    let valueText = opt.items ?
      loc(opt.items[opt.value]) :
      loc(opt.value ? "options/yes" : "options/no")
    text = "".concat(text, (text != "") ? "\n" : "", loc($"options/{opt.id}"), loc("ui/colon"), colorize("userlogColoredText", valueText))
  }

  set_cd_preset(wasDiff)
  return text
}

function getRuleBrText(rule) {
  return loc("ui/parentheses", { text = events.generateEventRule({ mranks = rule?.mranks }, true) })
}

function getRuleSummaryIcon(rule) {
  if ("class" not in rule || "name" in rule || "type" in rule || "ranks" in rule)
    return null
  let { fontIcon } = unitTypes.getByName(rule["class"], false)
  return fontIcon != "" ? fontIcon : null
}

function appendRulesRow(rows, locId, rules) {
  let rulesText = events.getRulesText(rules, ", ")
  if (rulesText != "")
    rows.append({ icon = null, text = " ".concat(loc(locId), rulesText) })
}

function getTeamVehiclesView(team, teamData) {
  let rows = []
  foreach (rule in getAlowedCrafts(teamData)) {
    let icon = getRuleSummaryIcon(rule)
    rows.append({
      icon
      text = icon != null ? getRuleBrText(rule) : events.generateEventRule(rule, true)
    })
  }
  appendRulesRow(rows, "events/forbidden_crafts", getForbiddenCrafts(teamData))
  appendRulesRow(rows, "events/required_crafts", getRequiredCrafts(teamData))
  if (rows.len() == 0)
    rows.append({ icon = null, text = loc("events/all_units_allowed") })

  return {
    teamName = team.getShortName()
    rows
  }
}

function fillSessionVehicles(scene, sessionInfo) {
  let blockObj = scene.findObject("session_vehicles")
  if (!blockObj?.isValid())
    return

  let isVisible = !isSlotbarOverrided(getSessionLobbyMissionName(true, sessionInfo))
  blockObj.show(isVisible)
  if (!isVisible)
    return

  let guiScene = scene.getScene()
  local hasShownTeam = false
  foreach (team in [g_team.A, g_team.B]) {
    let teamObj = blockObj.findObject($"session_vehicles_{team.id}")
    let teamData = getRoomTeamData(team.code, sessionInfo)
    let isPlayable = events.isTeamDataPlayable(teamData)
    teamObj.show(isPlayable)
    if (!isPlayable)
      continue

    teamObj.hasSeparator = hasShownTeam ? "yes" : "no"
    hasShownTeam = true
    let view = getTeamVehiclesView(team, teamData)
    let markup = handyman.renderCached("%gui/mpLobby/sessionTeamVehicles.tpl", view)
    guiScene.replaceContentFromText(teamObj, markup, markup.len(), null)
  }
}

return function(scene, sessionInfo) {
  if (!checkObj(scene))
    return

  if (!sessionInfo)
    return clearInfo(scene)

  showObjById("session_info_list", true, scene)
  createInfoRows(scene)

  let gt = getSessionLobbyGameType(sessionInfo)
  let missionInfo = ("mission" in sessionInfo) ? sessionInfo.mission : {}
  let isEventRoom = isInSessionRoom.get() && isInSessionLobbyEventRoom.get()

  let nameObj = scene.findObject("session_creator")
  let creatorName = getPlayerName(sessionInfo?.creator ?? "")
  setTextToObj(nameObj, "".concat(loc("multiplayer/game_host"), loc("ui/colon")), creatorName)

  let teams = getRoomTeamsCountries(sessionInfo)
  let isEqual = teams.len() == 1 || u.isEqual(teams[0], teams[1])
  let cObj1 = scene.findObject("countries1")
  let cObj2 = scene.findObject("countries2")
  if (checkObj(cObj1)) {
    cObj1.show(true)
    fillCountriesList(cObj1, teams[0])
    cObj2.show(!isEqual)
    if (!isEqual)
      fillCountriesList(cObj2, teams[1])
  }
  let vsObj = scene.findObject("vsText")
  if (checkObj(vsObj))
    vsObj.show(!isEqual)

  let mapNameObj = scene.findObject("session_mapName")
  if (isUserMission(sessionInfo))
    setTextToObj(mapNameObj, "".concat(loc("options/mp_user_mission"), loc("ui/colon")), sessionInfo?.userMissionName)
  else {
    let missionName = getSessionLobbyMissionNameText(sessionInfo)
    let titleText = isUrlMissionByRoom(sessionInfo) ? loc("urlMissions/sessionInfoHeader") : loc("options/mp_mission")
    setTextToObj(mapNameObj, "".concat(titleText, loc("ui/colon")), missionName)
  }

  let pasObj = scene.findObject("session_hasPassword")
  setTextToObj(pasObj, "".concat(loc("options/session_password"), loc("ui/colon")),
    isEventRoom ? null : sessionInfo?.hasPassword ?? false)

  let tlObj = scene.findObject("session_teamLimit")
  let rangeData = events.getPlayersRangeTextData(getRoomMGameMode(sessionInfo))
  setTextToObj(tlObj, rangeData.label,
               isEventRoom && rangeData.isValid ? rangeData.value : null)

  let craftsObj = scene.findObject("session_battleRating")
  let reqUnits = getRoomRequiredCrafts(Team.A, sessionInfo)
  setTextToObj(craftsObj, loc("events/required_crafts"), events.getRulesText(reqUnits))

  let envObj = scene.findObject("session_environment")
  let envTexts = []
  if ("weather" in missionInfo)
    envTexts.append(getWeatherLocName(missionInfo.weather))
  if ("environment" in missionInfo)
    envTexts.append(getMissionTimeText(missionInfo.environment))
  setTextToObj(envObj, "".concat(loc("sm_conditions"), loc("ui/colon")), ", ".join(envTexts, true))

  let difObj = scene.findObject("session_difficulty")
  if (checkObj(difObj)) {
    let diff = missionInfo?.difficulty
    setTextToObj(difObj, "".concat(loc("multiplayer/difficultyShort"), loc("ui/colon")), loc($"options/{diff}"))
    local diffTooltip = ""
    if (diff == "custom") {
      let custDiff = missionInfo?.custDifficulty
      if (custDiff)
        diffTooltip = getCustomDifficultyTooltipText(custDiff)
    }
    difObj.tooltip = diffTooltip
  }


  local bObj = scene.findObject("session_laps")
  setTextToObj(bObj, "".concat(loc("options/race_laps"), loc("ui/colon")),
    (gt & GT_RACE) ? missionInfo?.raceLaps : null)
  bObj = scene.findObject("session_winners")
  setTextToObj(bObj, "".concat(loc("options/race_winners"), loc("ui/colon")),
    (gt & GT_RACE) ? missionInfo?.raceWinners : null)
  bObj = scene.findObject("session_can_shoot")
  setTextToObj(bObj, "".concat(loc("options/race_can_shoot"), loc("ui/colon")),
    (gt & GT_RACE) ? !(missionInfo?.raceForceCannotShoot ?? false) : null)

  setTextToObjByOption("session_timeLimit", USEROPT_TIME_LIMIT, getSessionLobbyTimeLimit(sessionInfo))

  setTextToObjByOption("limited_fuel", USEROPT_LIMITED_FUEL, missionInfo?.isLimitedFuel)
  setTextToObjByOption("limited_ammo", USEROPT_LIMITED_AMMO, missionInfo?.isLimitedAmmo)

  setTextToObjByOption("session_respawn", USEROPT_VERSUS_RESPAWN,
    (missionInfo?.maxRespawns ?? RESPAWN_COUNT_MODE.ONE_FOR_EACH_CREW))

  let tObj = scene.findObject("session_takeoff")
  setTextToObj(tObj, "".concat(loc("options/optional_takeoff"), loc("ui/colon")),
    missionInfo?.optionalTakeOff ?? false)

  setTextToObjByOption("session_allowbots", USEROPT_IS_BOTS_ALLOWED,
               (gt & GT_RACE) ? null : missionInfo?.isBotsAllowed)

  setTextToObjByOption("session_allow_empty_teams", USEROPT_ALLOW_EMPTY_TEAMS, missionInfo?.allowEmptyTeams)

  bObj = scene.findObject("session_jip")
  setTextToObj(bObj, "".concat(loc("options/allow_jip"), loc("ui/colon")),
    sessionInfo?.allowJIP ?? true)

  setTextToObjByOption("session_cluster", USEROPT_CLUSTERS, sessionInfo?.cluster)

  setTextToObjByOption("disable_airfields", USEROPT_DISABLE_AIRFIELDS, missionInfo?.disableAirfields)

  setTextToObjByOption("spawn_ai_tank_on_tank_maps", USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, missionInfo?.spawnAiTankOnTankMaps)

  setTextToObjByOption("content_allowed_preset", USEROPT_CONTENT_ALLOWED_PRESET, missionInfo?.allowedTagsPreset)

  let slObj = scene.findObject("slotbar_override")
  if (checkObj(slObj)) {
    local slotOverrideText = ""
    if (isSlotbarOverrided(getSessionLobbyMissionName(true, sessionInfo)))
      slotOverrideText = colorize("userlogColoredText", loc("multiplayer/slotbarOverrided"))

    slObj.setValue(slotOverrideText)
  }

  fillSessionVehicles(scene, sessionInfo)
}