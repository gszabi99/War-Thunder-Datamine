from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/options/optionsCustomDifficulty.nut" import OptionsCustomDifficultyModal
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler, get_cur_base_gui_handler
from "%sqstd/platform.nut" import isSony
from "%appGlobals/clientState/platform.nut" import isPs4VsyncEnabled
from "%scripts/matchingRooms/sessionLobbyState.nut" import isInSessionRoom, getSessionLobbyMissionParam
from "%scripts/mainmenu/guiStartMainmenu.nut" import gui_start_mainmenu
from "%scripts/ranksAllowed.nut" import isRanksAllowed
from "%scripts/matching/serviceNotifications/mroomsState.nut" import isHostInRoom
from "%scripts/missions/missionsStates.nut" import get_mission_settings, isRemoteMissionVar, matchSearchGm, currentCampaignId
from "%scripts/missions/urlMission.nut" import UrlMission
from "%scripts/missions/missionsUtils.nut" import getMaxPlayersForGamemode
from "%scripts/gamercard/gamercard.nut" import updateGamercards
from "%scripts/matchingRooms/sessionLobbyManager.nut" import updateRoomAttributes, guiStartMpLobby, continueCoopWithSquad
from "%scripts/matchingRooms/sessionLobbyActions.nut" import createSessionLobbyRoom, startCoopBySquad
from "%scripts/options/options.nut" import getOptionsMode
from "%scripts/clientState/contentPacks.nut" import checkGamemodePkg, checkPackageAndAskDownloadByTimes
from "%scripts/squads/squadUtils.nut" import canJoinFlightMsgBox
from "eventbus" import eventbus_subscribe
from "guiMission" import get_mission_difficulty, do_start_flight
from "guiOptions" import set_cd_preset
from "%globalScripts/gameTypeConsts.nut" import *
from "%scripts/dagui_natives.nut" import d3d_get_vsync_enabled, d3d_enable_vsync, get_game_mode_name, play_movie, set_context_to_player
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "mission" import get_game_mode, get_game_type
from "%scripts/webRPC.nut" import webRpcRegister

let { g_mislist_type } = require("%scripts/missions/misListType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")

const DYNAMIC_REQ_COUNTRY_RANK = 1

let needCheckForVictory = Watched(false)

function guiStartSessionList() {
  loadHandler(get_gui_handler("SessionsList"),
                  {
                    wndOptionsMode = getOptionsMode(get_game_mode())
                    backSceneParams = { eventbusName = "gui_start_mainmenu" }
                  })
}

let prepareStartSkirmish = @() matchSearchGm.set(GM_SKIRMISH)


function fastStartSkirmishMission(mission) {
  let params = {
    canSwitchMisListType = false
    showAllCampaigns = false
    mission = mission
    wndGameMode = GM_SKIRMISH
  }

  prepareStartSkirmish()
  isRemoteMissionVar.set(true)
  handlersManager.loadHandler(get_gui_handler("RemoteMissionModalHandler"), params)
}

function startRemoteMission(params) {
  let url = params.url
  let name = params.name ?? "remote_mission"

  if (!isInMenu.get() || handlersManager.isAnyModalHandlerActive())
    return

  let urlMission = UrlMission(name, url)
  let mission = {
    id = urlMission.name
    isHeader = false
    isCampaign = false
    isUnlocked = true
    campaign = ""
    chapter = ""
  }
  mission.urlMission <- urlMission

  let callback = function(success, mis) {
                     if (!success)
                       return

                     mis.blk <- urlMission.getMetaInfo()
                     fastStartSkirmishMission(mis)
                   }

  scene_msg_box("start_mission_from_live_confirmation",
                  null,
                  loc("urlMissions/live/loadAndStartConfirmation", params),
                  [["yes", function() { g_url_missions.loadBlk(mission, callback) }],
                   ["no", function() {} ]],
                  "yes", { cancel_fn = function() {} }
                )
}

