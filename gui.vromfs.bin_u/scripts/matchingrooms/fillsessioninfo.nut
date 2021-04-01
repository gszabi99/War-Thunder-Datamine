local platformModule = require("scripts/clientState/platform.nut")
local { isSlotbarOverrided } = require("scripts/slotbar/slotbarOverride.nut")

local function clearInfo(scene)
{
  foreach (name in ["session_creator", "session_mapName", "session_hasPassword",
                    "session_environment", "session_difficulty", "session_timeLimit",
                    "session_limits", "session_respawn", "session_takeoff",
                    "session_allowbots", "session_botsranks", "session_jip",
                    "limited_fuel", "limited_ammo", "session_teamLimit",
                    "session_battleRating", "session_cluster", "disable_airfields",
                    "session_laps", "session_winners", "session_can_shoot",
                    "spawn_ai_tank_on_tank_maps", "content_allowed_preset"])
  {
    local obj = scene.findObject(name)
    if (::check_obj(obj))
      obj.setValue("")
  }

  foreach (name in ["countries1", "vsText", "countries2"])
  {
    local obj = scene.findObject(name)
    if (::check_obj(obj))
      obj.show(false)
  }
}

local setTextToObj = function(obj, coloredText, value)
{
  if (!::check_obj(obj))
    return

  if (::u.isBool(value))
    value = ::loc("options/{0}".subst(value ? "yes" : "no"))

  obj.setValue((!::u.isEmpty(value))
    ? "{0}{1}".subst(coloredText, ::colorize("activeTextColor", value.tostring()))
    : "")
}

local setTextToObjByOption = function(objId, optionId, value)
{
  local obj = scene.findObject(objId)
  if (!::check_obj(obj))
    return

  local option = ::get_option(optionId)
  local displayValue = option.getValueLocText(value)
  setTextToObj(obj, option.getTitle() + ::loc("ui/colon"), displayValue)
}

