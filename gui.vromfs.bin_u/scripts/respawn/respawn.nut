//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { toPixels } = require("%sqDagui/daguiUtil.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { get_time_msec } = require("dagor.time")
let { get_gui_option } = require("guiOptions")
let { ceil } = require("math")
let { format } = require("string")
let { is_has_multiplayer } = require("multiplayer")
let { get_current_mission_name, get_game_mode,
  get_game_type, get_mplayers_list, get_local_mplayer } = require("mission")
let { fetchChangeAircraftOnStart, canRespawnCaNow, canRequestAircraftNow,
  setSelectedUnitInfo, getAvailableRespawnBases, getRespawnBaseTimeLeftById,
  selectRespawnBase, highlightRespawnBase, getRespawnBase, doRespawnPlayer } = require("guiRespawn")
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
let { checkInRoomMembers } = require("%scripts/contacts/updateContactsStatus.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { getEventSlotbarHint } = require("%scripts/events/eventInfo.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { showedUnit, setShowUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { guiStartMPStatScreenFromGame,
  guiStartMPStatScreen } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { onSpectatorMode, switchSpectatorTarget,
  getSpectatorTargetId, getSpectatorTargetName, getSpectatorTargetTitle
} = require("guiSpectator")
let { getMplayersList } = require("%scripts/statistics/mplayersList.nut")
let { getCrew } = require("%scripts/crew/crew.nut")
let { quit_to_debriefing, get_mission_difficulty_int,
  get_unit_wp_to_respawn, get_mp_respawn_countdown, get_mission_status } = require("guiMission")
let { setCurSkinToHangar, getRealSkin, getSkinsOption
} = require("%scripts/customization/skins.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { openPersonalTasks } = require("%scripts/unlocks/personalTasks.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { USEROPT_SKIP_WEAPON_WARNING } = require("%scripts/options/optionsExtNames.nut")
let { loadLocalByScreenSize, saveLocalByScreenSize
} = require("%scripts/clientState/localProfile.nut")
let { getEsUnitType, getUnitName } = require("%scripts/unit/unitInfo.nut")

::last_ca_aircraft <- null
::used_planes <- {}
::need_race_finish_results <- false

::before_first_flight_in_session <- false

registerPersistentData("RespawnGlobals", getroottable(),
  ["last_ca_aircraft", "used_planes", "need_race_finish_results", "before_first_flight_in_session"])

::COLORED_DROPRIGHT_TEXT_STYLE <- "textStyle:t='textarea';"

enum ESwitchSpectatorTarget {
  E_DO_NOTHING,
  E_NEXT,
  E_PREV
}

::gui_start_respawn <- function gui_start_respawn(_is_match_start = false) {
  ::mp_stat_handler = handlersManager.loadHandler(gui_handlers.RespawnHandler)
  handlersManager.setLastBaseHandlerStartParams({ globalFunctionName = "gui_start_respawn" })
}

gui_handlers.RespawnHandler <- class extends gui_handlers.MPStatistics {
  sceneBlkName = "%gui/respawn/respawn.blk"
  shouldBlurSceneBg = true
  shouldFadeSceneInVr = true
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

  // debug vars
  timeToAutoSelectAircraft = 0.0
  timeToAutoStart = 0.0

  // Debug vars
  timeToAutoRespawn = 0.0

  prevUnitAutoChangeTimeMsec = -1
  prevAutoChangedUnit = null
  delayAfterAutoChangeUnitMsec = 1000

  static mainButtonsId = ["btn_select", "btn_select_no_enter"]

  function initScreen() {
    this.showSceneBtn("tactical-map-box", true)
    this.showSceneBtn("tactical-map", true)
    if (this.curRespawnBase != null)
      selectRespawnBase(this.curRespawnBase.mapId)

    this.missionRules = ::g_mis_custom_state.getCurMissionRules()

    this.checkFirstInit()

    ::disable_flight_menu(true)

    this.needPlayersTbl = false
    this.isApplyPressed = false
    this.doRespawnCalled = false
    let wasIsRespawn = this.isRespawn
    this.isRespawn = ::is_respawn_screen()
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
    this.updateLeftRespawns()

    let blk = ::dgs_get_game_params()
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

    this.showSceneBtn("screen_button_back", useTouchscreen && !this.isRespawn)
    this.showSceneBtn("gamercard_bottom", this.isRespawn)

    if (this.gameType & GT_RACE) {
      let finished = ::race_finished_by_local_player()
      if (finished && ::need_race_finish_results)
        guiStartMPStatScreenFromGame()
      ::need_race_finish_results = !finished
    }

    ::g_orders.collectOrdersToActivate()
    let ordersButton = this.scene.findObject("btn_activateorder")
    if (checkObj(ordersButton))
      ordersButton.setUserData(this)

    this.updateControlsAllowMask()
    this.updateVoiceChatWidget(!this.isRespawn)
    checkInRoomMembers()
    ::contacts_handler?.sceneShow(false)
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

    this.isFirstUnitOptionsInSession = ::before_first_flight_in_session

    this.scene.findObject("stat_update").setUserData(this)

    this.subHandlers.append(
      ::gui_load_mission_objectives(this.scene.findObject("primary_tasks_list"),   true, 1 << OBJECTIVE_TYPE_PRIMARY),
      ::gui_load_mission_objectives(this.scene.findObject("secondary_tasks_list"), true, 1 << OBJECTIVE_TYPE_SECONDARY)
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

  function initTeamUnitsLeftView() {
    if (!this.missionRules.hasCustomUnitRespawns())
      return

    let handler = handlersManager.loadHandler(gui_handlers.teamUnitsLeftView,
      { scene = this.scene.findObject("team_units_left_respawns"), missionRules = this.missionRules })
    this.registerSubHandler(handler)
    this.teamUnitsLeftWeak = handler?.weakref()
  }

  /*override*/ function onSceneActivate(show) {
    this.setOrdersEnabled(show && this.isSpectate)
    this.updateSpectatorRotationForced(show)
    this.updateTacticalMapUnitType(show ? null : false)
    base.onSceneActivate(show)
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
    if (!::g_mis_loading_state.isReadyToShowRespawn()) {
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
    if (checkObj(scoreObj) && this.missionRules.isScoreRespawnEnabled)
      scoreObj.setValue(::getCompoundedText("".concat(loc("multiplayer/spawnScore"), " "), this.curSpawnScore, "activeTextColor"))
  }

  function updateSpawnScore(isOnInit = false) {
    if (!this.missionRules.isScoreRespawnEnabled ||
      !::g_mis_loading_state.isReadyToShowRespawn())
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
    foreach (idx, crew in ::get_crews_list_by_country(::get_local_player_country())) {
      let unit = ::g_crew.getCrewUnit(crew)
      if (unit && ::shop_get_spawn_score(unit.name, "", []) >= this.curSpawnScore)
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
          isList = o.cType == optionControlType.LIST
          isCheckbox = o.cType == optionControlType.CHECKBOX
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
    let optionsParams = this.getOptionsParams().__update(paramsOverride)
    foreach (idx, option in respawnOptions.types)
      this.optionsFilled[idx] = option.update(optionsParams, trigger, this.optionsFilled[idx]) || this.optionsFilled[idx]
  }

  function initAircraftSelect() {
    if (showedUnit.value == null)
      showedUnit(getAircraftByName(::last_ca_aircraft))

    log($"initScreen aircraft {::last_ca_aircraft} showedUnit {showedUnit.value}")

    this.scene.findObject("CA_div").show(this.haveSlotbar)
    this.updateSessionWpBalance()

    if (this.haveSlotbar) {
      let needWaitSlotbar = !::g_mis_loading_state.isReadyToShowRespawn() && !this.isSpectator()
      this.showSceneBtn("slotbar_load_wait", needWaitSlotbar)
      if (!this.isSpectator() && ::g_mis_loading_state.isReadyToShowRespawn()
          && (this.needRefreshSlotbarOnReinit || !this.slotbarWeak)) {
        this.slotbarInited = false
        this.beforeRefreshSlotbar()
        this.createSlotbar(this.getSlotbarParams()
          .__update({ slotbarHintText = getEventSlotbarHint(
            ::SessionLobby.getRoomEvent(), ::get_local_player_country()) }),
          "flight_menu_bgd")
        this.afterRefreshSlotbar()
        this.slotReadyAtHostMask = this.getCrewSlotReadyMask()
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
      local airName = ::last_ca_aircraft
      if (this.isGTCooperative)
        airName = getTblValue("aircraftName", this.mplayerTable, "")
      let air = getAircraftByName(airName)
      if (air) {
        showedUnit(air)
        this.scene.findObject("air_info_div").show(true)
        let data = ::build_aircraft_item(air.name, air, {
          showBR        = hasFeature("SlotbarShowBattleRating")
          getEdiffFunc  = this.getCurrentEdiff.bindenv(this)
        })
        this.guiScene.replaceContentFromText(this.scene.findObject("air_item_place"), data, data.len(), this)
        ::fill_unit_item_timers(this.scene.findObject("air_item_place").findObject(air.name), air)
      }
    }

    this.setRespawnCost()
    this.reset_mp_autostart_countdown();
  }

  function getSlotbarParams() {
    let playerCountry = ::get_local_player_country()
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
      shouldSelectAvailableUnit = this.isRespawn
      customViewCountryData = { [playerCountry] = {
        icon = this.missionRules.getOverrideCountryIconByTeam(::get_mp_local_team())
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

    let info = ::get_cur_rank_info()
    let curWpBalance = ::get_cur_warpoints()
    this.sessionWpBalance = curWpBalance + info.cur_award_positive - info.cur_award_negative
  }

  function setRespawnCost() {
    let showWPSpend = this.missionRules.isWarpointsRespawnEnabled && this.isRespawn
    local wpBalance = ""
    if (showWPSpend) {
      this.updateSessionWpBalance()
      let info = ::get_cur_rank_info()
      let curWpBalance = ::get_cur_warpoints()
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
        text = ::getCompoundedText(loc("multiplayer/wp_header"), wpBalance, "activeTextColor")
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

    this.slotReadyAtHostMask = this.getCrewSlotReadyMask()
    this.slotsCostSum = this.getSlotsSpawnCostSumNoWeapon()
  }

  //hack: to check slotready changed
  function checkCrewAccessChange() {
    if (!this.getSlotbar()?.singleCountry || !this.slotbarInited)
      return

    local needReinitSlotbar = false

    let newMask = this.getCrewSlotReadyMask()
    if (newMask != this.slotReadyAtHostMask) {
      log("Error: is_crew_slot_was_ready_at_host or is_crew_available_in_session have changed without cb. force reload slots")
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

  function getCrewSlotReadyMask() {
    local res = 0
    if (!::g_mis_loading_state.isCrewsListReceived())
      return res

    let MAX_UNIT_SLOTS = 16
    for (local i = 0; i < MAX_UNIT_SLOTS; i++)
      if (::is_crew_slot_was_ready_at_host(i, "", false) && ::is_crew_available_in_session(i, false))
        res += (1 << i)
    return res
  }

  function getSlotsSpawnCostSumNoWeapon() {
    local res = 0
    let crewsCountry = ::g_crews_list.get()?[this.getCurCrew()?.idCountry]
    if (!crewsCountry)
      return res

    foreach (idx, crew in crewsCountry.crews) {
      if ((this.slotReadyAtHostMask & (1 << idx)) == 0)
        continue
      let unit = ::g_crew.getCrewUnit(crew)
      if (unit)
        res += ::shop_get_spawn_score(unit.name, "", [])
    }
    return res
  }

  function beforeSlotbarSelect(onOk, onCancel, selSlot) {
    if (!this.canChangeAircraft && this.slotbarInited) {
      onCancel()
      return
    }

    let crew = getCrew(selSlot.countryId, selSlot.crewIdInCountry)
    let unit = ::g_crew.getCrewUnit(crew)
    let isAvailable = ::is_crew_available_in_session(selSlot.crewIdInCountry, false)
      && this.missionRules.isUnitEnabledBySessionRank(unit)
    if (crew == null) {
      onCancel()
      return
    }

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
    ::cur_aircraft_name = unit.name

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

    let handler = handlersManager.loadHandler(gui_handlers.unitWeaponsHandler,
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
       && airName in ::used_planes
       && isInArray(weapon, ::used_planes[airName])) {
      let unit = getAircraftByName(airName)
      let count = getAmmoMaxAmountInSession(unit, weapon, AMMO.WEAPON) - getAmmoAmount(unit, weapon, AMMO.WEAPON)
      return (count * ::wp_get_cost2(airName, weapon))
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
    if (!this.isRespawn)
      hint = colorize("activeTextColor", loc("voice_message_attention_to_point_2"))
    else {
      let coords = ::get_mouse_relative_coords_on_obj(this.tmapBtnObj)
      if (!coords)
        hintIcon = ""
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

    if (selIdx == -1)
      foreach (idx, spawn in this.respawnBasesList)
        if (!spawn.isMapSelectable) {
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

    ::aircraft_for_weapons = air.name

    let option = respawnOptions.get(obj?.id)
    if (option.userOption != -1) {
      let userOpt = ::get_option(option.userOption)
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
      isUnitChanged = ::aircraft_for_weapons != unit.name
      ::cur_aircraft_name = unit.name //used in some options
      ::aircraft_for_weapons = unit.name
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
    ::set_tactical_map_hud_type(hudType)
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
    return getSkinsOption(unit.name).values?[obj.getValue()]
  }

  function doSelectAircraftSkipAmmo() {
    this.doSelectAircraft(false)
  }

  function doSelectAircraft(checkAmmo = true) {
    if (this.requestInProgress)
      return

    let requestData = this.getSelectedRequestData(false)
    if (!requestData)
      return
    if (checkAmmo && !this.checkCurAirAmmo(this.doSelectAircraftSkipAmmo))
      return
    if (!this.checkCurUnitSkin(this.doSelectAircraftSkipAmmo))
      return

    this.requestAircraftAndWeapon(requestData)
    if (this.scene.findObject("skin").getValue() > 0)
      reqUnlockByClient("non_standard_skin")

    actionBarInfo.cacheActionDescs(requestData.name)

    setShowUnit(getAircraftByName(requestData.name))
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
          ::g_popups.add(null, msg)
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
    if (cantSpawnReason) {
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
    }

    local bulletInd = 0;
    let bulletGroups = this.weaponsSelectorWeak ? this.weaponsSelectorWeak.bulletsManager.getBulletsGroups() : []
    foreach (_groupIndex, bulGroup in bulletGroups) {
      if (!bulGroup.active)
        continue
      let modName = bulGroup.selectedName
      if (!modName)
        continue

      let count = bulGroup.bulletsCount * bulGroup.guns
      if (bulGroup.canChangeBulletsCount() && bulGroup.bulletsCount <= 0)
        continue

      if (getModificationByName(air, modName)) //!default bullets (fake)
        res[$"bullets{bulletInd}"] <- modName
      else
        res[$"bullets{bulletInd}"] <- ""
      res[$"bulletCount{bulletInd}"] <- count
      bulletInd++;
    }
    while (bulletInd < BULLETS_SETS_QUANTITY) {
      res[$"bullets{bulletInd}"] <- ""
      res[$"bulletCount{bulletInd}"] <- 0
      bulletInd++;
    }

    let editSlotbarBullets = getOverrideBullets(air);
    if (editSlotbarBullets)
      for (local i = 0; i < BULLETS_SETS_QUANTITY; i++) {
        res[$"bullets{i}"] = editSlotbarBullets?[$"bullets{i}"] ?? ""
        res[$"bulletCount{i}"] = editSlotbarBullets?[$"bulletsCount{i}"] ?? 0
      }

    let optionsParams = this.getOptionsParams()

    foreach (option in respawnOptions.types) {
      if (!option.needSetToReqData || !option.isVisible(optionsParams))
        continue

      let opt = ::get_option(option.userOption)
      if (opt.controlType == optionControlType.LIST)
        res[opt.id] <- opt.values?[opt.value]
      else
        res[opt.id] <- opt.value
    }

    return res
  }

  function getCantSpawnReason(crew, silent = true) {
    let unit = ::g_crew.getCrewUnit(crew)
    if (unit == null)
      return null

    let ruleMsg = this.missionRules.getSpecialCantRespawnMessage(unit)
    if (!u.isEmpty(ruleMsg))
      return { text = ruleMsg, id = "cant_spawn_by_mission_rules" }

    if (this.isRespawn && !this.missionRules.isUnitEnabledBySessionRank(unit))
      return {
        text = loc("multiplayer/lowVehicleRank",
          { minSessionRank = ::calc_battle_rating_from_rank(this.missionRules.getMinSessionRank()) })
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
      (this.curSpawnScore < ::shop_get_spawn_score(unit.name, this.getSelWeapon() ?? "", this.getSelBulletsList() ?? [])))
        return { text = loc("multiplayer/noSpawnScore"), id = "not_enought_score" }

    if (this.missionRules.isSpawnDelayEnabled && this.isRespawn) {
      let slotDelay = ::get_slot_delay(unit.name)
      if (slotDelay > 0) {
        let text = loc("multiplayer/slotDelay", { time = time.secondsToString(slotDelay) })
        return { text = text, id = "wait_for_slot_delay" }
      }
    }

    if (!::is_crew_available_in_session(crew.idInCountry, !silent)) {
      local locId = "not_available_aircraft"
      if ((::SessionLobby.getUnitTypesMask() & (1 << getEsUnitType(unit))) != 0)
        locId = "crew_not_available"
      return { text = ::SessionLobby.getNotAvailableUnitByBRText(unit) || loc(locId),
        id = "crew_not_available" }
    }

    if (!silent)
      log($"Try to select aircraft {unit.name}")

    if (!::is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, !silent)) {
      if (!silent)
        log($"is_crew_slot_was_ready_at_host return false for {crew.idInCountry} - {unit.name}")
      return { text = loc("aircraft_not_repaired"), id = "aircraft_not_repaired" }
    }

    return null
  }

  function requestAircraftAndWeapon(requestData) {
    if (this.requestInProgress)
      return

    ::set_aircraft_accepted_cb(this, this.aircraftAcceptedCb);
    let _taskId = ::request_aircraft_and_weapon(requestData, requestData.idInCountry, requestData.respBaseId)
    if (_taskId < 0)
      ::set_aircraft_accepted_cb(null, null);
    else {
      this.requestInProgress = true
      this.showTaskProgressBox(loc("charServer/purchase0"), function() { this.requestInProgress = false })

      this.lastRequestData = requestData
    }
  }

  function aircraftAcceptedCb(result) {
    ::set_aircraft_accepted_cb(null, null)
    this.destroyProgressBox()
    this.requestInProgress = false

    if (!this.isValid())
      return

    this.reset_mp_autostart_countdown()

    switch (result) {
      case ERR_ACCEPT:
        this.onApplyAircraft(this.lastRequestData)
        ::update_gamercards() //update balance
        break;

      case ERR_REJECT_SESSION_FINISHED:
      case ERR_REJECT_DISCONNECTED:
        break;

      default:
        log($"Respawn Erorr: aircraft accepted cb result = {result}, on request:")
        debugTableData(this.lastRequestData)
        this.lastRequestData = null
        if (!checkObj(this.guiScene["char_connecting_error"]))
          showInfoMsgBox(loc($"changeAircraftResult/{result}"), "char_connecting_error")
        break
    }
  }

  function onApplyAircraft(requestData) {
    if (requestData)
      ::last_ca_aircraft = requestData.name

    this.checkReady()
    if (this.readyForRespawn)
      this.onApply()
  }

  function checkReady(obj = null) {
    this.onOtherOptionUpdate(obj)

    this.readyForRespawn = this.lastRequestData != null && u.isEqual(this.lastRequestData, this.getSelectedRequestData())

    if (!this.readyForRespawn && this.isApplyPressed)
      if (!this.doRespawnCalled)
        this.isApplyPressed = false
      else
        log("Something has changed in the aircraft selection, but too late - do_respawn was called before.")
    this.updateApplyText()
  }

  function updateApplyText() {
    let unit = this.getCurSlotUnit()
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
        let wpCost = this.getRespawnWpTotalCost()
        if (wpCost > 0) {
          shortCostText = Cost(wpCost).getUncoloredText()
          costTextArr.append(shortCostText)
        }

        if (this.missionRules.isScoreRespawnEnabled && unit) {
          let curScore = ::shop_get_spawn_score(unit.name, this.getSelWeapon() ?? "", this.getSelBulletsList() ?? [])
          isAvailResp = isAvailResp && (curScore <= this.curSpawnScore)
          if (curScore > 0)
            costTextArr.append(loc("shop/spawnScore", { cost = curScore }))
        }

        if (this.leftRespawns > 0)
          infoTextsArr.append(loc("respawn/leftRespawns", { num = this.leftRespawns.tostring() }))

        infoTextsArr.append(this.missionRules.getRespawnInfoTextForUnit(unit))
        isAvailResp = isAvailResp && this.missionRules.isRespawnAvailable(unit)
      }
    }

    local isCrewDelayed = false
    if (this.missionRules.isSpawnDelayEnabled && unit) {
      let slotDelay = ::get_slot_delay(unit.name)
      isCrewDelayed = slotDelay > 0
    }

    //******************** combine final texts ********************************

    local applyTextShort = this.applyText //for slot battle button
    let comma = loc("ui/comma")

    if (shortCostText.len())
      applyTextShort = format("%s<b> %s</b>", loc("mainmenu/toBattle/short"), shortCostText)

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
    }

    let crew = this.getCurCrew()
    let slotObj = crew && ::get_slot_obj(this.scene, crew.idCountry, crew.idInCountry)
    let slotBtnObj = setColoredDoubleTextToButton(slotObj, "slotBtn_battle", applyTextShort)
    if (slotBtnObj) {
      slotBtnObj.isCancel = this.isApplyPressed ? "yes" : "no"
      slotBtnObj.inactiveColor = (isAvailResp && !isCrewDelayed) ? "no" : "yes"
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
        ::g_popups.add(null, this.noRespText)
      return
    }

    this.reset_mp_autostart_countdown()
    if (this.readyForRespawn)
      this.setApplyPressed()
    else if (this.canChangeAircraft && !this.isApplyPressed && canRequestAircraftNow())
      this.doSelectAircraft()
  }

  function checkCurAirAmmo(applyFunc) {
    let bulletsManager = this.weaponsSelectorWeak?.bulletsManager
    if (!bulletsManager)
      return true

    if (bulletsManager.canChangeBulletsCount())
      return bulletsManager.checkChosenBulletsCount(true, Callback(@() applyFunc(), this))

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
      ::gui_start_modal_wnd(gui_handlers.WeaponWarningHandler,
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

    if (contentPreset.isAgreed(diffCode, newPresetId))
      return true // User already agreed to set this or higher preset.

  ::gui_start_modal_wnd(gui_handlers.SkipableMsgBox, {
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
    if (this.isSpectate || !crew || !::before_first_flight_in_session || this.missionRules.isWarpointsRespawnEnabled)
      return false;

    let air = this.getCurSlotUnit()
    if (!air)
      return false

    return !::is_spare_aircraft_in_slot(crew.idInCountry) &&
      ::is_crew_slot_was_ready_at_host(crew.idInCountry, air.name, false)
  }

  function onUpdate(_obj, dt) {
    if (this.needCheckSlotReady)
      this.checkCrewAccessChange()

    this.updateSwitchSpectatorTarget(dt)
    if (this.missionRules.isSpawnDelayEnabled)
      this.updateSlotDelays()

    this.updateSpawnScore(false)

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

    if (this.isApplyPressed) {
      if (this.checkSpawnInterrupt())
        return

      if (canRespawnCaNow() && countdown < -100) {
        ::disable_flight_menu(false)
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
    ::before_first_flight_in_session = false
    this.doRespawnCalled = doRespawnPlayer()
    if (!this.doRespawnCalled) {
      this.onApply()
      showInfoMsgBox(loc("msg/error_when_try_to_respawn"), "error_when_try_to_respawn", true)
      return
    }

    broadcastEvent("PlayerSpawn", this.lastRequestData)
    if (this.lastRequestData) {
      this.lastSpawnUnitName = this.lastRequestData.name
      let requestedWeapon = this.lastRequestData.weapon
      if (!(this.lastSpawnUnitName in ::used_planes))
        ::used_planes[this.lastSpawnUnitName] <- []
      if (!isInArray(requestedWeapon, ::used_planes[this.lastSpawnUnitName]))
        ::used_planes[this.lastSpawnUnitName].append(requestedWeapon)
      this.lastRequestData = null
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
      ::g_popups.add(null, msg)
    })
    return true
  }

  function updateSlotDelays() {
    if (!checkObj(this.scene))
      return

    let crews = ::get_crews_list_by_country(::get_local_player_country())
    let currentIdInCountry = this.getCurCrew()?.idInCountry
    foreach (crew in crews) {
      let idInCountry = crew.idInCountry
      if (!(idInCountry in this.slotDelayDataByCrewIdx))
        this.slotDelayDataByCrewIdx[idInCountry] <- { slotDelay = -1, updateTime = 0 }
      let slotDelayData = this.slotDelayDataByCrewIdx[idInCountry]

      let prevSlotDelay = getTblValue("slotDelay", slotDelayData, -1)
      let curSlotDelay = ::get_slot_delay_by_slot(idInCountry)
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
  }

  //only for crews of current country
  function updateCrewSlot(crew) {
    let unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      return

    let idInCountry = crew.idInCountry
    let countryId = crew.idCountry
    let slotObj = ::get_slot_obj(this.scene, countryId, idInCountry)
    if (!slotObj)
      return

    let params = this.getSlotbarParams()
    params.curSlotIdInCountry <- idInCountry
    params.curSlotCountryId <- countryId
    params.unlocked <- ::isUnitUnlocked(unit, countryId, idInCountry, ::get_local_player_country(), this.missionRules)
    params.weaponPrice <- this.getWeaponPrice(unit.name, getLastWeapon(unit.name))
    if (idInCountry in this.slotDelayDataByCrewIdx)
      params.slotDelayData <- this.slotDelayDataByCrewIdx[idInCountry]

    let priceTextObj = slotObj.findObject("bottom_item_price_text")
    if (checkObj(priceTextObj)) {
      let bottomText = ::get_unit_item_price_text(unit, params)
      priceTextObj.tinyFont = ::is_unit_price_text_long(bottomText) ? "yes" : "no"
      priceTextObj.setValue(bottomText)
    }

    let nameObj = slotObj.findObject($"{::get_slot_obj_id(countryId, idInCountry)}_txt")
    if (checkObj(nameObj))
      nameObj.setValue(::get_slot_unit_name_text(unit, params))

    if (!this.missionRules.isRespawnAvailable(unit))
      slotObj.shopStat = "disabled"
  }

  function updateAllCrewSlots() {
    foreach (crew in ::get_crews_list_by_country(::get_local_player_country()))
      this.updateCrewSlot(crew)
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
      btn_QuitMission =     this.showButtons && this.isRespawn && this.isNoRespawns && ::g_mis_loading_state.isReadyToShowRespawn()
      btn_back =            this.showButtons && useTouchscreen && !this.isRespawn
      btn_activateorder =   this.showButtons && this.isRespawn && ::g_orders.showActivateOrderButton() && (!this.isSpectate || !showConsoleButtons.value)
      btn_personal_tasks =  this.showButtons && this.isRespawn && canUseUnlocks
    }
    foreach (id, value in buttons)
      this.showSceneBtn(id, value)

    let crew = this.getCurCrew()
    let slotObj = crew && ::get_slot_obj(this.scene, crew.idCountry, crew.idInCountry)
    showObjById("buttonsDiv", show && this.isRespawn, slotObj)
  }

  function updateCountdown(countdown) {
    let isLoadingUnitModel = !this.stayOnRespScreen && !canRequestAircraftNow()
    this.showLoadAnim(!this.isGTCooperative
      && (isLoadingUnitModel || !::g_mis_loading_state.isReadyToShowRespawn()))
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
      ::hide_game_chat_scene_input(this.curChatData, !this.isRespawn && !this.isSpectate)
  }

  function loadChatScene(chatBlkName) {
    let chatObj = this.scene.findObject(this.isSpectate ? "mpChatInSpectator" : "mpChatInRespawn")
    if (!checkObj(chatObj))
      return

    if (this.curChatData) {
      if (checkObj(this.curChatData.scene))
        this.guiScene.replaceContentFromText(this.curChatData.scene, "", 0, null)
      ::detachGameChatSceneData(this.curChatData)
    }

    this.curChatData = ::loadGameChatToObj(chatObj, chatBlkName, this,
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
    ::force_spectator_camera_rotation(isRespawnSceneActive && this.isSpectate)
  }

  function setSpectatorMode(is_spectator, forceShowInfo = false) {
    if (this.isSpectate == is_spectator && !forceShowInfo)
      return

    this.isSpectate = is_spectator
    this.showSpectatorInfo(is_spectator)
    this.setOrdersEnabled(this.isSpectate)
    this.updateSpectatorRotationForced()

    this.shouldBlurSceneBg = !this.isSpectate ? needUseHangarDof() : false
    handlersManager.updateSceneBgBlur()

    this.shouldFadeSceneInVr = !this.isSpectate
    handlersManager.updateSceneVrParams()

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
      ::g_orders.enableOrders(statusObj)
  }

  function showSpectatorInfo(status) {
    if (!checkObj(this.scene))
      return

    this.setSceneTitle(status ? "" : ::getCurMpTitle(), this.scene, "respawn_title")

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
    let player = get_mplayers_list(GET_MPLAYERS_LIST, true).findvalue(@(p) p.id == targetId)
    let color = player != null ? ::get_mplayer_color(player) : "teamBlueColor"

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

    this.guiScene.performDelayed(this, function() {
      ::disable_flight_menu(false)
      ::gui_start_flight_menu()
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

    ::show_hud(!this.scene.findObject("respawn_screen").isVisible())
  }

  function showHud() {
    if (!checkObj(this.scene) || this.scene.findObject("respawn_screen").isVisible())
      return false
    ::show_hud(true)
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
    ::show_hud(false)
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

  function onMpStatScreen(_obj) {
    if (!canRequestAircraftNow())
      return

    this.guiScene.performDelayed(this, function() {
      ::disable_flight_menu(false)
      guiStartMPStatScreen()
    })
  }

  function getCurrentEdiff() {
    return ::get_mission_mode()
  }

  function onQuitMission(_obj) {
    ::quit_mission()
  }

  onPersonalTasksOpen = @() openPersonalTasks()

  function goBack() {
    if (!this.isRespawn)
      ::close_ingame_gui()
  }

  function onEventUpdateEsFromHost(_p) {
    if (this.isSceneActive())
      this.reinitScreen({})
  }

  function onEventUnitWeaponChanged(_p) {
    let crew = this.getCurCrew()
    let unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      return

    if (this.missionRules.hasRespawnCost)
      this.updateCrewSlot(crew)

    this.updateOptions(RespawnOptUpdBit.UNIT_WEAPONS)
    this.checkReady()
  }

  function onEventBulletsGroupsChanged(_p) {
    let crew = this.getCurCrew()
    if (this.missionRules.hasRespawnCost)
      this.updateCrewSlot(crew)

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

    this.showSceneBtn("mis_obj_text_header", !this.canSwitchChatSize)
    this.showSceneBtn("mis_obj_button_header", this.canSwitchChatSize)

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
}

::cant_respawn_anymore <- function cant_respawn_anymore() { // called when no more respawn bases left
  if (::current_base_gui_handler && ("stayOnRespScreen" in ::current_base_gui_handler))
    ::current_base_gui_handler.stayOnRespScreen = true
}

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

  if (!::g_mis_loading_state.isCrewsListReceived())
    return false

  let team = ::get_mp_local_team()
  let country = ::get_local_player_country()
  let crews = ::get_crews_list_by_country(country)
  if (!crews)
    return false

  log($"Looking for country {country} in team {team}")

  let missionRules = ::g_mis_custom_state.getCurMissionRules()
  let leftRespawns = missionRules.getLeftRespawns()
  if (leftRespawns == 0)
    return false

  let curSpawnScore = missionRules.getCurSpawnScore()
  foreach (c in crews) {
    let air = ::g_crew.getCrewUnit(c)
    if (!air)
      continue

    if (!::is_crew_available_in_session(c.idInCountry, false)
        || !::is_crew_slot_was_ready_at_host(c.idInCountry, air.name, false)
        || !getAvailableRespawnBases(air.tags).len()
        || !missionRules.getUnitLeftRespawns(air)
        || !missionRules.isUnitEnabledBySessionRank(air)
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