webRpcRegister("start_remote_mission", @(params) startRemoteMission(params))

function guiStartSkirmish(_ = null) {
  prepareStartSkirmish()
  guiStartSessionList()
}

function guiStartMislist(isModal = false, setGameMode = null, addParams = {}) {
  let hClass = isModal ? get_gui_handler("SingleMissionsModal") : get_gui_handler("SingleMissions")
  let params = clone addParams
  local gm = get_game_mode()
  if (setGameMode != null) {
    params.wndGameMode <- setGameMode
    gm = setGameMode
  }

  params.canSwitchMisListType <- gm == GM_SKIRMISH

  let showAllCampaigns = gm == GM_CAMPAIGN || gm == GM_SINGLE_MISSION
  currentCampaignId.set(showAllCampaigns ? null : get_game_mode_name(gm))
  params.showAllCampaigns <- showAllCampaigns

  if (!isModal) {
    params.backSceneParams = { eventbusName = "gui_start_mainmenu" }
    if (isInSessionRoom.get() && (get_game_mode() == GM_DYNAMIC))
      params.backSceneParams = { eventbusName = "guiStartDynamicSummary" }
  }

  loadHandler(hClass, params)
  if (!isModal)
    handlersManager.setLastBaseHandlerStartParams({ eventbusName = "guiStartMislist" })
}

function guiStartDynamicSummary(_ = null) {
  loadHandler(get_gui_handler("CampaignPreview"), { isFinal = false })
}

function guiStartDynamicSummaryF() {
  loadHandler(get_gui_handler("CampaignPreview"), { isFinal = true })
}

function guiStartFlight() {
  set_context_to_player("difficulty", get_mission_difficulty())
  do_start_flight()
}

function briefingOptionsApply() {
  let gt = get_game_type()
  let gm = get_game_mode()
  if (gm == GM_SINGLE_MISSION || gm == GM_DYNAMIC) {
    if (isInSessionRoom.get()) {
      if (!canJoinFlightMsgBox({ isLeaderCanJoin = true }))
        return

      if (!isHostInRoom())
        continueCoopWithSquad(get_mission_settings());
      else
        scene_msg_box("wait_host_leave", null, loc("msgbox/please_wait"),
          [["cancel", function() {}]], "cancel",
            {
              cancel_fn = function() { continueCoopWithSquad(get_mission_settings()); },
              need_cancel_fn = function() { return !isHostInRoom(); }
              waitAnim = true,
              delayedButtons = 15
            })

      return;
    }

    if (!g_squad_manager.isNotAloneOnline())
      return get_cur_base_gui_handler().goForward(guiStartFlight)


    if (canJoinFlightMsgBox(
          {
            isLeaderCanJoin = get_mission_settings().coop
            allowWhenAlone = false
            msgId = "multiplayer/squad/cantJoinSessionWithSquad"
            maxSquadSize = getMaxPlayersForGamemode(gm)
          }
        )
      )
      startCoopBySquad(get_mission_settings())
    return
  }

  if (isInSessionRoom.get()) {
    updateRoomAttributes(get_mission_settings())
    get_cur_base_gui_handler().goForward(guiStartMpLobby)
    return
  }

  if ((gt & GT_VERSUS) || get_mission_settings().missionURL != "")
    createSessionLobbyRoom(get_mission_settings())
  else
    get_cur_base_gui_handler().goForward(guiStartFlight)
}

function guiStartCdOptions(afterApplyFunc, owner = null) {
  log("guiStartCdOptions called")
  if (isInSessionRoom.get()) {
    let curDiff = getSessionLobbyMissionParam("custDifficulty", null)
    if (curDiff)
      set_cd_preset(curDiff)
  }

  loadHandler(OptionsCustomDifficultyModal, {
    owner = owner
    afterApplyFunc = Callback(afterApplyFunc, owner)
  })
}

