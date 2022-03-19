local crossplayModule = require("scripts/social/crossplay.nut")
local mapPreferencesParams = require("scripts/missions/mapPreferencesParams.nut")
local slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
local { targetPlatform } = require("scripts/clientState/platform.nut")
local { getMyCrewUnitsState } = require("scripts/slotbar/crewsListInfo.nut")

local function getMyStateData() {
  local profileInfo = ::get_profile_info()
  local gameModeId = ::g_squad_manager.isSquadMember()
    ? ::g_squad_manager.getLeaderGameModeId()
    : ::game_mode_manager.getCurrentGameModeId()
  local event = ::events.getEvent(gameModeId)
  local prefParams = mapPreferencesParams.getParams(event)
  local myData = {
    name = profileInfo.name,
    clanTag = profileInfo.clanTag,
    pilotIcon = profileInfo.icon,
    rank = 0,
    country = profileInfo.country,
    crewAirs = null,
    selAirs = ::getSelAirsTable(),
    selSlots = getSelSlotsTable(),
    brokenAirs = null,
    cyberCafeId = ::get_cyber_cafe_id()
    unallowedEventsENames = ::events.getUnallowedEventEconomicNames(),
    crossplay = crossplayModule.isCrossPlayEnabled()
    bannedMissions = prefParams.bannedMissions
    dislikedMissions = prefParams.dislikedMissions
    craftsInfoByUnitsGroups = slotbarPresets.getCurCraftsInfo()
    platform = targetPlatform
    fakeName = ::get_option_in_mode(::USEROPT_REPLACE_MY_NICK_LOCAL, ::OPTIONS_MODE_GAMEPLAY).value != ""
  }

  local airs = getMyCrewUnitsState(profileInfo.country)
  myData.crewAirs = airs.crewAirs
  myData.brokenAirs = airs.brokenAirs
  if (airs.rank > myData.rank)
    myData.rank = airs.rank

  local checkPacks = ["pkg_main"]
  local missed = []
  foreach(pack in checkPacks)
    if (!::have_package(pack))
      missed.append(pack)
  if (missed.len())
    myData.missedPkg <- missed

  return myData
}

local havePlayerTag = @(tag) ::get_player_tags().indexof(tag) != null

return {
  getMyStateData
  havePlayerTag
}