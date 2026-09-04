from "eventbus" import eventbus_subscribe
from "guiMission" import get_mission_difficulty, do_start_flight
from "guiOptions" import get_gui_option, set_cd_preset
from "%globalScripts/gameTypeConsts.nut" import *
from "%scripts/dagui_natives.nut" import d3d_get_vsync_enabled, d3d_enable_vsync, get_game_mode_name, play_movie, set_context_to_player
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import USEROPT_DIFFICULTY
from "mission" import get_game_mode, get_game_type
from "%scripts/webRPC.nut" import webRpcRegister
let { g_mislist_type } = require("%scripts/missions/misListType.nut")
let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { OptionsCustomDifficultyModal } = require("%scripts/options/optionsCustomDifficulty.nut")
let { Briefing } = require("%scripts/briefing.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { handlersManager, loadHandler, get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isPlatformSony, isPs4VsyncEnabled } = require("%scripts/clientState/platform.nut")
let { isInSessionRoom, getSessionLobbyMissionParam } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { isRanksAllowed } = require("%scripts/ranksAllowed.nut")
let { isHostInRoom } = require("%scripts/matching/serviceNotifications/mroomsState.nut")
let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { get_mission_settings, set_mission_settings, isRemoteMissionVar, matchSearchGm, currentCampaignId } = require("%scripts/missions/missionsStates.nut")
let { UrlMission } = require("%scripts/missions/urlMission.nut")
let { getMaxPlayersForGamemode } = require("%scripts/missions/missionsUtils.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { updateRoomAttributes, guiStartMpLobby, continueCoopWithSquad } = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { createSessionLobbyRoom, startCoopBySquad } = require("%scripts/matchingRooms/sessionLobbyActions.nut")
let { getOptionsMode } = require("%scripts/options/options.nut")
let { checkGamemodePkg, checkPackageAndAskDownloadByTimes } = require("%scripts/clientState/contentPacks.nut")
let { canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")

const DYNAMIC_REQ_COUNTRY_RANK = 1

let needCheckForVictory = Watched(false)
let backFromBriefingParams = mkWatched(persist, "backFromBriefingParams", { eventbusName = "gui_start_mainmenu"})

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

function guiStartBriefing() {
  
  let startParams = handlersManager.getLastBaseHandlerStartParams()
  if (startParams != null && !isInArray(startParams?.handlerName ?? "",
      ["MPLobby", "SessionsList", "DebriefingModal"]))
    backFromBriefingParams.set(startParams)

  let params = {
    backSceneParams = backFromBriefingParams.get()
    isRestart = false
  }
  params.applyFunc <- function() {
    if (get_gui_option(USEROPT_DIFFICULTY) == "custom")
      guiStartCdOptions(briefingOptionsApply, this)
    else
      briefingOptionsApply.call(this)
  }
  handlersManager.loadHandler(Briefing)
}

eventbus_subscribe("guiStartSkirmish", guiStartSkirmish)
eventbus_subscribe("guiStartMislist", @(_) guiStartMislist())
eventbus_subscribe("guiStartDynamicSummary", guiStartDynamicSummary)
eventbus_subscribe("gui_start_briefing", @(_) guiStartBriefing())

function guiStartCampaignNoPack() {
  guiStartMislist(true, GM_CAMPAIGN)

  if (needCheckForVictory.get()) {
    needCheckForVictory.set(false)
    play_movie("video/victory", false, true, true)
  }
}

function guiStartCampaign() {
  return checkPackageAndAskDownloadByTimes("hc_pacific", guiStartCampaignNoPack)
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
  if (isPlatformSony) {
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
  if (gm == GM_EVENT)
    guiStartBriefing()
  else if (gm == GM_DYNAMIC)
    guiStartDynamicLayouts()
  else if (gm == GM_BUILDER) {
    set_mission_settings("coop", true)
    guiStartBuilder()
  }
  else if (gm == GM_SINGLE_MISSION)
    guiStartSingleMissions()
  else if (gm == GM_USER_MISSION)
    guiStartUserMissions()
  else if (gm == GM_SKIRMISH)
    guiCreateSkirmish()
  else if (gm == GM_DOMINATION || gm == GM_TOURNAMENT)
    guiStartMislist()
  else 
    guiStartDynamicLayouts()
  
  
  updateGamercards()
}

function buildCheckTable(session, gm = 0) {
  let ret = {}

  if (session)
    gm = session.gameModeInt

  if (gm == GM_BUILDER) {
    ret.silentFeature <- "ModeBuilder"
  }
  else if (gm == GM_DYNAMIC) {
    if (session) {
      ret.minRank <- DYNAMIC_REQ_COUNTRY_RANK
      ret.rankCountry <- session.country
    }
    ret.silentFeature <- "ModeDynamic"
  }
  else if (gm == GM_SINGLE_MISSION) {
    if (session)
      ret.unlock <- "/".concat(session.chapter, session.map)
    ret.silentFeature <- "ModeSingleMissions"
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


return {
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
}