eventbus_subscribe("guiStartSkirmish", guiStartSkirmish)
eventbus_subscribe("guiStartMislist", @(_) guiStartMislist())
eventbus_subscribe("guiStartDynamicSummary", guiStartDynamicSummary)

function guiStartCampaignNoPack() {
  guiStartMislist(true, GM_CAMPAIGN)

  if (needCheckForVictory.get()) {
    needCheckForVictory.set(false)
    play_movie("video/victory", false, true, true)
  }
}

function guiStartCampaign() {
  return checkPackageAndAskDownloadByTimes("hc_pacific", guiStartCampaignNoPack, null, null, true)
}

function guiStartMenuCampaign() {
  gui_start_mainmenu()
  guiStartCampaign()
}

function guiStartSingleMissions() {
  guiStartMislist(true, GM_SINGLE_MISSION)
}

function guiStartMenuSingleMissions() {
  gui_start_mainmenu()
  guiStartSingleMissions()
}

function guiStartUserMissions() {
  guiStartMislist(true, GM_SINGLE_MISSION, { misListType = g_mislist_type.UGM })
}

function guiStartMenuUserMissions() {
  gui_start_mainmenu()
  guiStartUserMissions()
}

function guiCreateSkirmish() {
  guiStartMislist(true, GM_SKIRMISH)
}

function guiStartBenchmark() {
  if (isSony) {
    isPs4VsyncEnabled.set(d3d_get_vsync_enabled?() ?? false)
    d3d_enable_vsync?(false)
  }
  guiStartMislist(true, GM_BENCHMARK)
}

function guiStartTutorial() {
  guiStartMislist(true, GM_TRAINING)
}

function guiStartDynamicLayouts() {
  loadHandler(get_gui_handler("DynamicLayouts"))
}

function guiStartBuilder(params = {}) {
  loadHandler(get_gui_handler("MissionBuilder"), params)
}

function startCreateWndByGamemode(_handler, _obj) {
  let gm = matchSearchGm.get()
  if (gm == GM_DYNAMIC)
    guiStartDynamicLayouts()
  else if (gm == GM_SINGLE_MISSION)
    guiStartSingleMissions()
  else if (gm == GM_USER_MISSION)
    guiStartUserMissions()
  else if (gm == GM_SKIRMISH)
    guiCreateSkirmish()
  
  
  updateGamercards()
}

function buildCheckTable(session, gm = 0) {
  let ret = {}

  if (session)
    gm = session.gameModeInt

  if (gm == GM_DYNAMIC) {
    if (session) {
      ret.minRank <- DYNAMIC_REQ_COUNTRY_RANK
      ret.rankCountry <- session.country
    }
  }
  else if (gm == GM_SINGLE_MISSION) {
    if (session)
      ret.unlock <- "/".concat(session.chapter, session.map)
  }

  return ret
}

function checkAndCreateGamemodeWnd(handler, gm) {
  let cb = Callback(@() this.checkedNewFlight(function() {
    let tbl = buildCheckTable(null, gm)
    tbl.silent <- false
    if (isRanksAllowed(handler, tbl)) {
      matchSearchGm.set(gm)
      startCreateWndByGamemode(handler, null)
    }
  }), handler)
  checkGamemodePkg(gm, cb)
}


return freeze({
  DYNAMIC_REQ_COUNTRY_RANK
  needCheckForVictory
  guiStartSessionList
  guiStartSkirmish
  prepareStartSkirmish
  checkAndCreateGamemodeWnd
  guiStartCampaign
  guiStartMenuCampaign
  guiStartMenuSingleMissions
  guiStartMenuUserMissions
  guiStartMislist
  guiStartBenchmark
  guiStartTutorial
  guiStartDynamicSummary
  guiStartDynamicSummaryF
  guiStartBuilder
  guiStartFlight
  briefingOptionsApply
  guiStartCdOptions
})
