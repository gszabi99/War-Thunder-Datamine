from "%scripts/dagui_natives.nut" import get_cyber_cafe_id
from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let crossplayModule = require("%scripts/social/crossplay.nut")
let mapPreferencesParams = require("%scripts/missions/mapPreferencesParams.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { getMyCrewUnitsState } = require("%scripts/slotbar/crewsListInfo.nut")
let { getSelSlotsData } = require("%scripts/slotbar/slotbarState.nut")
let { queueProfileJwt } = require("%scripts/queue/queueBattleData.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_DISPLAY_MY_REAL_NICK
} = require("%scripts/options/optionsExtNames.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { getCurrentGameModeId } = require("%scripts/gameModes/gameModeManagerState.nut")
let { get_option_in_mode } = require("%scripts/options/optionsExt.nut")
let { havePackage } = require("%scripts/clientState/contentPacks.nut")

function getMyStateData() {
  let profileInfo = getProfileInfo()
  let gameModeId = g_squad_manager.isSquadMember()
    ? g_squad_manager.getLeaderGameModeId()
    : getCurrentGameModeId()
  let event = events.getEvent(gameModeId)
  let prefParams = mapPreferencesParams.getParams(event)
  let slotsData = getSelSlotsData()
  let myData = {
    name = profileInfo.name,
    clanTag = profileInfo.clanTag,
    pilotIcon = profileInfo.icon,
    rank = 0,
    country = profileInfo.country,
    crewAirs = null,
    selAirs = slotsData.units,
    selSlots = slotsData.slots,
    brokenAirs = null,
    cyberCafeId = get_cyber_cafe_id()
    unallowedEventsENames = events.getUnallowedEventEconomicNames(),
    crossplay = crossplayModule.isCrossPlayEnabled()
    bannedMissions = prefParams.bannedMissions
    dislikedMissions = prefParams.dislikedMissions
    craftsInfoByUnitsGroups = slotbarPresets.getCurCraftsInfo()
    platform = targetPlatform
    fakeName = !get_option_in_mode(USEROPT_DISPLAY_MY_REAL_NICK, OPTIONS_MODE_GAMEPLAY).value
    queueProfileJwt = queueProfileJwt.value ?? ""
  }

  let airs = getMyCrewUnitsState(profileInfo.country)
  myData.crewAirs = airs.crewAirs
  myData.brokenAirs = airs.brokenAirs
  if (airs.rank > myData.rank)
    myData.rank = airs.rank

  let checkPacks = ["pkg_main"]
  let missed = []
  foreach (pack in checkPacks)
    if (!havePackage(pack))
      missed.append(pack)
  if (missed.len())
    myData.missedPkg <- missed

  return myData
}

return {
  getMyStateData
}