from "%scripts/dagui_library.nut" import *
from "%scripts/gameModes/gameModeConsts.nut" import BATTLE_TYPES

let matchSearchGm = mkWatched(persist, "matchSearchGm", -1)
let isRemoteMissionVar = mkWatched(persist, "isRemoteMissionVar", false)
let currentCampaignId = mkWatched(persist, "currentCampaignId", null)
let currentCampaignMission = mkWatched(persist, "currentCampaignMission", null)

let persist_state = persist("persist_state", @() {
  current_campaign = null,
  mission_for_takeoff=""
  mission_settings = {
    name = null
    postfix = null
    missionURL = null
    aircraft = null
    weapon = null
    diff = 1
    mrankMin = null
    mrankMax = null
    players = null
    time = null
    weather = null
    isLimitedFuel = false
    isLimitedAmmo = false
    takeoffMode = 0
    currentMissionIdx = -1

    mission = null
    missionFull = null
    countriesType = null
    country_allies_bitmask = 0
    country_axis_bitmask = 0
    userAllowedUnitTypesMask = 0
    cluster = ""
    friendOnly = false
    allowJIP = true
    dedicatedReplay = false
    allowWebUi = -1
    coop = false
    layout = null
    sessionPassword = ""
    layoutName = ""
    isBotsAllowed = true
    rounds = 0
    arcadeCountry = false
    maxRespawns = -1
    autoBalance = true
    dynlist = []
    battleMode = BATTLE_TYPES.AIR 
  }

})

function is_user_mission(missionBlk) {
  return missionBlk?.userMission == true 
}

return {
  matchSearchGm
  isRemoteMissionVar
  currentCampaignId
  currentCampaignMission
  set_current_campaign = @(v) persist_state.current_campaign = v
  get_current_campaign = @() persist_state.current_campaign
  get_mission_for_takeoff = @() persist_state.mission_for_takeoff
  set_mission_for_takeoff = @(v) persist_state.mission_for_takeoff=v
  get_mission_settings = @() freeze(persist_state.mission_settings)
  set_mission_settings = @(k, v) persist_state.mission_settings[k] = v
  get_mutable_mission_settings = @() persist_state.mission_settings
  is_user_mission
}