from "%scripts/dagui_library.nut" import *
#no-root-fallback
#explicit-this
let { get_meta_mission_info_by_name, select_mission } = require("guiMission")
let { set_game_mode } = require("mission")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

const MIS_NAME = "tutorial_destroyer_battle_arcade"

let function isGmForUnitType(esUnitType) {
  let gameMode = ::game_mode_manager.getCurrentGameMode()
  let reqUnitTypes = ::game_mode_manager.getRequiredUnitTypes(gameMode)
  return reqUnitTypes.contains(esUnitType)
}

let function isUnitTypeInSlot(esUnitType) {
  let crews = ::get_crews_list_by_country(profileCountrySq.value)
  return crews.findindex(@(crew) ::g_crew.getCrewUnit(crew)?.esUnitType == esUnitType) != null
}

let function canStartShipTrainingMission() {
  if (!::my_stats.isStatsLoaded() || !::g_login.isProfileReceived())
    return false

  let hasLaunches = ::loadLocalByAccount($"tutor/mission_launched_{MIS_NAME}", false)
  if (hasLaunches)
    return false

  let hasRespawns = ::my_stats.getPvpRespawnsOnUnitType(ES_UNIT_TYPE_SHIP) > 0
  if (hasRespawns)
    return false

  if (!isGmForUnitType(ES_UNIT_TYPE_SHIP) || !isUnitTypeInSlot(ES_UNIT_TYPE_SHIP))
    return false

  let misBlk = get_meta_mission_info_by_name(MIS_NAME)
  if (!misBlk || (("reqFeature" in misBlk) && !hasFeature(misBlk.reqFeature)))
    return false

  return true
}

let function startShipTrainingMission() {
  ::destroy_session_scripted("on startShipTrainingMission")
  set_game_mode(GM_TRAINING)
  let misBlk = get_meta_mission_info_by_name(MIS_NAME)
  select_mission(misBlk, true)
  ::current_campaign_mission = MIS_NAME
  ::gui_start_flight()

  ::saveLocalByAccount($"tutor/mission_launched_{MIS_NAME}", true)
  ::save_profile(false)
}

return {
  startShipTrainingMission
  canStartShipTrainingMission
}