return function(scene, sessionInfo)
{
  if (!::check_obj(scene))
    return

  if (!sessionInfo)
    return clearInfo(scene)

  local gt = ::SessionLobby.getGameType(sessionInfo)
  local missionInfo = ("mission" in sessionInfo)? sessionInfo.mission : {}
  local isEventRoom = ::SessionLobby.isInRoom() && ::SessionLobby.isEventRoom

  local nameObj = scene.findObject("session_creator")
  local creatorName = platformModule.getPlayerName(sessionInfo?.creator ?? "")
  setTextToObj(nameObj, ::loc("multiplayer/game_host") + ::loc("ui/colon"), creatorName)

  local teams = ::SessionLobby.getTeamsCountries(sessionInfo)
  local isEqual = teams.len() == 1 || ::u.isEqual(teams[0], teams[1])
  local cObj1 = scene.findObject("countries1")
  local cObj2 = scene.findObject("countries2")
  if (::check_obj(cObj1))
  {
    cObj1.show(true)
    fillCountriesList(cObj1, teams[0])
    cObj2.show(!isEqual)
    if (!isEqual)
      fillCountriesList(cObj2, teams[1])
  }
  local vsObj = scene.findObject("vsText")
  if (::check_obj(vsObj))
    vsObj.show(!isEqual)

  local mapNameObj = scene.findObject("session_mapName")
  if (::SessionLobby.isUserMission(sessionInfo))
    setTextToObj(mapNameObj, ::loc("options/mp_user_mission") + ::loc("ui/colon"), ::getTblValue("userMissionName", sessionInfo))
  else if (::SessionLobby.isUrlMission(sessionInfo))
  {
    local url = ::getTblValue("missionURL", sessionInfo, "")
    local urlMission =  ::g_url_missions.findMissionByUrl(url)
    local missionName = urlMission ? urlMission.name : url
    setTextToObj(mapNameObj, ::loc("urlMissions/sessionInfoHeader") + ::loc("ui/colon"), missionName)
  }
  else
  {
    local missionName = ::SessionLobby.getMissionNameLoc(sessionInfo)
    setTextToObj(mapNameObj, "".concat(::loc("options/mp_mission"), ::loc("ui/colon")), missionName)
  }

  local pasObj = scene.findObject("session_hasPassword")
  setTextToObj(pasObj, ::loc("options/session_password") + ::loc("ui/colon"),
               isEventRoom ? null : ::getTblValue("hasPassword", sessionInfo, false))

  local tlObj = scene.findObject("session_teamLimit")
  local rangeData = ::events.getPlayersRangeTextData(::SessionLobby.getMGameMode(sessionInfo))
  setTextToObj(tlObj, rangeData.label,
               isEventRoom && rangeData.isValid ? rangeData.value : null)

  local craftsObj = scene.findObject("session_battleRating")
  local reqUnits = ::SessionLobby.getRequiredCrafts(Team.A, sessionInfo)
  setTextToObj(craftsObj, ::loc("events/required_crafts"), ::events.getRulesText(reqUnits))

  local envObj = scene.findObject("session_environment")
  local envTexts = []
  if ("weather" in missionInfo)
    envTexts.append(::loc("options/weather" + missionInfo.weather))
  if ("environment" in missionInfo)
    envTexts.append(::get_mission_time_text(missionInfo.environment))
  setTextToObj(envObj, ::loc("sm_conditions") + ::loc("ui/colon"), ::g_string.implode(envTexts, ", "))

  local difObj = scene.findObject("session_difficulty")
  if (::check_obj(difObj))
  {
    local diff = ::getTblValue("difficulty", missionInfo)
    setTextToObj(difObj, ::loc("multiplayer/difficultyShort") + ::loc("ui/colon"), ::loc("options/" + diff))
    local diffTooltip = ""
    if (diff=="custom")
    {
      local custDiff = ::getTblValue("custDifficulty", missionInfo, null)
      if (custDiff)
        diffTooltip = ::get_custom_difficulty_tooltip_text(custDiff)
    }
    difObj.tooltip = diffTooltip
  }


  local bObj = scene.findObject("session_laps")
  setTextToObj(bObj, ::loc("options/race_laps") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? ::getTblValue("raceLaps", missionInfo) : null)
  bObj = scene.findObject("session_winners")
  setTextToObj(bObj, ::loc("options/race_winners") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? ::getTblValue("raceWinners", missionInfo) : null)
  bObj = scene.findObject("session_can_shoot")
  setTextToObj(bObj, ::loc("options/race_can_shoot") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? !::getTblValue("raceForceCannotShoot", missionInfo, false) : null)

  setTextToObjByOption("session_timeLimit", ::USEROPT_TIME_LIMIT, ::SessionLobby.getTimeLimit(sessionInfo))

  setTextToObjByOption("limited_fuel", ::USEROPT_LIMITED_FUEL, ::getTblValue("isLimitedFuel", missionInfo))
  setTextToObjByOption("limited_ammo", ::USEROPT_LIMITED_AMMO, ::getTblValue("isLimitedAmmo", missionInfo))

  setTextToObjByOption("session_respawn", ::USEROPT_VERSUS_RESPAWN, ::getTblValue("maxRespawns", missionInfo, -1))

  local tObj = scene.findObject("session_takeoff")
  setTextToObj(tObj, ::loc("options/optional_takeoff") + ::loc("ui/colon"),
               ::getTblValue("optionalTakeOff", missionInfo, false))

  setTextToObjByOption("session_allowbots", ::USEROPT_IS_BOTS_ALLOWED,
               (gt & ::GT_RACE)? null : ::getTblValue("isBotsAllowed", missionInfo))
  setTextToObjByOption("session_botsranks", ::USEROPT_BOTS_RANKS,
               (gt & ::GT_RACE)? null : ::getTblValue("ranks", missionInfo))

  bObj = scene.findObject("session_jip")
  setTextToObj(bObj, ::loc("options/allow_jip") + ::loc("ui/colon"),
               ::getTblValue("allowJIP", sessionInfo, true))

  setTextToObjByOption("session_cluster", ::USEROPT_CLUSTER, ::getTblValue("cluster", sessionInfo))

  setTextToObjByOption("disable_airfields", ::USEROPT_DISABLE_AIRFIELDS, ::getTblValue("disableAirfields", missionInfo))

  setTextToObjByOption("spawn_ai_tank_on_tank_maps", ::USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, ::getTblValue("spawnAiTankOnTankMaps", missionInfo))

  setTextToObjByOption("content_allowed_preset", ::USEROPT_CONTENT_ALLOWED_PRESET, missionInfo?.allowedTagsPreset)

  local slObj = scene.findObject("slotbar_override")
  if (::check_obj(slObj))
  {
    local slotOverrideText = ""
    if (isSlotbarOverrided(::SessionLobby.getMissionName(true, sessionInfo)))
      slotOverrideText = ::colorize("userlogColoredText", ::loc("multiplayer/slotbarOverrided"))

    slObj.setValue(slotOverrideText)
  }
}