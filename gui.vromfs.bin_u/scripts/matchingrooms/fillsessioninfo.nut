from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")
let { USEROPT_TIME_LIMIT, USEROPT_LIMITED_FUEL, USEROPT_LIMITED_AMMO,
  USEROPT_VERSUS_RESPAWN, USEROPT_IS_BOTS_ALLOWED, USEROPT_ALLOW_EMPTY_TEAMS,
  USEROPT_CLUSTERS, USEROPT_DISABLE_AIRFIELDS, USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS,
  USEROPT_CONTENT_ALLOWED_PRESET
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { isInSessionRoom, isInSessionLobbyEventRoom, getSessionLobbyGameType, isUserMission, isUrlMissionByRoom
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getMissionTimeText, getWeatherLocName } = require("%scripts/missions/missionsText.nut")
let { getCustomDifficultyTooltipText } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { getSessionLobbyMissionNameLoc, getSessionLobbyTimeLimit,
  getRoomRequiredCrafts, getRoomMGameMode, getRoomTeamsCountries
} = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getSessionLobbyMissionName } = require("%scripts/missions/missionsUtilsModule.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")
let { fillCountriesList } = require("%scripts/matchingRooms/fillCountriesList.nut")

function clearInfo(scene) {
  foreach (name in ["session_creator", "session_mapName", "session_hasPassword",
                    "session_environment", "session_difficulty", "session_timeLimit",
                    "session_limits", "session_respawn", "session_takeoff",
                    "session_allowbots", "session_allow_empty_teams", "session_jip",
                    "limited_fuel", "limited_ammo", "session_teamLimit",
                    "session_battleRating", "session_cluster", "disable_airfields",
                    "session_laps", "session_winners", "session_can_shoot",
                    "spawn_ai_tank_on_tank_maps", "content_allowed_preset"]) {
    let obj = scene.findObject(name)
    if (checkObj(obj))
      obj.setValue("")
  }

  foreach (name in ["countries1", "vsText", "countries2"]) {
    let obj = scene.findObject(name)
    if (checkObj(obj))
      obj.show(false)
  }
}

local setTextToObj = function(obj, coloredText, value) {
  if (!checkObj(obj))
    return

  if (u.isBool(value))
    value = loc("options/{0}".subst(value ? "yes" : "no"))

  obj.setValue((!u.isEmpty(value))
    ? "{0}{1}".subst(coloredText, colorize("activeTextColor", value.tostring()))
    : "")
}

let setTextToObjByOption = function(objId, optionId, value) {
  let obj = this.scene.findObject(objId)
  if (!checkObj(obj))
    return

  let option = get_option(optionId)
  let displayValue = option.getValueLocText(value)
  setTextToObj(obj, "".concat(option.getTitle(), loc("ui/colon")), displayValue)
}

return function(scene, sessionInfo) {
  if (!checkObj(scene))
    return

  if (!sessionInfo)
    return clearInfo(scene)

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
  else if (isUrlMissionByRoom(sessionInfo)) {
    let url = getTblValue("missionURL", sessionInfo, "")
    let urlMission =  g_url_missions.findMissionByUrl(url)
    let missionName = urlMission ? urlMission.name : url
    setTextToObj(mapNameObj, "".concat(loc("urlMissions/sessionInfoHeader"), loc("ui/colon")), missionName)
  }
  else {
    let missionName = getSessionLobbyMissionNameLoc(sessionInfo)
    setTextToObj(mapNameObj, "".concat(loc("options/mp_mission"), loc("ui/colon")), missionName)
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
    let diff = getTblValue("difficulty", missionInfo)
    setTextToObj(difObj, "".concat(loc("multiplayer/difficultyShort"), loc("ui/colon")), loc($"options/{diff}"))
    local diffTooltip = ""
    if (diff == "custom") {
      let custDiff = getTblValue("custDifficulty", missionInfo, null)
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

  setTextToObjByOption("limited_fuel", USEROPT_LIMITED_FUEL, getTblValue("isLimitedFuel", missionInfo))
  setTextToObjByOption("limited_ammo", USEROPT_LIMITED_AMMO, getTblValue("isLimitedAmmo", missionInfo))

  setTextToObjByOption("session_respawn", USEROPT_VERSUS_RESPAWN, getTblValue("maxRespawns", missionInfo, -1))

  let tObj = scene.findObject("session_takeoff")
  setTextToObj(tObj, "".concat(loc("options/optional_takeoff"), loc("ui/colon")),
    missionInfo?.optionalTakeOff ?? false)

  setTextToObjByOption("session_allowbots", USEROPT_IS_BOTS_ALLOWED,
               (gt & GT_RACE) ? null : getTblValue("isBotsAllowed", missionInfo))

  setTextToObjByOption("session_allow_empty_teams", USEROPT_ALLOW_EMPTY_TEAMS, missionInfo?.allowEmptyTeams)

  bObj = scene.findObject("session_jip")
  setTextToObj(bObj, "".concat(loc("options/allow_jip"), loc("ui/colon")),
    sessionInfo?.allowJIP ?? true)

  setTextToObjByOption("session_cluster", USEROPT_CLUSTERS, getTblValue("cluster", sessionInfo))

  setTextToObjByOption("disable_airfields", USEROPT_DISABLE_AIRFIELDS, getTblValue("disableAirfields", missionInfo))

  setTextToObjByOption("spawn_ai_tank_on_tank_maps", USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, getTblValue("spawnAiTankOnTankMaps", missionInfo))

  setTextToObjByOption("content_allowed_preset", USEROPT_CONTENT_ALLOWED_PRESET, missionInfo?.allowedTagsPreset)

  let slObj = scene.findObject("slotbar_override")
  if (checkObj(slObj)) {
    local slotOverrideText = ""
    if (isSlotbarOverrided(getSessionLobbyMissionName(true, sessionInfo)))
      slotOverrideText = colorize("userlogColoredText", loc("multiplayer/slotbarOverrided"))

    slObj.setValue(slotOverrideText)
  }
}