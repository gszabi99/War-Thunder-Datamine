import "%scripts/social/crossplay.nut" as crossplayModule
import "%scripts/missions/mapPreferencesParams.nut" as mapPreferencesParams
from "%scripts/events/eventsState.nut" import getEvent
from "%scripts/events/eventAllowed.nut" import getUnallowedEventEconomicNames
from "%scripts/squads/squadState.nut" import getLeaderGameModeId, isSquadMember
from "%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut" import getCurCraftsInfo
from "%sqstd/platform.nut" import platformId
from "%scripts/slotbar/slotbarPresetsHelpers.nut" import getMyCrewUnitsState
from "%scripts/slotbar/slotbarState.nut" import getSelSlotsData
from "%scripts/queue/queueBattleData.nut" import queueProfileJwt
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_DISPLAY_MY_REAL_NICK, USEROPT_DISPLAY_MY_REAL_CLAN
from "%scripts/user/userInfoStats.nut" import getProfileInfo
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeId
from "%scripts/options/optionsExt.nut" import get_option_in_mode
from "%scripts/clientState/contentPacks.nut" import havePackage
from "%scripts/dagui_natives.nut" import get_cyber_cafe_id
from "%scripts/unit/unitMrankSelectionState.nut" import getMrankDeltaByUnit
from "%scripts/dagui_library.nut" import *

function getMyStateData() {
  let profileInfo = getProfileInfo()
  let gameModeId = isSquadMember()
    ? getLeaderGameModeId()
    : getCurrentGameModeId()
  let event = getEvent(gameModeId)
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
    unallowedEventsENames = getUnallowedEventEconomicNames(),
    crossplay = crossplayModule.isCrossPlayEnabled()
    bannedMissions = prefParams.bannedMissions
    dislikedMissions = prefParams.dislikedMissions
    craftsInfoByUnitsGroups = getCurCraftsInfo()
    platform = platformId
    fakeName = !get_option_in_mode(USEROPT_DISPLAY_MY_REAL_NICK, OPTIONS_MODE_GAMEPLAY).value
    hideClan = !get_option_in_mode(USEROPT_DISPLAY_MY_REAL_CLAN, OPTIONS_MODE_GAMEPLAY).value
    queueProfileJwt = queueProfileJwt.get() ?? ""
  }

  let airs = getMyCrewUnitsState(profileInfo.country)
  myData.crewAirs = airs.crewAirs
  myData.brokenAirs = airs.brokenAirs
  if (airs.rank > myData.rank)
    myData.rank = airs.rank

  let ownUnitNames = []
  foreach (names in airs.crewAirs)
    ownUnitNames.extend(names)
  myData.mrankDeltaByUnit <- getMrankDeltaByUnit(ownUnitNames)

  let checkPacks = ["pkg_main"]
  let missed = []
  foreach (pack in checkPacks)
    if (!havePackage(pack))
      missed.append(pack)
  if (missed.len())
    myData.missedPkg <- missed

  return myData
}

return freeze({
  getMyStateData
})