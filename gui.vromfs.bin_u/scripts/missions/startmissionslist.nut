from "%scripts/dagui_natives.nut" import d3d_get_vsync_enabled, d3d_enable_vsync, get_game_mode_name, play_movie, set_context_to_player
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import USEROPT_DIFFICULTY
from "mission" import get_game_mode, get_game_type

let { g_mislist_type } =  require("%scripts/missions/misListType.nut")
let { eventbus_subscribe } = require("eventbus")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isInMenu, handlersManager, loadHandler, get_cur_base_gui_handler
} = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { get_mission_difficulty, do_start_flight } = require("guiMission")
let { get_gui_option, set_cd_preset } = require("guiOptions")
let { isInSessionRoom, sessionLobbyStatus } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { isRanksAllowed } = require("%scripts/ranksAllowed.nut")
let { isHostInRoom } = require("%scripts/matching/serviceNotifications/mrooms.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { web_rpc } = require("%scripts/webRPC.nut")
let { isRemoteMissionVar, matchSearchGm, currentCampaignId } = require("%scripts/missions/missionsStates.nut")

const DYNAMIC_REQ_COUNTRY_RANK = 1

let needCheckForVictory = Watched(false)
let backFromBriefingParams = mkWatched(persist, "backFromBriefingParams", { eventbusName = "gui_start_mainmenu"})

function guiStartSessionList() {
  loadHandler(gui_handlers.SessionsList,
                  {
                    wndOptionsMode = ::get_options_mode(get_game_mode())
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
  handlersManager.loadHandler(gui_handlers.RemoteMissionModalHandler, params)
}

function startRemoteMission(params) {
  let url = params.url
  let name = params.name || "remote_mission"

  if (!isInMenu() || handlersManager.isAnyModalHandlerActive())
    return

  let urlMission = ::UrlMission(name, url)
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

web_rpc.register_handler("start_remote_mission", @(params) startRemoteMission(params))

function guiStartSkirmish(_ = null) {
  prepareStartSkirmish()
  guiStartSessionList()
}

function guiStartMislist(isModal = false, setGameMode = null, addParams = {}) {
  let hClass = isModal ? gui_handlers.SingleMissionsModal : gui_handlers.SingleMissions
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
  loadHandler(gui_handlers.CampaignPreview, { isFinal = false })
}

function guiStartDynamicSummaryF() {
  loadHandler(gui_handlers.CampaignPreview, { isFinal = true })
}

function guiStartFlight() {
  set_context_to_player("difficulty", get_mission_difficulty())
  do_start_flight()
}

function guiStartMpLobby() {
  if (sessionLobbyStatus.get() != lobbyStates.IN_LOBBY) {
    gui_start_mainmenu()
    return
  }

  local backFromLobby = { eventbusName = "gui_start_mainmenu" }
  if (::SessionLobby.getGameMode() == GM_SKIRMISH && !isRemoteMissionVar.get())
    backFromLobby = { eventbusName = "guiStartSkirmish" }
  else {
    let lastEvent = ::SessionLobby.getRoomEvent()
    if (lastEvent && events.eventRequiresTicket(lastEvent) && events.getEventActiveTicket(lastEvent) == null) {
      gui_start_mainmenu()
      return
    }
  }

  isRemoteMissionVar.set(false)
  loadHandler(gui_handlers.MPLobby, { backSceneParams = backFromLobby })
}

function briefingOptionsApply() {
  let gt = get_game_type()
  let gm = get_game_mode()
  if (gm == GM_SINGLE_MISSION || gm == GM_DYNAMIC) {
    if (isInSessionRoom.get()) {
      if (!isHostInRoom())
        ::SessionLobby.continueCoopWithSquad(::mission_settings);
      else
        scene_msg_box("wait_host_leave", null, loc("msgbox/please_wait"),
          [["cancel", function() {}]], "cancel",
            {
              cancel_fn = function() { ::SessionLobby.continueCoopWithSquad(::mission_settings); },
              need_cancel_fn = function() { return !isHostInRoom(); }
              waitAnim = true,
              delayedButtons = 15
            })

      return;
    }

    if (!g_squad_manager.isNotAloneOnline())
      return get_cur_base_gui_handler().goForward(guiStartFlight)


    if (::g_squad_utils.canJoinFlightMsgBox(
          {
            isLeaderCanJoin = ::mission_settings.coop
            allowWhenAlone = false
            msgId = "multiplayer/squad/cantJoinSessionWithSquad"
            maxSquadSize = ::get_max_players_for_gamemode(gm)
          }
        )
      )
      ::SessionLobby.startCoopBySquad(::mission_settings)
    return
  }

  if (isInSessionRoom.get()) {
    ::SessionLobby.updateRoomAttributes(::mission_settings)
    get_cur_base_gui_handler().goForward(guiStartMpLobby)
    return
  }

  if ((gt & GT_VERSUS) || ::mission_settings.missionURL != "")
    ::SessionLobby.createRoom(::mission_settings)
  else
    get_cur_base_gui_handler().goForward(guiStartFlight)
}

function guiStartCdOptions(afterApplyFunc, owner = null) {
  log("guiStartCdOptions called")
  if (isInSessionRoom.get()) {
    let curDiff = ::SessionLobby.getMissionParam("custDifficulty", null)
    if (curDiff)
      set_cd_preset(curDiff)
  }

  loadHandler(gui_handlers.OptionsCustomDifficultyModal, {
    owner = owner
    afterApplyFunc = Callback(afterApplyFunc, owner)
  })
}

function guiStartBriefing() {
  //FIX ME: Check below really can be in more easier way.
  let startParams = handlersManager.getLastBaseHandlerStartParams()
  if (startParams != null && !isInArray(startParams?.handlerName ?? "",
      ["MPLobby", "SessionsList", "DebriefingModal"]))
    backFromBriefingParams(startParams)

  let params = {
    backSceneParams = backFromBriefingParams.value
    isRestart = false
  }
  params.applyFunc <- function() {
    if (get_gui_option(USEROPT_DIFFICULTY) == "custom")
      guiStartCdOptions(briefingOptionsApply, this)
    else
      briefingOptionsApply.call(this)
  }
  handlersManager.loadHandler(gui_handlers.Briefing)
}

eventbus_subscribe("guiStartSkirmish", guiStartSkirmish)
eventbus_subscribe("guiStartMislist", @(_) guiStartMislist())
eventbus_subscribe("guiStartDynamicSummary", guiStartDynamicSummary)
eventbus_subscribe("gui_start_briefing", @(_) guiStartBriefing())

function guiStartCampaignNoPack() {
  guiStartMislist(true, GM_CAMPAIGN)

  if (needCheckForVictory.value) {
    needCheckForVictory(false)
    play_movie("video/victory", false, true, true)
  }
}

function guiStartCampaign() {
  return ::check_package_and_ask_download("hc_pacific", null, guiStartCampaignNoPack, null, "campaign")
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
    ::ps4_vsync_enabled = d3d_get_vsync_enabled?() ?? false
    d3d_enable_vsync?(false)
  }
  guiStartMislist(true, GM_BENCHMARK)
}

function guiStartTutorial() {
  guiStartMislist(true, GM_TRAINING)
}

function guiStartDynamicLayouts() {
  loadHandler(gui_handlers.DynamicLayouts)
}

function guiStartBuilder(params = {}) {
  loadHandler(gui_handlers.MissionBuilder, params)
}

function startCreateWndByGamemode(_handler, _obj) {
  let gm = matchSearchGm.get()
  if (gm == GM_EVENT)
    guiStartBriefing()
  else if (gm == GM_DYNAMIC)
    guiStartDynamicLayouts()
  else if (gm == GM_BUILDER) {
    ::mission_settings.coop = true
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
  else //any coop - create dyncampaign
    guiStartDynamicLayouts()
  //may be not actual with current hndler managment system
  //handler.guiScene.initCursor("%gui/cursor.blk", "normal")
  ::update_gamercards()
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
  if (!::check_gamemode_pkg(gm))
    return

  handler.checkedNewFlight( function() {
    let tbl = buildCheckTable(null, gm)
    tbl.silent <- false
    if (isRanksAllowed.bindenv(handler)(tbl)) {
      matchSearchGm.set(gm)
      startCreateWndByGamemode(handler, null)
    }
  })
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
  guiStartMpLobby
  guiStartCdOptions
}
