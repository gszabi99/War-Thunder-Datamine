from "%scripts/dagui_natives.nut" import is_crew_slot_was_ready_at_host, wp_get_cost2, set_aircraft_accepted_cb, race_finished_by_local_player, get_local_player_country, set_tactical_map_hud_type, get_slot_delay, get_cur_warpoints, shop_get_spawn_score, get_slot_delay_by_slot, close_ingame_gui, disable_flight_menu, get_cur_rank_info, force_spectator_camera_rotation, is_respawn_screen
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/respawn/respawnConsts.nut" import RespawnOptUpdBit
from "radarOptions" import set_option_radar_name, set_option_radar_scan_pattern_name
from "hudState" import show_hud
from "%scripts/utils_sa.nut" import get_mplayer_color

let { g_mis_loading_state } = require("%scripts/respawn/misLoadingState.nut")
let { eventbus_subscribe } = require("eventbus")
let { get_current_base_gui_handler } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { get_game_params_blk } = require("blkGetters")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { toPixels, getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let { get_time_msec } = require("dagor.time")
let { get_gui_option } = require("guiOptions")
let { ceil } = require("math")
let { format } = require("string")
let { is_has_multiplayer } = require("multiplayer")
let { get_current_mission_name, get_game_mode,
  get_game_type, get_mplayer_by_id, get_local_mplayer, get_mp_local_team } = require("mission")
let { fetchChangeAircraftOnStart, canRespawnCaNow, canRequestAircraftNow,
  setSelectedUnitInfo, getAvailableRespawnBases, getRespawnBaseTimeLeftById,
  selectRespawnBase, highlightRespawnBase, getRespawnBase, doRespawnPlayer,
  requestAircraftAndWeaponWithSpare } = require("guiRespawn")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let statsd = require("statsd")
let time = require("%scripts/time.nut")
let respawnBases = require("%scripts/respawn/respawnBases.nut")
let respawnOptions = require("%scripts/respawn/respawnOptionsType.nut")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let contentPreset = require("%scripts/customization/contentPreset.nut")
let actionBarInfo = require("%scripts/hud/hudActionBarInfo.nut")
let { getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let { getLastWeapon, setLastWeapon, isWeaponEnabled, isWeaponVisible, getOverrideBullets
} = require("%scripts/weaponry/weaponryInfo.nut")
let { getModificationName, getUnitLastBullets } = require("%scripts/weaponry/bulletsInfo.nut")
let { AMMO, getAmmoAmount, getAmmoMaxAmountInSession, getAmmoAmountData
} = require("%scripts/weaponry/ammoInfo.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { getEventSlotbarHint } = require("%scripts/slotbar/slotbarOverride.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { showedUnit, setShowUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { guiStartMPStatScreenFromGame, getCurMpTitle
  guiStartMPStatScreen } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { onSpectatorMode, switchSpectatorTarget,
  getSpectatorTargetId, getSpectatorTargetName, getSpectatorTargetTitle
} = require("guiSpectator")
let { getMplayersList } = require("%scripts/statistics/mplayersList.nut")
let { quit_to_debriefing, get_mission_difficulty_int,
  get_unit_wp_to_respawn, get_mp_respawn_countdown, get_mission_status,
  OBJECTIVE_TYPE_PRIMARY, OBJECTIVE_TYPE_SECONDARY } = require("guiMission")
let { setCurSkinToHangar, getRealSkin, getSkinsOption
} = require("%scripts/customization/skins.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { openPersonalTasks } = require("%scripts/unlocks/personalTasks.nut")
let { set_option, get_option } = require("%scripts/options/optionsExt.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { USEROPT_SKIP_WEAPON_WARNING, USEROPT_FUEL_AMOUNT_CUSTOM,
  USEROPT_LOAD_FUEL_AMOUNT} = require("%scripts/options/optionsExtNames.nut")
let { loadLocalByScreenSize, saveLocalByScreenSize
} = require("%scripts/clientState/localProfile.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { getContactsHandler } = require("%scripts/contacts/contactsHandlerState.nut")
let { register_command } = require("console")
let { calcBattleRatingFromRank, reset_cur_mission_mode, clear_spawn_score, get_mission_mode } = require("%appGlobals/ranks_common_shared.nut")
let { isCrewAvailableInSession, isSpareAircraftInSlot,
  isRespawnWithUniversalSpare, getWasReadySlotsMask, getDisabledSlotsMask
} = require("%scripts/respawn/respawnState.nut")
let { getUniversalSparesForUnit } = require("%scripts/items/itemsManagerModule.nut")
let { isUnitUnlockedInSlotbar, getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { openRespawnSpareWnd } = require("%scripts/respawn/respawnSpareWnd.nut")
let { markUsedItemCount } = require("%scripts/items/usedItemsInBattle.nut")
let { buildUnitSlot, fillUnitSlotTimers, getSlotObjId, getSlotObj, getSlotUnitNameText,
  getUnitSlotPriceText, getUnitSlotPriceHintText
} = require("%scripts/slotbar/slotbarView.nut")
let { gui_start_flight_menu } = require("%scripts/flightMenu/flightMenu.nut")
let { quitMission } = require("%scripts/hud/startHud.nut")
let { collectOrdersToActivate, showActivateOrderButton, enableOrders
} = require("%scripts/items/orders.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { getCrewUnit, getCrew } = require("%scripts/crew/crew.nut")
let { createAdditionalUnitsViewData, updateUnitSelection, isLockedUnit, setUnitUsed } = require("%scripts/respawn/additionalUnits.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { loadGameChatToObj, detachGameChatSceneData, hideGameChatSceneInput
} = require("%scripts/chat/mpChat.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { setAllowMoveCenter, isAllowedMoveCenter, setForcedHudType, getCurHudType, isForcedHudType,
  setPointSettingMode, isPointSettingMode, resetPointOfInterest, isPointOfInterestSet  } = require("guiTacticalMap")
let { hasSightStabilization } = require("vehicleModel")
let AdditionalUnits = require("%scripts/misCustomRules/ruleAdditionalUnits.nut")
let { isGroundAndAirMission } = require("%scripts/missions/missionType.nut")
let { clearStreaks } =  require("%scripts/streaks.nut")
let { gui_load_mission_objectives } = require("%scripts/misObjectives/misObjectivesView.nut")

let { getRoomEvent, getRoomUnitTypesMask, getNotAvailableUnitByBRText
} = require("%scripts/matchingRooms/sessionLobbyInfo.nut")

function getCrewSlotReadyMask() {
  if (!g_mis_loading_state.isCrewsListReceived())
    return 0

  return getWasReadySlotsMask() & ~getDisabledSlotsMask()
}

function getCompoundedText(firstPart, secondPart, color) {
  return "".concat(firstPart, colorize(color, secondPart))
}


let respawnWndState = persist("respawnWndState", @() {
  lastCaAircraft = null
  needRaceFinishResults = false
  beforeFirstFlightInSession = false
})
let usedPlanes = persist("usedPlanes", @() {})

function onMissionStartedMp(_) {
  log("on_mission_started_mp - CLIENT")
  clearStreaks()
  respawnWndState.beforeFirstFlightInSession = true
  clear_spawn_score()
  reset_cur_mission_mode()
  broadcastEvent("MissionStarted")
}

eventbus_subscribe("on_mission_started_mp", onMissionStartedMp)

enum ESwitchSpectatorTarget {
  E_DO_NOTHING,
  E_NEXT,
  E_PREV
}

function gui_start_respawn(_ = null) {
  loadHandler(gui_handlers.RespawnHandler)
  handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_respawn" })
}

eventbus_subscribe("gui_start_respawn", gui_start_respawn)

let needSkipAvailableCrewToSelect = persist("needSkipAvailableCrewToSelect", @() {value = false})

gui_handlers.RespawnHandler <- class (gui_handlers.MPStatistics) {
  sceneBlkName = "%gui/respawn/respawn.blk"
  widgetsList = [
    { widgetId = DargWidgets.RESPAWN }
  ]

  shouldBlurSceneBg = true
  shouldOpenCenteredToCameraInVr = true
  keepLoaded = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_NONE

  showButtons = true
  sessionWpBalance = 0

  slotDelayDataByCrewIdx = {}

  //temporary hack before real fix will appear at all platforms.
  needCheckSlotReady = true //compatibility with "1.51.7.81"
  slotReadyAtHostMask = 0
  slotsCostSum = 0 //refreash slotbar when unit costs sum will changed after initslotbar.

  isFirstInit = true
  isFirstUnitOptionsInSession = false
  weaponsSelectorWeak = null
  teamUnitsLeftWeak = null

  canSwitchChatSize = false
  isChatFullSize = true

  isModeStat = false
  showLocalTeamOnly = true
  isStatScreen = false

  haveSlots = false
  haveSlotbar = false
  isGTCooperative = false
  canChangeAircraft = false
  stayOnRespScreen = false
  haveRespawnBases = false
  canChooseRespawnBase = false
  respawnBasesList = []
  curRespawnBase = null
  isNoRespawns = false
  isRespawn = false //use for called respawn from battle on M or Tab
  needRefreshSlotbarOnReinit = false

  canInitVoiceChatWithSquadWidget = true

  noRespText = ""
  applyText = ""

  tmapBtnObj  = null
  tmapHintObj = null
  tmapRespawnBaseTimerObj = null
  tmapIconObj = null

  lastRequestData = null
  lastSpawnUnitName = ""
  requestInProgress = false

  readyForRespawn = true  //aircraft and weapons choosen
  doRespawnCalled = false
  respawnRecallTimer = -1.0
  autostartTimer = -1
  autostartTime = 0
  autostartShowTime = 0
  autostartShowInColorTime = 0

  isFriendlyUnitsExists = true
  spectator_switch_timer_max = 0.5
  spectator_switch_timer = 0
  spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING
  lastSpectatorTargetName = ""

  bulletsDescr = array(BULLETS_SETS_QUANTITY, null)

  optionsFilled = null

  missionRules = null
  slotbarInited = false
  leftRespawns = -1
  customStateCrewAvailableMask = 0
  curSpawnScore = 0
  crewsSpawnScoreMask = 0 //mask of crews available by spawn score

  curSpawnRageTokens = 0
  crewsSpawnRageTokensMask = 0 //mask of crews available spawn by rage token

  // debug vars
  timeToAutoSelectAircraft = 0.0
  timeToAutoStart = 0.0

  // Debug vars
  timeToAutoRespawn = 0.0

  prevUnitAutoChangeTimeMsec = -1
  prevAutoChangedUnit = null
  delayAfterAutoChangeUnitMsec = 1000

  universalSpareUidForRespawn = ""

  isInUpdateLoadFuelOptions = false

  static mainButtonsId = ["btn_select", "btn_select_no_enter"]

  function initScreen() {
    showObjById("tactical-map-box", true, this.scene)
    showObjById("tactical-map", true, this.scene)
    if (this.curRespawnBase != null)
      selectRespawnBase(this.curRespawnBase.mapId)

    this.missionRules = getCurMissionRules()

    this.checkFirstInit()

    disable_flight_menu(true)

    this.needPlayersTbl = false
    this.isApplyPressed = false
    this.doRespawnCalled = false
    let wasIsRespawn = this.isRespawn
    this.isRespawn = is_respawn_screen()
    this.needRefreshSlotbarOnReinit = this.isRespawn || wasIsRespawn

    this.initStatsMissionParams()

    this.isFriendlyUnitsExists = this.isModeWithFriendlyUnits(this.gameType)

    this.updateCooldown = -1
    this.wasTimeLeft = -1000
    this.mplayerTable = get_local_mplayer() || {}
    this.missionTable = this.missionRules.missionParams

    this.readyForRespawn = this.readyForRespawn && this.isRespawn
    this.recountStayOnRespScreen()

    this.updateSpawnScore(true)
    this.updateSpawnRageTokens(true)
    this.updateLeftRespawns()

    let blk = get_game_params_blk()
    this.autostartTime = blk.autostartTime;
    this.autostartShowTime = blk.autostartShowTime;
    this.autostartShowInColorTime = blk.autostartShowInColorTime;

    log($"stayOnRespScreen = {this.stayOnRespScreen}")

    let spectator = this.isSpectator()
    this.haveSlotbar = (this.gameType & (GT_VERSUS | GT_COOPERATIVE)) &&
                  (this.gameMode != GM_SINGLE_MISSION && this.gameMode != GM_DYNAMIC) &&
                  !spectator
    this.isGTCooperative = (this.gameType & GT_COOPERATIVE) != 0
    this.canChangeAircraft = this.haveSlotbar && !this.stayOnRespScreen && this.isRespawn

    if (fetchChangeAircraftOnStart() && !this.stayOnRespScreen && !spectator) {
      log("fetchChangeAircraftOnStart() true")
      this.isRespawn = true
      this.stayOnRespScreen = false
      this.canChangeAircraft = true
    }

    if (this.missionRules.isScoreRespawnEnabled)
      this.canChangeAircraft = this.canChangeAircraft && this.curSpawnScore >= this.missionRules.getMinimalRequiredSpawnScore()
    this.canChangeAircraft = this.canChangeAircraft && this.leftRespawns != 0

    this.setSpectatorMode(this.isRespawn && this.stayOnRespScreen && this.isFriendlyUnitsExists, true)
    this.createRespawnOptions()

    this.loadChat()

    this.updateRespawnBasesStatus()
    this.initAircraftSelect()
    ::init_options() //for disable menu only

    this.updateApplyText()
    this.updateButtons()
    ::add_tags_for_mp_players()

    showObjById("screen_button_back", useTouchscreen && !this.isRespawn, this.scene)
    showObjById("gamercard_bottom", this.isRespawn, this.scene)

    if (this.gameType & GT_RACE) {
      let finished = race_finished_by_local_player()
      if (finished && respawnWndState.needRaceFinishResults)
        guiStartMPStatScreenFromGame()
      respawnWndState.needRaceFinishResults = !finished
    }

    collectOrdersToActivate()
    let ordersButton = this.scene.findObject("btn_activateorder")
    if (checkObj(ordersButton))
      ordersButton.setUserData(this)

    this.updateControlsAllowMask()
    this.updateVoiceChatWidget(!this.isRespawn)
    getContactsHandler()?.sceneShow(false)


    if(this.missionRules instanceof AdditionalUnits)
      this.scene.findObject("additionalUnitsNest").show(true)
  }

  function isModeWithFriendlyUnits(gt = null) {
    if (gt == null)
      gt = get_game_type()
    return !!(gt & GT_RACE) || !(gt & (GT_FFA_DEATHMATCH | GT_FFA))
  }

  function recountStayOnRespScreen() { //return isChanged
    let newHaveSlots = ::has_available_slots()
    let newStayOnRespScreen = this.missionRules.isStayOnRespScreen() || !newHaveSlots
    if ((newHaveSlots == this.haveSlots) && (newStayOnRespScreen == this.stayOnRespScreen))
      return false

    this.haveSlots = newHaveSlots
    this.stayOnRespScreen = newStayOnRespScreen
    return true
  }

  function checkFirstInit() {
    if (!this.isFirstInit)
      return
    this.isFirstInit = false

    this.isFirstUnitOptionsInSession = respawnWndState.beforeFirstFlightInSession

    this.scene.findObject("stat_update").setUserData(this)

    this.subHandlers.append(
      gui_load_mission_objectives(this.scene.findObject("primary_tasks_list"),   true, 1 << OBJECTIVE_TYPE_PRIMARY),
      gui_load_mission_objectives(this.scene.findObject("secondary_tasks_list"), true, 1 << OBJECTIVE_TYPE_SECONDARY)
    )

    let navBarObj = this.scene.findObject("gamercard_bottom_navbar_place")
    if (checkObj(navBarObj)) {
      navBarObj.show(true)
      navBarObj["id"] = "nav-help"
      this.guiScene.replaceContent(navBarObj, "%gui/navRespawn.blk", this)
    }

    this.includeMissionInfoBlocksToGamercard()
    this.updateLeftPanelBlock()
    this.initTeamUnitsLeftView()
    getMplayersList()

    this.tmapBtnObj  = this.scene.findObject("tmap_btn")
    this.tmapHintObj = this.scene.findObject("tmap_hint")
    this.tmapIconObj = this.scene.findObject("tmap_icon")
    this.tmapRespawnBaseTimerObj = this.scene.findObject("tmap_respawn_base_timer")
    SecondsUpdater(this.tmapRespawnBaseTimerObj, (@(_obj, _params) this.updateRespawnBaseTimerText()).bindenv(this))
  }

  function updateRespawnBaseTimerText() {
    local text = ""
    if (this.isRespawn && this.respawnBasesList.len()) {
      let timeLeft = this.curRespawnBase ? getRespawnBaseTimeLeftById(this.curRespawnBase.id) : -1
      if (timeLeft > 0)
        text = loc("multiplayer/respawnBaseAvailableTime", { time = time.secondsToString(timeLeft) })
    }
    this.tmapRespawnBaseTimerObj.setValue(text)
  }

  function resetPointOfInterestMode() {
    setPointSettingMode(false)
    showObjById("POI_resetter", false, this.scene)
    let tacticalMapObj = this.scene.findObject("tactical-map")
    tacticalMapObj.cursor = "normal"
    let buttonImg = this.scene.findObject("hud_poi_img");
    buttonImg["background-image"] =  isPointOfInterestSet() ? "#ui/gameuiskin#map_interestpoint_delete.svg" : "#ui/gameuiskin#map_interestpoint.svg"
  }

  function initTeamUnitsLeftView() {
    if (!this.missionRules.hasCustomUnitRespawns())
      return

    let handler = loadHandler(gui_handlers.teamUnitsLeftView,
      { scene = this.scene.findObject("team_units_left_respawns"), missionRules = this.missionRules })
    this.registerSubHandler(handler)
    this.teamUnitsLeftWeak = handler?.weakref()
  }

  /*override*/ function onSceneActivate(show) {
    updateExtWatched({isInRespawnWnd = show})
    this.setOrdersEnabled(show && this.isSpectate)
    this.updateSpectatorRotationForced(show)
    this.updateTacticalMapUnitType(show ? null : false)
    base.onSceneActivate(show)
    setAllowMoveCenter(false)
    this.resetPointOfInterestMode()
  }

  function getOrderStatusObj() {
    let statusObj = this.scene.findObject("respawn_order_status")
    return checkObj(statusObj) ? statusObj : null
  }

  function isSpectator() {
    return getTblValue("spectator", this.mplayerTable, false)
  }

  function updateRespawnBasesStatus() { //return is isNoRespawns changed
    let wasIsNoRespawns = this.isNoRespawns
    if (this.isGTCooperative) {
      this.isNoRespawns = false
      this.updateNoRespawnText()
      return wasIsNoRespawns != this.isNoRespawns
    }

    this.noRespText = ""
    if (!g_mis_loading_state.isReadyToShowRespawn()) {
      this.isNoRespawns = true
      this.readyForRespawn = false
      this.noRespText = loc("multiplayer/loadingMissionData")
    }
    else {
      let isAnyBases = this.missionRules.isAnyUnitHaveRespawnBases()
      this.readyForRespawn = this.readyForRespawn && isAnyBases

      this.isNoRespawns = true
      if (!isAnyBases)
        this.noRespText = loc("multiplayer/noRespawnBasesLeft")
      else if (this.missionRules.isScoreRespawnEnabled && this.curSpawnScore < this.missionRules.getMinimalRequiredSpawnScore())
        this.noRespText = this.isRespawn ? loc("multiplayer/noSpawnScore") : ""
      else if (this.leftRespawns == 0)
        this.noRespText = loc("multiplayer/noRespawnsInMission")
      else if (!this.haveSlots)
        this.noRespText = loc("multiplayer/noCrewsLeft")
      else
        this.isNoRespawns = false
    }

    this.updateNoRespawnText()
    return wasIsNoRespawns != this.isNoRespawns
  }

  function updateCurSpawnScoreText() {
    let scoreObj = this.scene.findObject("gc_spawn_score")
    if (!scoreObj?.isValid())
      return
    let scoreText = this.missionRules.isScoreRespawnEnabled ? $"{loc("multiplayer/spawnScore")} {colorize("activeTextColor", this.curSpawnScore)}"
      : this.missionRules.isRageTokensRespawnEnabled ? $"{loc("multiplayer/rageTokens")} {colorize("activeTextColor", this.curSpawnRageTokens)}"
      : ""

    scoreObj.setValue(scoreText)
  }

  function updateSpawnScore(isOnInit = false) {
    if (!this.missionRules.isScoreRespawnEnabled ||
      !g_mis_loading_state.isReadyToShowRespawn())
      return

    let newSpawnScore = this.missionRules.getCurSpawnScore()
    if (!isOnInit && this.curSpawnScore == newSpawnScore)
      return

    this.curSpawnScore = newSpawnScore

    let newSpawnScoreMask = this.calcCrewSpawnScoreMask()
    if (this.crewsSpawnScoreMask != newSpawnScoreMask) {
      this.crewsSpawnScoreMask = newSpawnScoreMask
      if (!isOnInit && this.isRespawn)
        return this.reinitScreen({})
      else
        this.updateAllCrewSlots()
    }

    this.updateCurSpawnScoreText()
  }

  function calcCrewSpawnScoreMask() {
    local res = 0
    foreach (idx, crew in getCrewsListByCountry(get_local_player_country())) {
      let unit = getCrewUnit(crew)
      if (unit && shop_get_spawn_score(unit.name, "", []) >= this.curSpawnScore
          && this.missionRules.canRespawnOnUnitByRageTokens(unit))
        res = res | (1 << idx)
    }
    return res
  }

  function updateSpawnRageTokens(isOnInit = false) {
    if (!this.missionRules.isRageTokensRespawnEnabled ||
      !g_mis_loading_state.isReadyToShowRespawn())
      return

    let newSpawnRageTokens = this.missionRules.getSpawnRageTokens()
    if (!isOnInit && this.curSpawnRageTokens == newSpawnRageTokens)
      return

    this.curSpawnRageTokens = newSpawnRageTokens

    let newSpawnRageTokensMask = this.calcCrewSpawnRageTokensMask()
    if (this.crewsSpawnRageTokensMask != newSpawnRageTokensMask) {
      this.crewsSpawnRageTokensMask = newSpawnRageTokensMask
      if (!isOnInit && this.isRespawn)
        return this.reinitScreen({})
      else
        this.updateAllCrewSlots()
    }

    this.updateCurSpawnScoreText()
  }

  function calcCrewSpawnRageTokensMask() {
    local res = 0
    foreach (idx, crew in getCrewsListByCountry(get_local_player_country())) {
      let unit = getCrewUnit(crew)
      if (unit && this.missionRules.getUnitSpawnRageTokens(unit) >= this.curSpawnRageTokens)
        res = res | (1 << idx)
    }
    return res
  }

  function updateLeftRespawns() {
    this.leftRespawns = this.missionRules.getLeftRespawns()
    this.customStateCrewAvailableMask = this.missionRules.getCurCrewsRespawnMask()
  }

  function updateRespawnWhenChangedMissionRespawnBasesStatus() {
    let isStayOnrespScreenChanged = this.recountStayOnRespScreen()
    let isNoRespawnsChanged = this.updateRespawnBasesStatus()
    if (!this.stayOnRespScreen  && !this.isNoRespawns
        && (isStayOnrespScreenChanged || isNoRespawnsChanged)) {
      this.reinitScreen({})
      return
    }

    if (!this.updateRespawnBases())
      return

    this.reinitSlotbar()
    this.updateOptions(RespawnOptUpdBit.RESPAWN_BASES)
    this.updateButtons()
    this.updateApplyText()
    this.checkReady()
  }

  function onEventChangedMissionRespawnBasesStatus(_params) {
    this.doWhenActiveOnce("updateRespawnWhenChangedMissionRespawnBasesStatus")
  }

  function updateNoRespawnText() {
    let noRespObj = this.scene.findObject("txt_no_respawn_bases")
    if (checkObj(noRespObj)) {
      noRespObj.setValue(this.noRespText)
      noRespObj.show(this.isNoRespawns)
    }
  }

  function reinitScreen(params = {}) {
    this.setParams(params)
    this.initScreen()
  }

  function createRespawnOptions() {
    if (this.optionsFilled != null)
      return
    this.optionsFilled = array(respawnOptions.types.len(), false)

    let cells = respawnOptions.types
      .filter(@(o) o.isAvailableInMission())
      .map(@(o) {
          id = o.id
          label = o.getLabelText()
          cb = o.cb
          tooltipName = o.tooltipName
          isList = o.cType == optionControlType.LIST
          isCheckbox = o.cType == optionControlType.CHECKBOX
          isSlider = o.cType == optionControlType.SLIDER
        })

    let markup = handyman.renderCached("%gui/respawn/respawnOptions.tpl", { cells })
    this.guiScene.replaceContentFromText(this.scene.findObject("respawn_options_table"), markup, markup.len(), this)
  }

  function getOptionsParams() {
    let unit = this.getCurSlotUnit()
    return {
      handler = this
      unit
      isRandomUnit = this.isUnitRandom(unit)
      canChangeAircraft = this.canChangeAircraft
      respawnBasesList = this.respawnBasesList
      curRespawnBase = this.curRespawnBase
      haveRespawnBases = this.haveRespawnBases
      isRespawnBasesChanged = true
    }
  }

  function updateOptions(trigger, paramsOverride = {}) {
    this.isInUpdateLoadFuelOptions = true
    let optionsParams = this.getOptionsParams().__update(paramsOverride)
    foreach (idx, option in respawnOptions.types)
      this.optionsFilled[idx] = option.update(optionsParams, trigger, this.optionsFilled[idx]) || this.optionsFilled[idx]

    this.isInUpdateLoadFuelOptions = false
  }

  function initAircraftSelect() {
    if (showedUnit.value == null)
      showedUnit(getAircraftByName(respawnWndState.lastCaAircraft))

    log($"initScreen aircraft {respawnWndState.lastCaAircraft} showedUnit {showedUnit.value}")

    this.scene.findObject("CA_div").show(this.haveSlotbar)
    this.updateSessionWpBalance()

    if(this.missionRules instanceof AdditionalUnits)
      this.clearAdditionalUnits()

    if (this.haveSlotbar) {
      let needWaitSlotbar = !g_mis_loading_state.isReadyToShowRespawn() && !this.isSpectator()
      showObjById("slotbar_load_wait", needWaitSlotbar, this.scene)
      if (!this.isSpectator() && g_mis_loading_state.isReadyToShowRespawn()
          && (this.needRefreshSlotbarOnReinit || !this.slotbarWeak)) {
        this.slotbarInited = false
        this.beforeRefreshSlotbar()
        this.createSlotbar(this.getSlotbarParams().__update({
          slotbarHintText = getEventSlotbarHint(getRoomEvent(), get_local_player_country())
          draggableSlots = false
          showCrewUnseenIcon = false
        }), "flight_menu_bgd")
        this.afterRefreshSlotbar()
        this.slotReadyAtHostMask = getCrewSlotReadyMask()
        this.slotbarInited = true
        this.updateUnitOptions()

        if (this.canChangeAircraft)
          this.readyForRespawn = false

        if (this.isRespawn)
          setMousePointerInitialPos(this.getSlotbar()?.getCurrentCrewSlot().findObject("extra_info_block"))
      }
    }
    else {
      this.destroySlotbar()
      local airName = respawnWndState.lastCaAircraft
      if (this.isGTCooperative)
        airName = getTblValue("aircraftName", this.mplayerTable, "")
      let air = getAircraftByName(airName)
      if (air) {
        showedUnit(air)
        this.scene.findObject("air_info_div").show(true)
        let data = buildUnitSlot(air.name, air, {
          showBR        = hasFeature("SlotbarShowBattleRating")
          getEdiffFunc  = this.getCurrentEdiff.bindenv(this)
        })
        this.guiScene.replaceContentFromText(this.scene.findObject("air_item_place"), data, data.len(), this)
        fillUnitSlotTimers(this.scene.findObject("air_item_place").findObject(air.name), air)
      }
    }

    this.setRespawnCost()
    this.reset_mp_autostart_countdown();
  }

  function getSlotbarParams() {
    let playerCountry = get_local_player_country()
    return {
      singleCountry = playerCountry
      hasActions = false
      showNewSlot = false
      showEmptySlot = false
      toBattle = this.canChangeAircraft
      haveRespawnCost = this.missionRules.hasRespawnCost
      haveSpawnDelay = this.missionRules.isSpawnDelayEnabled
      totalSpawnScore = this.curSpawnScore
      sessionWpBalance = this.sessionWpBalance
      checkRespawnBases = true
      missionRules = this.missionRules
      hasExtraInfoBlock = true
      hasExtraInfoBlockTop = true
      showAdditionExtraInfo = true
      showCrewHintUnderSlot = true
      shouldSelectAvailableUnit = this.isRespawn
      customViewCountryData = { [playerCountry] = {
        icon = this.missionRules.getOverrideCountryIconByTeam(get_mp_local_team())
      } }

      beforeSlotbarSelect = this.beforeSlotbarSelect
      afterSlotbarSelect = this.onChangeUnit
      onSlotDblClick = Callback(@(_crew) this.onApply(), this)
      beforeFullUpdate = this.beforeRefreshSlotbar
      afterFullUpdate = this.afterRefreshSlotbar
      onSlotBattleBtn = this.onApply
    }
  }

  function updateSessionWpBalance() {
    if (!(this.missionRules.isWarpointsRespawnEnabled && this.isRespawn))
      return

    let info = get_cur_rank_info()
    let curWpBalance = get_cur_warpoints()
    this.sessionWpBalance = curWpBalance + info.cur_award_positive - info.cur_award_negative
  }

  function setRespawnCost() {
    let showWPSpend = this.missionRules.isWarpointsRespawnEnabled && this.isRespawn
    local wpBalance = ""
    if (showWPSpend) {
      this.updateSessionWpBalance()
      let info = get_cur_rank_info()
      let curWpBalance = get_cur_warpoints()
      let total = this.sessionWpBalance
      if (curWpBalance != total || (info.cur_award_positive != 0 && info.cur_award_negative != 0)) {
        let curWpBalanceString = Cost(curWpBalance).toStringWithParams({ isWpAlwaysShown = true })
        local curPositiveIncrease = ""
        local curNegativeDecrease = ""
        local color = info.cur_award_positive > 0 ? "@goodTextColor" : "@badTextColor"
        local curDifference = info.cur_award_positive
        if (info.cur_award_positive < 0) {
          curDifference = info.cur_award_positive - info.cur_award_negative
          color = "@badTextColor"
        }
        else if (info.cur_award_negative != 0)
          curNegativeDecrease = colorize("@badTextColor",
            Cost(-1 * info.cur_award_negative).toStringWithParams({ isWpAlwaysShown = true }))

        if (curDifference != 0)
          curPositiveIncrease = colorize(color, "".concat(curDifference > 0 ? "+" : "",
            Cost(curDifference).toStringWithParams({ isWpAlwaysShown = true })))

        let totalString = "".concat(" = ", colorize("@activeTextColor",
          Cost(total).toStringWithParams({ isWpAlwaysShown = true })))

        wpBalance = "".concat(curWpBalanceString, curPositiveIncrease, curNegativeDecrease, totalString)
      }
    }

    let balanceObj = this.getObj("gc_wp_respawn_balance")
    if (checkObj(balanceObj)) {
      local text = ""
      if (wpBalance != "")
        text = getCompoundedText(loc("multiplayer/wp_header"), wpBalance, "activeTextColor")
      balanceObj.setValue(text)
    }
  }

  function getRespawnWpTotalCost() {
    if (!this.missionRules.isWarpointsRespawnEnabled)
      return 0

    let air = this.getCurSlotUnit()
    let airRespawnCost = air ? get_unit_wp_to_respawn(air.name) : 0
    let weaponPrice = air ? this.getWeaponPrice(air.name, this.getSelWeapon()) : 0
    return airRespawnCost + weaponPrice
  }

  function isInAutoChangeDelay() {
    return get_time_msec() - this.prevUnitAutoChangeTimeMsec < this.delayAfterAutoChangeUnitMsec
  }

  function beforeRefreshSlotbar() {
    if (!this.isInAutoChangeDelay())
      this.prevAutoChangedUnit = this.getCurSlotUnit()
  }

  function afterRefreshSlotbar() {
    let curUnit = this.getCurSlotUnit()
    if (curUnit && curUnit != this.prevAutoChangedUnit)
      this.prevUnitAutoChangeTimeMsec = get_time_msec()

    this.updateApplyText()

    if (!this.needCheckSlotReady)
      return

    this.slotReadyAtHostMask = getCrewSlotReadyMask()
    this.slotsCostSum = this.getSlotsSpawnCostSumNoWeapon()
  }


  //hack: to check slotready changed
  function checkCrewAccessChange() {
    if (!this.getSlotbar()?.singleCountry || !this.slotbarInited)
      return

    local needReinitSlotbar = false

    let newMask = getCrewSlotReadyMask()
    if (newMask != this.slotReadyAtHostMask) {
      log("Error: is_crew_slot_was_ready_at_host or isCrewAvailableInSession have changed without cb. force reload slots")
      statsd.send_counter("sq.errors.change_disabled_slots", 1, { mission = get_current_mission_name() })
      needReinitSlotbar = true
    }

    let newSlotsCostSum = this.getSlotsSpawnCostSumNoWeapon()
    if (newSlotsCostSum != this.slotsCostSum) {
      log("Error: slots spawn cost have changed without cb. force reload slots")
      statsd.send_counter("sq.errors.changed_slots_spawn_cost", 1, { mission = get_current_mission_name() })
      needReinitSlotbar = true
    }

    if (needReinitSlotbar && this.getSlotbar())
      this.getSlotbar().forceUpdate()
  }

  function getSlotsSpawnCostSumNoWeapon() {
    local res = 0
    let crewsCountry = getCrewsList()?[this.getCurCrew()?.idCountry]
    if (!crewsCountry)
      return res

    foreach (idx, crew in crewsCountry.crews) {
      if ((this.slotReadyAtHostMask & (1 << idx)) == 0)
        continue
      let unit = getCrewUnit(crew)
      if (unit)
        res += shop_get_spawn_score(unit.name, "", [])
    }
    return res
  }

  function beforeSlotbarSelect(onOk, onCancel, selSlot) {
    if (!this.canChangeAircraft && this.slotbarInited) {
      onCancel()
      return
    }

    let crew = getCrew(selSlot.countryId, selSlot.crewIdInCountry)
    if (crew == null) {
      onCancel()
      return
    }

    let unit = getCrewUnit(crew)
    let isAvailable = needSkipAvailableCrewToSelect.value
      || ((isCrewAvailableInSession(crew, unit))
        && this.missionRules.isUnitEnabledBySessionRank(unit))
    if (unit && (isAvailable || !this.slotbarInited)) {  //can init wnd without any available aircrafts
      onOk()
      return
    }

    if (!::has_available_slots())
      return onOk()

    onCancel()

    let cantSpawnReason = this.getCantSpawnReason(crew)
    if (cantSpawnReason)
      showInfoMsgBox(cantSpawnReason.text, cantSpawnReason.id, true)
  }

  function isUnitRandom(unit) {
    return unit != null && this.missionRules?.getRandomUnitsGroupName(unit.name) != null
  }

  function onChangeUnit() {
    let unit = this.getCurSlotUnit()
    if (!unit)
      return

    if (this.slotbarInited)
      this.prevUnitAutoChangeTimeMsec = -1

    this.slotbarInited = true
    this.onAircraftUpdate()
  }

  function updateWeaponsSelector(isUnitChanged) {
    let unit = this.getCurSlotUnit()
    let isRandomUnit = this.isUnitRandom(unit)
    let shouldShowWeaponry = (!isRandomUnit || !this.isRespawn) && !getOverrideBullets(unit)
    let canChangeWeaponry = this.canChangeAircraft && shouldShowWeaponry

    let weaponsSelectorObj = this.scene.findObject("unit_weapons_selector")
    if (this.weaponsSelectorWeak) {
      this.weaponsSelectorWeak.setUnit(unit)
      this.weaponsSelectorWeak.setCanChangeWeaponry(canChangeWeaponry, this.isRespawn && !isUnitChanged)
      weaponsSelectorObj.show(shouldShowWeaponry)
      return
    }

    let handler = loadHandler(gui_handlers.unitWeaponsHandler,
                                       { scene = weaponsSelectorObj
                                         unit = unit
                                         canShowPrice = true
                                         canChangeWeaponry = canChangeWeaponry
                                       })

    this.weaponsSelectorWeak = handler.weakref()
    this.registerSubHandler(handler)
    weaponsSelectorObj.show(shouldShowWeaponry)
  }

  function getWeaponPrice(airName, weapon) {
    if (this.missionRules.isWarpointsRespawnEnabled
       && this.isRespawn
       && airName in usedPlanes
       && isInArray(weapon, usedPlanes[airName])) {
      let unit = getAircraftByName(airName)
      let count = getAmmoMaxAmountInSession(unit, weapon, AMMO.WEAPON) - getAmmoAmount(unit, weapon, AMMO.WEAPON)
      return (count * wp_get_cost2(airName, weapon))
    }
    return 0
  }

  function onSmokeTypeUpdate(obj) {
    this.checkReady(obj)
    this.updateOptions(RespawnOptUpdBit.SMOKE_TYPE)
  }

  function onRespawnbaseOptionUpdate(obj) {
    if (!this.isRespawn)
      return

    let idx = checkObj(obj) ? obj.getValue() : 0
    let spawn = this.respawnBasesList?[idx]
    if (!spawn)
      return

    if (this.curRespawnBase != spawn) //selected by user
      respawnBases.selectBase(this.getCurSlotUnit(), spawn)
    this.curRespawnBase = spawn
    selectRespawnBase(this.curRespawnBase.mapId)
    this.updateRespawnBaseTimerText()
    this.checkReady()
  }

  function updateTacticalMapHint() {
    local hint = ""
    local hintIcon = showConsoleButtons.value ? gamepadIcons.getTexture("r_trigger") : "#ui/gameuiskin#mouse_left"
    local highlightSpawnMapId = -1
    if (!this.isRespawn) {
      hint = isAllowedMoveCenter() ? colorize("activeTextColor", loc("hints/move_map_hint"))
                                   : colorize("activeTextColor", loc("voice_message_attention_to_point_2"))
    }
    else {
      let coords = ::get_mouse_relative_coords_on_obj(this.tmapBtnObj)
      if (!coords)
        hintIcon = ""
      else if (isAllowedMoveCenter())
        hint = colorize("activeTextColor", loc("hints/move_map_hint"))
      else if (!this.canChooseRespawnBase) {
        hint = colorize("commonTextColor", loc("guiHints/respawn_base/choice_disabled"))
        hintIcon = ""
      }
      else {
        let spawnId = coords ? getRespawnBase(coords[0], coords[1]) : respawnBases.MAP_ID_NOTHING
        if (spawnId != respawnBases.MAP_ID_NOTHING)
          foreach (spawn in this.respawnBasesList)
            if (spawn.id == spawnId && spawn.isMapSelectable) {
              highlightSpawnMapId = spawn.mapId
              hint = colorize("userlogColoredText", spawn.getTitle())
              if (spawnId == this.curRespawnBase?.id)
                hint = "".concat(hint, colorize("activeTextColor", loc("ui/parentheses/space",
                  { text = loc(this.curRespawnBase.isAutoSelected ? "ui/selected_auto" : "ui/selected") })))
              break
            }

        if (!hint.len()) {
          hint = colorize("activeTextColor", loc("guiHints/respawn_base/choice_enabled"))
          hintIcon = ""
        }
      }
    }

    highlightRespawnBase(highlightSpawnMapId)

    this.tmapHintObj.setValue(hint)
    this.tmapIconObj["background-image"] = hintIcon
  }

  function onTacticalmapClick(_obj) {
    if (!this.isRespawn || !checkObj(this.scene) || !this.canChooseRespawnBase)
      return

    let coords = ::get_mouse_relative_coords_on_obj(this.tmapBtnObj)
    let spawnId = coords ? getRespawnBase(coords[0], coords[1]) : respawnBases.MAP_ID_NOTHING

    local selIdx = -1
    if (spawnId != -1)
      foreach (idx, spawn in this.respawnBasesList)
        if (spawn.id == spawnId && spawn.isMapSelectable) {
          selIdx = idx
          break
        }

    if (selIdx != -1) {
      let optionObj = this.scene.findObject("respawn_base")
      if (checkObj(optionObj))
        optionObj.setValue(selIdx)
    }
  }

  function onOtherOptionUpdate(obj) {
    this.reset_mp_autostart_countdown();
    if (!obj)
      return

    let air = this.getCurSlotUnit()
    if (!air)
      return

    unitNameForWeapons.set(air.name)

    let option = respawnOptions.get(obj?.id)
    if (option.userOption != -1) {
      let userOpt = get_option(option.userOption)
      let value = obj.getValue()
      set_option(userOpt.type, value, userOpt)
    }
  }

  function updateRespawnBases() {
    let unit = this.getCurSlotUnit()
    if (!unit)
      return false

    let currBasesList = clone this.respawnBasesList

    if (this.canChangeAircraft) {
      let crew = this.getCurCrew()
      setSelectedUnitInfo(unit.name, crew.idInCountry)
      let rbData = respawnBases.getRespawnBasesData(unit)
      this.curRespawnBase = rbData.selBase
      this.respawnBasesList = rbData.basesList
      this.haveRespawnBases = rbData.hasRespawnBases
      this.canChooseRespawnBase = rbData.canChooseRespawnBase
    }
    else {
      this.curRespawnBase = respawnBases.getSelectedBase()
      this.respawnBasesList = this.curRespawnBase ? [this.curRespawnBase] : []
      this.haveRespawnBases = this.curRespawnBase != null
      this.canChooseRespawnBase = false
    }

    return !u.isEqual(this.respawnBasesList, currBasesList)
  }


  function showRespawnTr(show) {
    let obj = this.scene.findObject("respawn_base_tr")
    if (checkObj(obj))
      obj.show(show)
  }

  function updateUnitOptions() {
    let unit = this.getCurSlotUnit()
    local isUnitChanged = false
    if (unit) {
      isUnitChanged = unitNameForWeapons.get() != unit.name
      unitNameForWeapons.set(unit.name)
      showedUnit(unit)

      if (isUnitChanged || this.isFirstUnitOptionsInSession)
        this.preselectUnitWeapon(unit)
    }

    this.updateTacticalMapUnitType()

    this.updateWeaponsSelector(isUnitChanged)
    let isRespawnBasesChanged = this.updateRespawnBases()
    this.updateOptions(RespawnOptUpdBit.UNIT_ID, { isRespawnBasesChanged })
    this.isFirstUnitOptionsInSession = false
    this.updateLeftPanelBlock()
    this.updateSkinOptionTooltipId()
    this.universalSpareUidForRespawn = ""

    if(this.missionRules instanceof AdditionalUnits && unit != null)
      this.fillAdditionalUnits(unit.name)
  }

  function fillAdditionalUnits(unitName) {
    let units = createAdditionalUnitsViewData(unitName)
    let data = handyman.renderCached("%gui/respawn/additionalUnit.tpl", { units })
    let list = this.scene.findObject("additionalUnits")
    this.guiScene.replaceContentFromText(list, data, data.len(), this)
  }

  function clearAdditionalUnits() {
    let list = this.scene.findObject("additionalUnits")
    this.guiScene.replaceContentFromText(list, "", 0, this)
    this.scene.findObject("additionalUnitsNest").show(false)
  }


  function preselectUnitWeapon(unit) {
    if (unit && this.isUnitRandom(unit)) {
      setLastWeapon(unit.name, this.missionRules.getWeaponForRandomUnit(unit, "forceWeapon"))
      return
    }

    if (!this.missionRules.hasWeaponLimits())
      return

    foreach (weapon in (unit?.getWeapons() ?? []))
      if (isWeaponVisible(unit, weapon)
          && isWeaponEnabled(unit, weapon)
          && this.missionRules.getUnitWeaponRespawnsLeft(unit, weapon) > 0) { //limited and available
       setLastWeapon(unit.name, weapon.name)
       break
     }
  }

  function updateTacticalMapUnitType(isMapForSelectedUnit = null) {
    local hudType = HUD_TYPE_UNKNOWN
    if (this.isRespawn) {
      if (isMapForSelectedUnit == null)
        isMapForSelectedUnit = !this.isSpectate
      let unit = isMapForSelectedUnit ? this.getCurSlotUnit() : null
      if (unit)
        hudType = unit.unitType.hudTypeCode
    }
    else
      hudType = isForcedHudType() ? getCurHudType() : this.getCurSlotUnit()?.unitType.hudTypeCode ?? HUD_TYPE_UNKNOWN

    set_tactical_map_hud_type(hudType)
    let buttonImg = this.scene.findObject("hud_type_img");
    buttonImg["background-image"] = (hudType == HUD_TYPE_AIRPLANE) ? "#ui/gameuiskin#objective_tank.svg" : "#ui/gameuiskin#objective_fighter.svg"
  }

  function onDestroy() {
    this.updateTacticalMapUnitType(false)
  }

  function onAircraftUpdate() {
    this.updateUnitOptions()
    this.checkReady()
  }

  function getSelWeapon() {
    let unit = this.getCurSlotUnit()
    if (unit)
      return getLastWeapon(unit.name)
    return null
  }

  function getSelBulletsList() {
    let unit = this.getCurSlotUnit()
    if (unit)
      return getUnitLastBullets(unit)
    return null
  }

  function getSelSkin() {
    let unit = this.getCurSlotUnit()
    let obj = this.scene.findObject("skin")
    if (unit == null || !checkObj(obj))
      return null
    let skinOptions = getSkinsOption(unit.name)
    return skinOptions.values?[obj.getValue()] ?? skinOptions?.autoSkin
  }

  function doSelectAircraftSkipAmmo(requestData = null) {
    if (this.requestInProgress)
      return

    requestData = requestData ?? this.getSelectedRequestData(false)
    if (!requestData)
      return

    if (!this.checkCurUnitSkin(this.doSelectAircraftSkipAmmo))
      return

    this.requestAircraftAndWeapon(requestData)
    if (this.scene.findObject("skin").getValue() > 0)
      reqUnlockByClient("non_standard_skin")

    actionBarInfo.cacheActionDescs(requestData.name)

    setShowUnit(getAircraftByName(requestData.name))
  }

  function doSelectAircraft() {
    if (this.requestInProgress)
      return

    let requestData = this.getSelectedRequestData(false)
    if (!requestData)
      return

    let unit = getAircraftByName(requestData.name)
    let crew = this.getCurCrew()
    if (crew != null && isRespawnWithUniversalSpare(crew, unit) && requestData.spareUid == "") {
      let cb = Callback(function(item) {
        this.universalSpareUidForRespawn = item.uids[0]
        this.doSelectAircraft()
      }, this)
      openRespawnSpareWnd(unit, cb, this.getSlotbar()?.getCurrentCrewSlot())
      return
    }

    if (!this.checkCurAirAmmo(this.doSelectAircraftSkipAmmo))
      return

    this.doSelectAircraftSkipAmmo(requestData)
  }

  function getSelectedRequestData(silent = true) {
    let air = this.getCurSlotUnit()
    if (!air) {
      log("getCurSlotUnit() returned null?")
      return null
    }

    if (this.prevAutoChangedUnit && this.prevAutoChangedUnit != air && this.isInAutoChangeDelay()) {
      if (!silent) {
        let msg = this.missionRules.getSpecialCantRespawnMessage(this.prevAutoChangedUnit)
        if (msg)
          addPopup(null, msg)
        this.prevUnitAutoChangeTimeMsec = -1
      }
      return null
    }

    let crew = this.getCurCrew()
    let weapon = getLastWeapon(air.name)
    let skin = getRealSkin(air.name)
    setCurSkinToHangar(air.name)
    if (!weapon || !skin) {
      log("no weapon or skin selected?")
      return null
    }

    let cantSpawnReason = this.getCantSpawnReason(crew, silent)
    if (!needSkipAvailableCrewToSelect.value && cantSpawnReason) {
      if (!silent)
        showInfoMsgBox(cantSpawnReason.text, cantSpawnReason.id, true)
      return null
    }

    let res = {
      name = air.name
      weapon = weapon
      skin = skin
      respBaseId = this.curRespawnBase?.id ?? -1
      idInCountry = crew.idInCountry
      spareUid = this.universalSpareUidForRespawn
    }

    local bulletInd = 0;
    let bulletGroups = this.weaponsSelectorWeak ? this.weaponsSelectorWeak.bulletsManager.getBulletsGroups() : []
    foreach (_groupIndex, bulGroup in bulletGroups) {
      if (!bulGroup.active)
        continue
      let modName = bulGroup.selectedName
      if (!modName)
        continue

      let count = bulGroup.bulletsCount
      if (bulGroup.canChangeBulletsCount() && bulGroup.bulletsCount <= 0)
        continue

      if (getModificationByName(air, modName)) //!default bullets (fake)
        res[$"bullets{bulletInd}"] <- modName
      else
        res[$"bullets{bulletInd}"] <- ""
      res[$"bulletCount{bulletInd}"] <- count
      res[$"bulletsWeapon{bulletInd}"] <- bulGroup.getWeaponName()
      bulletInd++;
    }
    while (bulletInd < BULLETS_SETS_QUANTITY) {
      res[$"bullets{bulletInd}"] <- ""
      res[$"bulletCount{bulletInd}"] <- 0
      res[$"bulletsWeapon{bulletInd}"] <- ""
      bulletInd++;
    }

    let editSlotbarBullets = getOverrideBullets(air);
    if (editSlotbarBullets)
      for (local i = 0; i < BULLETS_SETS_QUANTITY; i++) {
        res[$"bullets{i}"] = editSlotbarBullets?[$"bullets{i}"] ?? ""
        res[$"bulletCount{i}"] = editSlotbarBullets?[$"bulletsCount{i}"] ?? 0
        res[$"bulletsWeapon{i}"] <- editSlotbarBullets?[$"bulletsWeapon{i}"] ?? ""
      }

    let optionsParams = this.getOptionsParams()

    foreach (option in respawnOptions.types) {
      if (!option.needSetToReqData || !option.isVisible(optionsParams))
        continue

      let opt = get_option(option.userOption)
      if (opt.controlType == optionControlType.LIST)
        res[opt.id] <- opt.values?[opt.value]
      else
        res[opt.id] <- opt.value
    }

    return res
  }

  function getCantSpawnReason(crew, silent = true) {
    let unit = getCrewUnit(crew)
    if (unit == null)
      return null

    let ruleMsg = this.missionRules.getSpecialCantRespawnMessage(unit)
    if (!u.isEmpty(ruleMsg))
      return { text = ruleMsg, id = "cant_spawn_by_mission_rules" }

    if (this.isRespawn && !this.missionRules.isUnitEnabledBySessionRank(unit))
      return {
        text = loc("multiplayer/lowVehicleRank",
          { minSessionRank = calcBattleRatingFromRank(this.missionRules.getMinSessionRank()) })
        id = "low_vehicle_rank"
      }

    if (! this.haveRespawnBases)
      return { text = loc("multiplayer/noRespawnBasesLeft"), id = "no_respawn_bases" }

    if (this.missionRules.isWarpointsRespawnEnabled && this.isRespawn) {
      let respawnPrice = this.getRespawnWpTotalCost()
      if (respawnPrice > 0 && respawnPrice > this.sessionWpBalance)
        return { text = loc("msg/not_enought_warpoints_for_respawn"), id = "not_enought_wp" }
    }

    if (this.missionRules.isScoreRespawnEnabled && this.isRespawn &&
      (this.curSpawnScore < shop_get_spawn_score(unit.name, this.getSelWeapon() ?? "", this.getSelBulletsList() ?? [])))
        return { text = loc("multiplayer/noSpawnScore"), id = "not_enought_score" }

    if (this.isRespawn && !this.missionRules.canRespawnOnUnitByRageTokens(unit))
      return { text = loc("multiplayer/noRageTokens"), id = "not_enought_score" }

    if (this.missionRules.isSpawnDelayEnabled && this.isRespawn) {
      let slotDelay = get_slot_delay(unit.name)
      if (slotDelay > 0) {
        let text = loc("multiplayer/slotDelay", { time = time.secondsToString(slotDelay) })
        return { text = text, id = "wait_for_slot_delay" }
      }
    }

    if (!isCrewAvailableInSession(crew, unit, !silent)) {
      local locId = "not_available_aircraft"
      if ((getRoomUnitTypesMask() & (1 << getEsUnitType(unit))) != 0)
        locId = "crew_not_available"
      return { text = getNotAvailableUnitByBRText(unit) || loc(locId),
        id = "crew_not_available" }
    }

    if (!silent)
      log($"Try to select aircraft {unit.name}")

    if (!is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, !silent)) {
      if (!silent)
        log($"is_crew_slot_was_ready_at_host return false for {crew.idInCountry} - {unit.name}")
      return { text = loc("aircraft_not_repaired"), id = "aircraft_not_repaired" }
    }

    return null
  }

  function requestAircraftAndWeapon(requestData) {
    if (this.requestInProgress)
      return

    set_aircraft_accepted_cb(this, this.aircraftAcceptedCb);
    let _taskId = requestAircraftAndWeaponWithSpare(requestData, requestData.idInCountry,
      requestData.respBaseId, requestData.spareUid)
    if (_taskId < 0)
      set_aircraft_accepted_cb(null, null);
    else {
      this.requestInProgress = true
      this.showTaskProgressBox(loc("charServer/purchase0"), function() { this.requestInProgress = false })

      this.lastRequestData = requestData
    }
  }

  function aircraftAcceptedCb(result) {
    set_aircraft_accepted_cb(null, null)
    this.destroyProgressBox()
    this.requestInProgress = false

    if (!this.isValid())
      return

    this.reset_mp_autostart_countdown()
    if (result == ERR_ACCEPT) {
      this.onApplyAircraft(this.lastRequestData)
      ::update_gamercards() //update balance
      return
    }

    if (result == ERR_REJECT_SESSION_FINISHED || result == ERR_REJECT_DISCONNECTED)
      return

    log($"Respawn Erorr: aircraft accepted cb result = {result}, on request:")
    debugTableData(this.lastRequestData)
    this.lastRequestData = null
    if (!checkObj(this.guiScene["char_connecting_error"]))
      showInfoMsgBox(loc($"changeAircraftResult/{result}"), "char_connecting_error")
  }

  function onApplyAircraft(requestData) {
    if (requestData)
      respawnWndState.lastCaAircraft = requestData.name

    this.checkReady()
    if (this.readyForRespawn)
      this.onApply()
  }

  function checkReady(obj = null) {
    this.onOtherOptionUpdate(obj)

    this.readyForRespawn = this.lastRequestData != null
      && u.isEqual(this.lastRequestData, this.getSelectedRequestData())

    if (!this.readyForRespawn && this.isApplyPressed)
      if (!this.doRespawnCalled)
        this.isApplyPressed = false
      else
        log("Something has changed in the aircraft selection, but too late - do_respawn was called before.")
    this.updateApplyText()
  }

  function updateFuelCustomValueText(value) {
    let customOption = get_option(USEROPT_FUEL_AMOUNT_CUSTOM)
    let customTextValueObj = this.scene.findObject($"value_{customOption.id}")
    customTextValueObj.setValue(customOption.getValueLocText(value))
  }

  function onLoadFuelChange(obj) {
    if(this.isInUpdateLoadFuelOptions)
      return

    this.isInUpdateLoadFuelOptions = true

    let value = obj.getValue()

    let option = get_option(USEROPT_LOAD_FUEL_AMOUNT)
    let fuelAmount = option.values[value]
    let customOption = get_option(USEROPT_FUEL_AMOUNT_CUSTOM)
    let customObj = this.scene.findObject(customOption.id)
    customObj.setValue(fuelAmount)
    this.checkReady(obj)

    this.isInUpdateLoadFuelOptions = false
  }

  function onLoadFuelCustomChange(obj) {

    let newFuelAmount = obj.getValue().tointeger()
    this.updateFuelCustomValueText(newFuelAmount)

    if(this.isInUpdateLoadFuelOptions)
      return

    this.isInUpdateLoadFuelOptions = true
    set_option(USEROPT_FUEL_AMOUNT_CUSTOM, newFuelAmount)
    let option = get_option(USEROPT_LOAD_FUEL_AMOUNT)
    let newValue = option.values.len() - 1
    set_option(USEROPT_LOAD_FUEL_AMOUNT, newValue)

    let fuelAmountObj = this.scene.findObject(option.id)
    fuelAmountObj.setValue(newValue)
    this.checkReady(obj)
    this.isInUpdateLoadFuelOptions = false
  }

  function onChangeRadarModeSelectedUnit(obj) {
    set_option_radar_name(unitNameForWeapons.get(), getLastWeapon(unitNameForWeapons.get()), obj.getValue())

    this.updateOptions(RespawnOptUpdBit.UNIT_WEAPONS)
  }

  function onChangeRadarScanRangeSelectedUnit(obj) {
    set_option_radar_scan_pattern_name(unitNameForWeapons.get(), getLastWeapon(unitNameForWeapons.get()), obj.getValue())

    this.updateOptions(RespawnOptUpdBit.UNIT_WEAPONS)
  }

  function onSkinSelect(obj = null) {
    this.checkReady(obj)
    this.updateSkinOptionTooltipId()
  }

  function updateApplyText() {
    let unit = this.getCurSlotUnit()
    let crew = this.getCurCrew()
    local isAvailResp = this.haveRespawnBases || this.isGTCooperative
    local tooltipText = ""
    local tooltipEndText = ""
    let infoTextsArr = []
    let costTextArr = []
    local shortCostText = "" //for slot battle button

    if (this.isApplyPressed)
      this.applyText = loc("mainmenu/btnCancel")
    else {
      this.applyText = loc("mainmenu/toBattle")
      tooltipText = loc("mainmenu/selectAircraftTooltip")
      if (is_platform_pc)
        tooltipEndText = format(" [%s]", loc("key/Enter"))

      if (this.haveSlotbar) {
        if (crew != null && (isRespawnWithUniversalSpare(crew, unit) || isSpareAircraftInSlot(crew.idInCountry))) {
          shortCostText = loc("icon/universalSpare")
          costTextArr.append(shortCostText)
        }

        if (this.missionRules.isScoreRespawnEnabled && unit) {
          let curScore = shop_get_spawn_score(unit.name, this.getSelWeapon() ?? "", this.getSelBulletsList() ?? [])
          isAvailResp = isAvailResp && (curScore <= this.curSpawnScore)
          if (curScore > 0)
            costTextArr.append(loc("shop/spawnScore", { cost = curScore }))
        }

        let reqUnitSpawnRageTokens = unit != null ? this.missionRules.getUnitSpawnRageTokens(unit) : 0
        if (reqUnitSpawnRageTokens > 0) {
          isAvailResp = isAvailResp && reqUnitSpawnRageTokens <= this.curSpawnRageTokens
          costTextArr.append(loc("shop/spawnScore", { cost = reqUnitSpawnRageTokens }))
        }

        if (this.leftRespawns > 0)
          infoTextsArr.append(loc("respawn/leftRespawns", { num = this.leftRespawns.tostring() }))

        infoTextsArr.append(this.missionRules.getRespawnInfoTextForUnit(unit))
        isAvailResp = isAvailResp && this.missionRules.isRespawnAvailable(unit)
      }
    }

    local isCrewDelayed = false
    if (this.missionRules.isSpawnDelayEnabled && unit) {
      let slotDelay = get_slot_delay(unit.name)
      isCrewDelayed = slotDelay > 0
    }

    //******************** combine final texts ********************************

    local battleBtnText = this.applyText //for slot battle button

    if (shortCostText.len()) {
      let shortToBattleText = loc("mainmenu/toBattle/short")
      battleBtnText = $"{shortToBattleText} {shortCostText}"
    }

    let comma = loc("ui/comma")

    let costText = comma.join(costTextArr, true)
    if (costText.len())
      this.applyText = "".concat(this.applyText, loc("ui/parentheses/space", { text = costText }))

    let infoText = comma.join(infoTextsArr, true)
    if (infoText.len())
      this.applyText = "".concat(this.applyText, loc("ui/parentheses/space", { text = infoText }))

    //******************  uodate buttons objects ******************************

    foreach (btnId in this.mainButtonsId) {
      let buttonSelectObj = setColoredDoubleTextToButton(this.scene.findObject("nav-help"), btnId, this.applyText)
      buttonSelectObj.tooltip = this.isSpectate ? tooltipText : "".concat(tooltipText, tooltipEndText)
      buttonSelectObj.isCancel = this.isApplyPressed ? "yes" : "no"
      buttonSelectObj.inactiveColor = (isAvailResp && !isCrewDelayed) ? "no" : "yes"

      if (shortCostText.len() && !this.isApplyPressed)
        buttonSelectObj["visualStyle"] = "purchase"
      else
        buttonSelectObj["visualStyle"] = ""
    }

    let slotObj = crew && getSlotObj(this.scene, crew.idCountry, crew.idInCountry)
    let slotBtnObj = setColoredDoubleTextToButton(slotObj, "slotBtn_battle", battleBtnText)
    if (slotBtnObj) {
      slotBtnObj.isCancel = this.isApplyPressed ? "yes" : "no"
      slotBtnObj.inactiveColor = (isAvailResp && !isCrewDelayed) ? "no" : "yes"
      if (shortCostText.len() && !this.isApplyPressed)
        slotBtnObj["visualStyle"] = "purchase"
    }

    this.showRespawnTr(isAvailResp && !isCrewDelayed)
  }

  function setApplyPressed() {
    this.isApplyPressed = !this.isApplyPressed
    this.updateApplyText()
  }

  function onApply() {
    if (this.doRespawnCalled)
      return

    if (!this.haveSlots || this.leftRespawns == 0) {
      if (this.isNoRespawns)
        addPopup(null, this.noRespText)
      return
    }

    this.reset_mp_autostart_countdown()
    this.checkReady()
    if (this.readyForRespawn) {
      if (this.isApplyPressed && this.universalSpareUidForRespawn != "")
        this.universalSpareUidForRespawn = ""
      this.setApplyPressed()
    }
    else if (this.canChangeAircraft && !this.isApplyPressed && canRequestAircraftNow())
      this.doSelectAircraft()
  }

  function checkCurAirAmmo(applyFunc) {
    let bulletsManager = this.weaponsSelectorWeak?.bulletsManager
    if (!bulletsManager)
      return true

    if (bulletsManager.canChangeBulletsCount())
      return bulletsManager.checkChosenBulletsCount(Callback(@() applyFunc(), this))

    let air = this.getCurSlotUnit()
    if (!air)
      return true

    let textArr = []
    local zero = false;

    let weapon = this.getSelWeapon()
    if (weapon) {
      let weaponText = getAmmoAmountData(air, weapon, AMMO.WEAPON)
      if (weaponText.warning) {
        textArr.append("".concat(getWeaponNameText(air.name, false, -1, loc("ui/comma")), weaponText.text))
        if (!weaponText.amount)
          zero = true
      }
    }


    let bulletGroups = bulletsManager.getBulletsGroups()
    foreach (_groupIndex, bulGroup in bulletGroups) {
      if (!bulGroup.active)
        continue
      let modifName = bulGroup.selectedName
      if (modifName == "")
        continue

      let modificationText = getAmmoAmountData(air, modifName, AMMO.MODIFICATION)
      if (!modificationText.warning)
        continue

      textArr.append("".concat(getModificationName(air, modifName), modificationText.text))
      if (!modificationText.amount)
        zero = true
    }

    if (!zero && !::is_game_mode_with_spendable_weapons())
      return true

    if (textArr.len() && (zero || !get_gui_option(USEROPT_SKIP_WEAPON_WARNING))) { //skip warning only
      loadHandler(gui_handlers.WeaponWarningHandler,
        {
          parentHandler = this
          message = loc(zero ? "msgbox/zero_ammo_warning" : "controls/no_ammo_left_warning")
          list = "\n".join(textArr)
          ableToStartAndSkip = !zero
          onStartPressed = applyFunc
        })
      return false
    }
    return true
  }

  function checkCurUnitSkin(applyFunc) {
    let unit = this.getCurSlotUnit()
    if (!unit)
      return true

    let skinId = this.getSelSkin()
    if (!skinId)
      return true

    let diffCode = get_mission_difficulty_int()

    let curPresetId = contentPreset.getCurPresetId(diffCode)
    let newPresetId = contentPreset.getPresetIdBySkin(diffCode, unit.name, skinId)
    if (newPresetId == curPresetId)
      return true

    if (contentPreset.isAgreed(diffCode, newPresetId)) { // User already agreed to set this or higher preset.
      contentPreset.setPreset(diffCode, newPresetId, false)
      return true
    }

    loadHandler(gui_handlers.SkipableMsgBox, {
      parentHandler = this
      onStartPressed = function() {
        contentPreset.setPreset(diffCode, newPresetId, true)
        applyFunc()
      }
      message = " ".concat(
        loc("msgbox/optionWillBeChanged/content_allowed_preset"),
        loc("msgbox/optionWillBeChanged", {
          name     = colorize("userlogColoredText", loc("options/content_allowed_preset"))
          oldValue = colorize("userlogColoredText", loc($"content/tag/{curPresetId}"))
          newValue = colorize("userlogColoredText", loc($"content/tag/{newPresetId}"))
        }),
        loc("msgbox/optionWillBeChanged/comment"))
    })
    return false
  }

  function use_autostart() {
    if (!(get_game_type() & GT_AUTO_SPAWN))
      return false;
    let crew = this.getCurCrew()
    if (this.isSpectate || !crew || !respawnWndState.beforeFirstFlightInSession || this.missionRules.isWarpointsRespawnEnabled)
      return false;

    let air = this.getCurSlotUnit()
    if (!air)
      return false

    return !isSpareAircraftInSlot(crew.idInCountry) &&
      is_crew_slot_was_ready_at_host(crew.idInCountry, air.name, false)
  }

  function onUpdate(_obj, dt) {
    if (this.needCheckSlotReady)
      this.checkCrewAccessChange()

    this.updateSwitchSpectatorTarget(dt)
    if (this.missionRules.isSpawnDelayEnabled)
      this.updateSlotDelays()

    this.updateSpawnScore(false)
    this.updateSpawnRageTokens(false)

    this.autostartTimer += dt;

    let countdown = get_mp_respawn_countdown()
    this.updateCountdown(countdown)

    this.updateTimeToKick(dt)
    this.updateTables(dt)
    this.setInfo()

    this.updateTacticalMapHint()

    if (this.use_autostart() && this.get_mp_autostart_countdown() <= 0 && !this.isApplyPressed) {
      this.onApply()
      return
    }

    let tacticalMapObj = this.scene.findObject("tactical-map")
    tacticalMapObj.cursor =  isAllowedMoveCenter() ? "moveArrowCursor" : isPointSettingMode() ? "pointOfInterest" : "normal"

    let buttonImg = this.scene.findObject("hud_poi_img");
    buttonImg["background-image"] =  isPointOfInterestSet() ? "#ui/gameuiskin#map_interestpoint_delete.svg" : "#ui/gameuiskin#map_interestpoint.svg"

    if (this.isApplyPressed) {
      if (this.checkSpawnInterrupt())
        return

      if (canRespawnCaNow() && countdown < -100) {
        disable_flight_menu(false)
        if (this.respawnRecallTimer < 0) {
          this.respawnRecallTimer = 3.0
          this.doRespawn()
        }
        else
          this.respawnRecallTimer -= dt
      }
    }

    if (this.isRespawn && this.isSpectate)
      this.updateSpectatorName()

    if (this.isRespawn && get_mission_status() > MISSION_STATUS_RUNNING)
      quit_to_debriefing()
  }

  function doRespawn() {
    log("doRespawnPlayer called")
    respawnWndState.beforeFirstFlightInSession = false
    this.doRespawnCalled = doRespawnPlayer()
    if (!this.doRespawnCalled) {
      this.onApply()
      showInfoMsgBox(loc("msg/error_when_try_to_respawn"), "error_when_try_to_respawn", true)
      return
    }

    broadcastEvent("PlayerSpawn", this.lastRequestData)
    if (this.lastRequestData) {
      if (this.lastRequestData.spareUid != "") {
        markUsedItemCount(itemType.UNIVERSAL_SPARE, this.lastRequestData.spareUid)
        this.universalSpareUidForRespawn = ""
      }
      this.lastSpawnUnitName = this.lastRequestData.name
      let requestedWeapon = this.lastRequestData.weapon
      if (!(this.lastSpawnUnitName in usedPlanes))
        usedPlanes[this.lastSpawnUnitName] <- []
      if (!isInArray(requestedWeapon, usedPlanes[this.lastSpawnUnitName]))
        usedPlanes[this.lastSpawnUnitName].append(requestedWeapon)
      this.lastRequestData = null

      if(this.missionRules instanceof AdditionalUnits)
        setUnitUsed(this.lastSpawnUnitName)
    }
    this.updateButtons()
    selectRespawnBase(-1)
  }

  function checkSpawnInterrupt() {
    if (!this.doRespawnCalled || !this.isRespawn)
      return false

    let unit = getAircraftByName(this.lastRequestData?.name ?? this.lastSpawnUnitName)
    if (!unit || this.missionRules.getUnitLeftRespawns(unit) != 0)
      return false

    this.guiScene.performDelayed(this, function() {
      if (!this.doRespawnCalled)
        return

      let msg = loc("multiplayer/noTeamUnitLeft",
                        { unitName = this.lastSpawnUnitName.len() ? getUnitName(this.lastSpawnUnitName) : "" })
      this.reinitScreen()
      addPopup(null, msg)
    })
    return true
  }

  function updateSlotDelays() {
    if (!checkObj(this.scene))
      return

    let crews = getCrewsListByCountry(get_local_player_country())
    let currentIdInCountry = this.getCurCrew()?.idInCountry
    foreach (crew in crews) {
      let idInCountry = crew.idInCountry
      if (!(idInCountry in this.slotDelayDataByCrewIdx))
        this.slotDelayDataByCrewIdx[idInCountry] <- { slotDelay = -1, updateTime = 0 }
      let slotDelayData = this.slotDelayDataByCrewIdx[idInCountry]

      let prevSlotDelay = getTblValue("slotDelay", slotDelayData, -1)
      let curSlotDelay = get_slot_delay_by_slot(idInCountry)
      if (prevSlotDelay != curSlotDelay) {
        slotDelayData.slotDelay = curSlotDelay
        slotDelayData.updateTime = get_time_msec()
      }
      else if (curSlotDelay < 0)
        continue

      if (currentIdInCountry == idInCountry)
        this.updateApplyText()
      this.updateCrewSlot(crew)
    }

    this.getSlotbar()?.updateMissionInfoVisibility()
  }

  //only for crews of current country
  function updateCrewSlot(crew) {
    let unit = getCrewUnit(crew)
    if (!unit)
      return

    let idInCountry = crew.idInCountry
    let countryId = crew.idCountry
    let slotObj = getSlotObj(this.scene, countryId, idInCountry)
    if (!slotObj)
      return

    let params = this.getSlotbarParams().__update({
      crew
      curSlotIdInCountry = idInCountry
      curSlotCountryId = countryId
      unlocked = isUnitUnlockedInSlotbar(unit, crew, get_local_player_country(), this.missionRules)
      weaponPrice = this.getWeaponPrice(unit.name, getLastWeapon(unit.name))
      slotDelayData = this.slotDelayDataByCrewIdx?[idInCountry]
    })

    let priceTextObj = slotObj.findObject("extraInfoPriceText")
    if (checkObj(priceTextObj)) {
      let priceText = getUnitSlotPriceText(unit, params)
      let hasPriceText = priceText != ""
      priceTextObj.show(hasPriceText)
      priceTextObj.hasInfo = hasPriceText ? "yes" : "no"
      if (hasPriceText)
        priceTextObj.setValue(priceText)

      let priceTextHintObj = showObjById("extraInfoPriceTextHint", hasPriceText, slotObj)
      if (hasPriceText && priceTextHintObj?.isValid())
        priceTextHintObj.setValue(getUnitSlotPriceHintText(unit, params))

      this.getSlotbar().updateTopExtraInfoBlock(slotObj)
    }

    let nameObj = slotObj.findObject($"{getSlotObjId(countryId, idInCountry)}_txt")
    if (checkObj(nameObj))
      nameObj.setValue(getSlotUnitNameText(unit, params))

    if (!this.missionRules.isRespawnAvailable(unit))
      slotObj.shopStat = this.missionRules instanceof AdditionalUnits ? "locked" : "disabled"
  }

  function updateAllCrewSlots() {
    foreach (crew in getCrewsListByCountry(get_local_player_country()))
      this.updateCrewSlot(crew)

    this.getSlotbar()?.updateMissionInfoVisibility()
  }

  function get_mp_autostart_countdown() {
    let countdown = this.autostartTime - this.autostartTimer;
    return ceil(countdown);
  }
  function reset_mp_autostart_countdown() {
    this.autostartTimer = 0;
  }

  function showLoadAnim(show) {
    if (checkObj(this.scene))
      this.scene.findObject("loadanim").show(show)

    if (show)
      this.reset_mp_autostart_countdown();
  }

  function updateButtons(show = null, checkShowChange = false) {
    if ((checkShowChange && show == this.showButtons) || !checkObj(this.scene))
      return

    if (show != null)
      this.showButtons = show

    let canUseUnlocks = (get_game_type() & GT_USE_UNLOCKS) != 0
    let buttons = {
      btn_select =          this.showButtons && this.isRespawn && !this.isNoRespawns && !this.stayOnRespScreen && !this.doRespawnCalled && !this.isSpectate
      btn_select_no_enter = this.showButtons && this.isRespawn && !this.isNoRespawns && !this.stayOnRespScreen && !this.doRespawnCalled && this.isSpectate
      btn_spectator =       this.showButtons && this.isRespawn && this.isFriendlyUnitsExists && (!this.isSpectate || is_has_multiplayer())
      btn_mpStat =          this.showButtons && this.isRespawn && is_has_multiplayer()
      btn_QuitMission =     this.showButtons && this.isRespawn && this.isNoRespawns && g_mis_loading_state.isReadyToShowRespawn()
      btn_back =            this.showButtons && useTouchscreen && !this.isRespawn
      btn_activateorder =   this.showButtons && this.isRespawn && showActivateOrderButton() && (!this.isSpectate || !showConsoleButtons.value)
      btn_personal_tasks =  this.showButtons && this.isRespawn && canUseUnlocks

      //Tactical map control
      hint_attention_to_map = !showConsoleButtons.get()
      hint_btn_move_map     = !showConsoleButtons.get()
    }
    foreach (id, value in buttons)
      showObjById(id, value, this.scene)

    let isShowPOiButton = !(this.showButtons && this.isRespawn && !this.isNoRespawns && !this.stayOnRespScreen && !this.doRespawnCalled && !this.isSpectate) && hasSightStabilization()
    let setPointOfInterestObj = showObjById("btn_set_point_of_interest", isShowPOiButton, this.scene)
    if (isShowPOiButton)
      showObjById("hint_btn_set_point_of_interest", !showConsoleButtons.get(), setPointOfInterestObj)

    let isShowSetHudTypeBtn = isGroundAndAirMission()
    let setHudTypeObj = showObjById("btn_set_hud_type", isShowSetHudTypeBtn, this.scene)
    if (isShowSetHudTypeBtn)
      showObjById("hint_btn_set_hud_type", !showConsoleButtons.get(), setHudTypeObj)

    let crew = this.getCurCrew()
    let slotObj = crew && getSlotObj(this.scene, crew.idCountry, crew.idInCountry)
    showObjById("buttonsDiv", show && this.isRespawn, slotObj)
  }

  function updateCountdown(countdown) {
    let isLoadingUnitModel = !this.stayOnRespScreen && !canRequestAircraftNow()
    this.showLoadAnim(!this.isGTCooperative
      && (isLoadingUnitModel || !g_mis_loading_state.isReadyToShowRespawn()))
    this.updateButtons(!isLoadingUnitModel, true)

    if (isLoadingUnitModel || !this.use_autostart())
      this.reset_mp_autostart_countdown();

    if (this.stayOnRespScreen)
      return

    local btnText = this.applyText
    if (countdown > 0 && this.readyForRespawn && this.isApplyPressed)
      btnText = "".concat(btnText, loc("ui/parentheses/space", { text = "".concat(countdown, loc("mainmenu/seconds")) }))

    foreach (btnId in this.mainButtonsId)
      setColoredDoubleTextToButton(this.scene, btnId, btnText)

    let textObj = this.scene.findObject("autostart_countdown_text")
    if (!checkObj(textObj))
      return

    let autostartCountdown = this.get_mp_autostart_countdown()
    local text = ""
    if (this.use_autostart() && autostartCountdown > 0 && autostartCountdown <= this.autostartShowTime)
      text = colorize(autostartCountdown <= this.autostartShowInColorTime ? "@warningTextColor" : "@activeTextColor",
        "".concat(loc("mainmenu/autostartCountdown"), " ", autostartCountdown, loc("mainmenu/seconds")))
    textObj.setValue(text)
  }

  curChatBlk = ""
  curChatData = null
  function loadChat() {
    let chatBlkName = this.isSpectate ? "%gui/chat/gameChat.blk" : "%gui/chat/gameChatRespawn.blk"
    if (!this.curChatData || chatBlkName != this.curChatBlk)
      this.loadChatScene(chatBlkName)
    if (this.curChatData)
      hideGameChatSceneInput(this.curChatData, !this.isRespawn && !this.isSpectate)
  }

  function loadChatScene(chatBlkName) {
    let chatObj = this.scene.findObject(this.isSpectate ? "mpChatInSpectator" : "mpChatInRespawn")
    if (!checkObj(chatObj))
      return

    if (this.curChatData) {
      if (checkObj(this.curChatData.scene))
        this.guiScene.replaceContentFromText(this.curChatData.scene, "", 0, null)
      detachGameChatSceneData(this.curChatData)
    }

    this.curChatData = loadGameChatToObj(chatObj, chatBlkName, this,
      { selfHideInput = this.isSpectate, isInSpectateMode = this.isSpectate, isInputSelected = this.isSpectate })
    this.curChatBlk = chatBlkName

    if (!this.isSpectate)
      return

    let voiceChatNestObj = chatObj.findObject("voice_chat_nest")
    if (checkObj(voiceChatNestObj))
      this.guiScene.replaceContent(voiceChatNestObj, "%gui/chat/voiceChatWidget.blk", this)
  }

  function updateSpectatorRotationForced(isRespawnSceneActive = null) {
    if (isRespawnSceneActive == null)
      isRespawnSceneActive = this.isSceneActive()
    force_spectator_camera_rotation(isRespawnSceneActive && this.isSpectate)
  }

  function setSpectatorMode(is_spectator, forceShowInfo = false) {
    if (this.isSpectate == is_spectator && !forceShowInfo)
      return

    updateExtWatched({isInRespawnSpectatorMode = is_spectator})

    this.isSpectate = is_spectator
    this.showSpectatorInfo(is_spectator)
    this.setOrdersEnabled(this.isSpectate)
    this.updateSpectatorRotationForced()

    this.shouldBlurSceneBg = !this.isSpectate ? needUseHangarDof() : false
    handlersManager.updateSceneBgBlur()

    this.updateTacticalMapUnitType()

    if (is_spectator) {
      this.scene.findObject("btn_spectator").setValue(this.canChangeAircraft ? loc("multiplayer/changeAircraft") : loc("multiplayer/backToMap"))
      this.updateSpectatorName()
    }
    else
      this.scene.findObject("btn_spectator").setValue(loc("multiplayer/spectator"))

    this.loadChat()

    this.updateListsButtons()

    onSpectatorMode(is_spectator)

    this.updateApplyText()
    this.updateControlsAllowMask()
  }

  function updateControlsAllowMask() {
    this.switchControlsAllowMask(
      !this.isRespawn ? (
        CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP |
        CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD |
        CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY)
      : this.isSpectate ? CtrlsInGui.CTRL_ALLOW_SPECTATOR
      : CtrlsInGui.CTRL_ALLOW_NONE)
  }

  function setOrdersEnabled(value) {
    let statusObj = this.getOrderStatusObj()
    if (statusObj == null)
      return
    statusObj.show(value)
    statusObj.enable(value)
    if (value)
      enableOrders(statusObj)
  }

  function showSpectatorInfo(status) {
    if (!checkObj(this.scene))
      return

    this.setSceneTitle(status ? "" : getCurMpTitle(), this.scene, "respawn_title")
    this.setSceneMissionEnviroment()
    this.scene.findObject("spectator_mode_title").show(status)
    this.scene.findObject("flight_menu_bgd").show(!status)
    this.scene.findObject("spectator_controls").show(status)
    this.scene.findObject("btn_show_hud").enable(status)
    this.updateButtons()
  }

  function getEndTimeObj() {
    return this.scene.findObject("respawn_time_end")
  }

  function getScoreLimitObj() {
    return this.scene.findObject("respawn_score_limit")
  }

  function getTimeToKickObj() {
    return this.scene.findObject("respawn_time_to_kick")
  }

  function updateSpectatorName() {
    if (!checkObj(this.scene))
      return

    let name = getSpectatorTargetName()
    if (name == this.lastSpectatorTargetName)
      return
    this.lastSpectatorTargetName = name

    let title = getSpectatorTargetTitle()
    let text = $"{name} {title}"

    let targetId = getSpectatorTargetId()
    let player = get_mplayer_by_id(targetId)
    let color = player != null ? get_mplayer_color(player) : "teamBlueColor"

    this.scene.findObject("spectator_name").setValue(colorize(color, text))
  }

  function onChatCancel() {
    if (this.curChatData?.selfHideInput ?? false)
      return
    this.onGamemenu(null)
  }

  function onEmptyChatEntered() {
    if (!this.isSpectate)
      this.onApply()
  }

  function onGamemenu(_obj) {
    if (this.showHud())
      return; //was hidden, ignore menu opening

    if (!this.isRespawn || !canRequestAircraftNow())
      return

    if (this.isSpectate && this.onSpectator() && ::has_available_slots())
      return

    if (isAllowedMoveCenter()) {
      setAllowMoveCenter(false)
      let tacticalMapObj = this.scene.findObject("tactical-map")
      tacticalMapObj.cursor =  "normal"
      return;
    }

    this.guiScene.performDelayed(this, function() {
      disable_flight_menu(false)
      gui_start_flight_menu()
    })
  }

  function onSpectator(_obj = null) {
    if (!canRequestAircraftNow() || !this.isRespawn)
      return false
    this.setSpectatorMode(!this.isSpectate)
    return true
  }

  function setHudVisibility(_obj) {
    if (!this.isSpectate)
      return

    show_hud(!this.scene.findObject("respawn_screen").isVisible())
  }

  function showHud() {
    if (!checkObj(this.scene) || this.scene.findObject("respawn_screen").isVisible())
      return false
    show_hud(true)
    return true
  }

  function updateSwitchSpectatorTarget(dt) {
    this.spectator_switch_timer -= dt;

    if (this.spectator_switch_direction == ESwitchSpectatorTarget.E_DO_NOTHING)
      return; //do nothing
    if (this.spectator_switch_timer <= 0) {
      switchSpectatorTarget(this.spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT);
      this.updateSpectatorName();

      this.spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING;
      this.spectator_switch_timer = this.spectator_switch_timer_max;
    }
  }
  function switchSpectatorTargetToNext() {
    if (this.spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT)
      return; //already switching
    if (this.spectator_switch_direction == ESwitchSpectatorTarget.E_PREV) {
      this.spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING; //switch back
      return;
    }
    this.spectator_switch_direction = ESwitchSpectatorTarget.E_NEXT;
  }
  function switchSpectatorTargetToPrev() {
    if (this.spectator_switch_direction == ESwitchSpectatorTarget.E_PREV)
      return; //already switching
    if (this.spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT) {
      this.spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING; //switch back
      return;
    }
    this.spectator_switch_direction = ESwitchSpectatorTarget.E_PREV;
  }

  function onHideHUD(_obj) {
    show_hud(false)
  }

  function onShowHud(show = true, _needApplyPending = false) { //return - was changed
    if (!this.isSceneActive())
      return

    if (!checkObj(this.scene))
      return

    let obj = this.scene.findObject("respawn_screen")
    let isHidden = obj?.display == "hide" //until scene recount obj.isVisible will return false, because it was full hidden
    if (isHidden != show)
      return

    obj.show(show)
  }

  function onSpectatorNext(_obj) {
    if (!canRequestAircraftNow())
      return
    if (this.isRespawn && this.isSpectate)
      this.switchSpectatorTargetToNext();
  }

  function onSpectatorPrev(_obj) {
    if (!canRequestAircraftNow())
      return
    if (this.isRespawn && this.isSpectate)
      this.switchSpectatorTargetToPrev();
  }

  function onMoveMapActivate() {
     setAllowMoveCenter(!isAllowedMoveCenter())
     let tacticalMapObj = this.scene.findObject("tactical-map")
     tacticalMapObj.cursor =  isAllowedMoveCenter() ? "moveArrowCursor" : "normal"
  }

  function onForcedSetHudType(obj) {
    local curHudType = getCurHudType()
    if (curHudType == HUD_TYPE_UNKNOWN) {
      let unit = this.getCurSlotUnit()
      if (unit)
        curHudType = unit.unitType.hudTypeCode
    }

    let isSwitchToTankHud = curHudType == HUD_TYPE_AIRPLANE
    setForcedHudType(isSwitchToTankHud ? HUD_TYPE_TANK : HUD_TYPE_AIRPLANE)
    obj.findObject("hud_type_img")["background-image"] = isSwitchToTankHud  ? "#ui/gameuiskin#objective_fighter.svg" : "#ui/gameuiskin#objective_tank.svg"
  }

  function onSetPointOfInterest(obj) {
    setAllowMoveCenter(false)
    let buttonImg = obj.findObject("hud_poi_img");
    if (isPointOfInterestSet()) {
      resetPointOfInterest()
      buttonImg["background-image"] = "#ui/gameuiskin#map_interestpoint.svg"
      setPointSettingMode(false)
      showObjById("POI_resetter", false, this.scene)
      return
    }
    let isPointSettingModeOn = !isPointSettingMode()
    setPointSettingMode(isPointSettingModeOn)
    buttonImg["background-image"] = isPointSettingModeOn ? "#ui/gameuiskin#map_interestpoint_delete.svg" : "#ui/gameuiskin#map_interestpoint.svg"
    let tacticalMapObj = this.scene.findObject("tactical-map")
    tacticalMapObj.cursor =  isPointSettingModeOn ? "pointOfInterest" : "normal"
    showObjById("POI_resetter", isPointSettingModeOn, this.scene)
  }

  function onRespawnScreenClick() {
    this.resetPointOfInterestMode()
  }

  function onMpStatScreen(_obj) {
    if (!canRequestAircraftNow())
      return

    this.guiScene.performDelayed(this, function() {
      disable_flight_menu(false)
      guiStartMPStatScreen()
    })
  }

  function getCurrentEdiff() {
    return get_mission_mode()
  }

  function onQuitMission(_obj) {
    quitMission()
  }

  onPersonalTasksOpen = @() openPersonalTasks()

  function goBack() {
    if (!this.isRespawn)
      close_ingame_gui()
  }

  function onEventUpdateEsFromHost(_p) {
    if (this.isSceneActive())
      this.reinitScreen({})
  }

  function onEventUnitWeaponChanged(_p) {
    let crew = this.getCurCrew()
    let unit = getCrewUnit(crew)
    if (!unit)
      return

    if (this.missionRules.hasRespawnCost) {
      this.updateCrewSlot(crew)
      this.getSlotbar()?.updateMissionInfoVisibility()
    }

    this.updateOptions(RespawnOptUpdBit.UNIT_WEAPONS)
    this.checkReady()
  }

  function onEventBulletsGroupsChanged(_p) {
    let crew = this.getCurCrew()
    if (this.missionRules.hasRespawnCost) {
      this.updateCrewSlot(crew)
      this.getSlotbar()?.updateMissionInfoVisibility()
    }

    this.checkReady()
  }

  function onEventBulletsCountChanged(_p) {
    this.checkReady()
  }

  function updateLeftPanelBlock() {
    let objectivesObj = this.scene.findObject("objectives")
    let separateObj = this.scene.findObject("separate_block")
    let chatObj = this.scene.findObject("mpChatInRespawn")
    let unitOptionsObj = this.scene.findObject("unit_options")
    objectivesObj.height = ""
    separateObj.height = ""
    unitOptionsObj.height = ""
    chatObj.height = "fh"

    // scene update needed to all objects has right size values
    this.guiScene.applyPendingChanges(false)

    let leftPanelObj = this.scene.findObject("panel-left")
    let minChatHeight = toPixels(this.guiScene, "1@minChatHeight")
    let hOversize = unitOptionsObj.getSize()[1] + objectivesObj.getSize()[1] +
      minChatHeight - leftPanelObj.getSize()[1]

    local unitOptionsHeight = unitOptionsObj.getSize()[1]
    if (hOversize > 0) {
      unitOptionsHeight = max(unitOptionsObj.getSize()[1] - hOversize,
        unitOptionsObj.getSize()[1] / 2)
      unitOptionsObj.height = unitOptionsHeight
    }

    let maxChatHeight = toPixels(this.guiScene, "1@maxChatHeight")
    this.canSwitchChatSize = chatObj.getSize()[1] < maxChatHeight
      && objectivesObj.getSize()[1] > toPixels(this.guiScene, "1@minMisObjHeight")

    showObjById("mis_obj_text_header", !this.canSwitchChatSize, this.scene)
    showObjById("mis_obj_button_header", this.canSwitchChatSize, this.scene)

    this.isChatFullSize = !this.canSwitchChatSize ? true : loadLocalByScreenSize("isRespawnChatFullSize", null)
    this.updateChatSize(this.isChatFullSize)

    let separatorHeight = leftPanelObj.getSize()[1] - unitOptionsObj.getSize()[1] -
                           objectivesObj.getSize()[1] - maxChatHeight

    chatObj.height = separatorHeight > 0 ? "1@maxChatHeight" : "fh"
    separateObj.height = separatorHeight > 0 ? "fh" : ""

    objectivesObj["max-height"] = leftPanelObj.getSize()[1] - unitOptionsHeight - minChatHeight
  }

  function onSwitchChatSize() {
    if (!this.canSwitchChatSize)
      return

    this.updateChatSize(!this.isChatFullSize)
    saveLocalByScreenSize("isRespawnChatFullSize", this.isChatFullSize)
  }

  function updateChatSize(newIsChatFullSize) {
    this.isChatFullSize = newIsChatFullSize

    this.scene.findObject("mis_obj_button_header").direction = this.isChatFullSize ? "down" : "up"
    this.scene.findObject("objectives").height = this.canSwitchChatSize && this.isChatFullSize ? "1@minMisObjHeight" : ""
  }

  function checkUpdateCustomStateRespawns() {
    if (!this.isSceneActive())
      return //when scene become active again there will be full update on reinitScreen

    let newRespawnMask = this.missionRules.getCurCrewsRespawnMask()
    if (!this.customStateCrewAvailableMask && newRespawnMask) {
      this.reinitScreen({})
      return
    }

    if (this.customStateCrewAvailableMask == newRespawnMask)
      return this.updateApplyText() //unit left respawn text

    this.updateLeftRespawns()
    this.reinitSlotbar()
  }

  function onEventMissionCustomStateChanged(_p) {
    this.doWhenActiveOnce("checkUpdateCustomStateRespawns")
    this.doWhenActiveOnce("updateAllCrewSlots")
  }

  function onEventMyCustomStateChanged(_p) {
    this.doWhenActiveOnce("checkUpdateCustomStateRespawns")
    this.doWhenActiveOnce("updateAllCrewSlots")
  }

  function onEventMissionObjectiveUpdated(_p) {
    this.updateLeftPanelBlock()
  }

  function updateSkinOptionTooltipId() {
    let unit = this.getCurSlotUnit()
    if (!unit)
      return
    let skinId = this.getSelSkin()
    if (!skinId)
      return
    let tooltipObj = this.scene.findObject("skin_tooltip")
    tooltipObj.tooltipId = getTooltipType("DECORATION").getTooltipId($"{unit.name}/{skinId}", UNLOCKABLE_SKIN,{
      hideDesignedFor = true
      hideUnlockInfo = true
    })
  }

  function getCurItemObj() {
    let list = this.scene.findObject("additionalUnits")
    let value = getObjValidIndex(list)
    if (value < 0)
      return null

    return list.getChild(value)
  }

  function onSelectAdditionalUnit(_obj) {
    let itemObj = this.getCurItemObj()
    if(itemObj == null)
      return

    let newUnitName = itemObj.id
    if(isLockedUnit(newUnitName))
      return
    updateUnitSelection(newUnitName)

    this.getSlotbar().fullUpdate()
    let slotsData = this.getSlotbar().getSlotsData(newUnitName)
    if (slotsData.len() == 0)
      return

    this.getSlotbar().selectCrew(slotsData[0].crew.idInCountry)
  }
}

function cantRespawnAnymore(_) { // called when no more respawn bases left
  let current_base_gui_handler = get_current_base_gui_handler()
  if (current_base_gui_handler && ("stayOnRespScreen" in current_base_gui_handler))
    current_base_gui_handler.stayOnRespScreen = true
}

eventbus_subscribe("cant_respawn_anymore", cantRespawnAnymore)

::get_mouse_relative_coords_on_obj <- function get_mouse_relative_coords_on_obj(obj) {
  if (!checkObj(obj))
    return null

  let objPos  = obj.getPosRC()
  let objSize = obj.getSize()
  let cursorPos = get_dagui_mouse_cursor_pos_RC()
  if (cursorPos[0] >= objPos[0] && cursorPos[0] <= objPos[0] + objSize[0] && cursorPos[1] >= objPos[1] && cursorPos[1] <= objPos[1] + objSize[1])
    return [
      1.0 * (cursorPos[0] - objPos[0]) / objSize[0],
      1.0 * (cursorPos[1] - objPos[1]) / objSize[1],
    ]

  return null
}

::has_available_slots <- function has_available_slots() {
  if (!(get_game_type() & (GT_VERSUS | GT_COOPERATIVE)))
    return true

  if (get_game_mode() == GM_SINGLE_MISSION || get_game_mode() == GM_DYNAMIC)
    return true

  if (!g_mis_loading_state.isCrewsListReceived())
    return false

  let team = get_mp_local_team()
  let country = get_local_player_country()
  let crews = getCrewsListByCountry(country)
  if (!crews)
    return false

  log($"Looking for country {country} in team {team} slots:{crews.len()}")

  let missionRules = getCurMissionRules()
  let leftRespawns = missionRules.getLeftRespawns()
  if (leftRespawns == 0)
    return false

  let curSpawnScore = missionRules.getCurSpawnScore()
  foreach (c in crews) {
    let air = getCrewUnit(c)
    if (!air)
      continue

    if (!isCrewAvailableInSession(c, air)
        || !is_crew_slot_was_ready_at_host(c.idInCountry, air.name, false)
        || !getAvailableRespawnBases(air.tags).len()
        || !missionRules.getUnitLeftRespawns(air)
        || !missionRules.isUnitEnabledBySessionRank(air)
        || !missionRules.canRespawnOnUnitByRageTokens(air)
        || air.disableFlyout)
      continue

    if (missionRules.isScoreRespawnEnabled
      && curSpawnScore >= 0
      && curSpawnScore < air.getMinimumSpawnScore())
      continue

    log($"has_available_slots true: unit {air.name} in slot {c.idInCountry}")
    return true
  }
  log("has_available_slots false")
  return false
}

function respawnInfoUpdated(data) {
  let { unitName = null } = data
  if (unitName == null)
    return
  let respawn = handlersManager.findHandlerClassInScene(gui_handlers.RespawnHandler)
  if (respawn == null)
    return

  let { crew = null } = respawn.getSlotbar()?.getSlotsData(unitName)[0]
  if (crew == null)
    return

  respawn.updateCrewSlot(crew)
  respawn.getSlotbar().updateMissionInfoVisibility()
}

eventbus_subscribe("respawnInfoUpdated", respawnInfoUpdated)

register_command(function() {
  needSkipAvailableCrewToSelect.value = !needSkipAvailableCrewToSelect.value
  log($"needSkipAvailableCrewToSelect = {needSkipAvailableCrewToSelect.value ? "true" : "false"}")
}, "respawn.toggle_to_select_not_available_unit")

register_command(function(universalSpareName) {
  let respawn = handlersManager.findHandlerClassInScene(gui_handlers.RespawnHandler)
  if (!(respawn?.isRespawn ?? false)) {
    log("Is no in respawn window")
    return
  }

  let curUnit = respawn.getCurSlotUnit()
  if (curUnit == null) {
    log("No selected unit")
    return
  }
  let unitName = curUnit.name
  let list = getUniversalSparesForUnit(curUnit)
  if (list.len() == 0) {
    log($"Missing universal spares for {unitName}")
    return
  }

  let spare = list.findvalue(@(item) item.id == universalSpareName)
  if (spare == null) {
    log($"Can not found spare for {unitName}")
    log($"Try using one of the {", ".join(list.map(@(item) item.id))}")
    return
  }
  respawn.universalSpareUidForRespawn = spare.uids[0]
  respawn.doSelectAircraft()
  log($"requestAircraftAndWeaponWithSpare for {unitName} with {universalSpareName}")
}, "respawn.try_respawn_on_selected_aircraft_with_universal_spare")
