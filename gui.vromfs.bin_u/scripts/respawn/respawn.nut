local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local statsd = require("statsd")
local time = require("scripts/time.nut")
local respawnBases = require("scripts/respawn/respawnBases.nut")
local gamepadIcons = require("scripts/controls/gamepadIcons.nut")
local contentPreset = require("scripts/customization/contentPreset.nut")
local actionBarInfo = require("scripts/hud/hudActionBarInfo.nut")
local { getWeaponNameText } = require("scripts/weaponry/weaponryDescription.nut")
local { getLastWeapon,
        setLastWeapon,
        isWeaponEnabled,
        isWeaponVisible,
        getOverrideBullets } = require("scripts/weaponry/weaponryInfo.nut")
local { getModificationName, getUnitLastBullets } = require("scripts/weaponry/bulletsInfo.nut")
local { AMMO,
        getAmmoAmount,
        getAmmoMaxAmountInSession,
        getAmmoAmountData } = require("scripts/weaponry/ammoInfo.nut")
local { getModificationByName } = require("scripts/weaponry/modificationInfo.nut")
local { setColoredDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local { bombNbr, hasCountermeasures } = require("scripts/unit/unitStatus.nut")
local { checkInRoomMembers } = require("scripts/contacts/updateContactsStatus.nut")
local { setMousePointerInitialPos } = require("scripts/controls/mousePointerInitialPos.nut")
local { isTripleColorSmokeAvailable } = require("scripts/options/optionsManager.nut")
local { DECORATION } = require("scripts/utils/genericTooltipTypes.nut")
local { getEventSlotbarHint } = require("scripts/events/eventInfo.nut")
local { needUseHangarDof } = require("scripts/viewUtils/hangarDof.nut")

::last_ca_aircraft <- null
::used_planes <- {}
::need_race_finish_results <- false

::before_first_flight_in_session <- false

::g_script_reloader.registerPersistentData("RespawnGlobals", ::getroottable(),
  ["last_ca_aircraft","used_planes", "need_race_finish_results", "before_first_flight_in_session"])

::COLORED_DROPRIGHT_TEXT_STYLE <- "textStyle:t='textarea';"

enum ESwitchSpectatorTarget
{
  E_DO_NOTHING,
  E_NEXT,
  E_PREV
}

::respawn_options <- [
  {id = "skin",        hint = "options/skin",
    user_option = ::USEROPT_SKIN, isShowForRandomUnit =false },
  {id = "user_skins",  hint = "options/user_skins",
    user_option = ::USEROPT_USER_SKIN, isShowForRandomUnit =false,
    isVisible = @() ::has_feature("UserSkins") },
  {id = "gundist",     hint = "options/gun_target_dist",
    user_option = ::USEROPT_GUN_TARGET_DISTANCE},
  {id = "gunvertical", hint = "options/gun_vertical_targeting", user_option = ::USEROPT_GUN_VERTICAL_TARGETING},
  {id = "bomb_activation_type",    hint = "options/bomb_activation_time",
    user_option = ::USEROPT_BOMB_ACTIVATION_TIME, isShowForRandomUnit =false },
  {id = "bomb_series",    hint = "options/bomb_series",
    user_option = ::USEROPT_BOMB_SERIES, isShowForRandomUnit =false },
  {id = "depthcharge_activation_time",  hint = "options/depthcharge_activation_time",
     user_option = ::USEROPT_DEPTHCHARGE_ACTIVATION_TIME, isShowForRandomUnit =false },
  {id = "rocket_fuse_dist",  hint = "options/rocket_fuse_dist",
    user_option = ::USEROPT_ROCKET_FUSE_DIST, isShowForRandomUnit =false },
  {id = "torpedo_dive_depth",  hint = "options/torpedo_dive_depth",
    user_option = ::USEROPT_TORPEDO_DIVE_DEPTH, isShowForRandomUnit =false,
    isVisible = @() !::get_option_torpedo_dive_depth_auto() },
  {id = "fuel",        hint = "options/fuel_amount",
    user_option = ::USEROPT_LOAD_FUEL_AMOUNT, isShowForRandomUnit =false },
  {id = "countermeasures_periods",        hint = "options/countermeasures_periods",
    user_option = ::USEROPT_COUNTERMEASURES_PERIODS, isShowForRandomUnit =false },
  {id = "countermeasures_series_periods", hint = "options/countermeasures_series_periods",
    user_option = ::USEROPT_COUNTERMEASURES_SERIES_PERIODS, isShowForRandomUnit =false },
  {id = "countermeasures_series",         hint = "options/countermeasures_series",
    user_option = ::USEROPT_COUNTERMEASURES_SERIES, isShowForRandomUnit =false },
  {id = "respawn_base",hint = "options/respawn_base",        cb = "onRespawnbaseOptionUpdate", use_margin_top = true},
  {id = "smoke_type", hint = "options/aerobatics_smoke_type",
    user_option = ::USEROPT_AEROBATICS_SMOKE_TYPE, cb = "onSmokeTypeUpdate", isSmokeType = true},
  {id = "smoke_left_color", hint = "options/aerobatics_smoke_left_color",
    user_option = ::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, isSmokeColor = true},
  {id = "smoke_right_color", hint = "options/aerobatics_smoke_right_color",
    user_option = ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, isSmokeColor = true},
  {id = "smoke_tail_color", hint = "options/aerobatics_smoke_tail_color",
    user_option = ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR, isSmokeColor = true},
]

::gui_start_respawn <- function gui_start_respawn(is_match_start = false)
{
  ::mp_stat_handler = ::handlersManager.loadHandler(::gui_handlers.RespawnHandler)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_respawn)
}

class ::gui_handlers.RespawnHandler extends ::gui_handlers.MPStatistics
{
  sceneBlkName = "gui/respawn.blk"
  shouldBlurSceneBg = true
  keepLoaded = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_NONE

  showButtons = true
  sessionWpBalance = 0

  slotDelayDataByCrewIdx = {}

  //temporary hack before real fix will appear at all platforms.
  needCheckSlotReady = true //!::is_version_equals_or_newer("1.51.7.81")
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

  bulletsDescr = array(::BULLETS_SETS_QUANTITY, null)

  skins = null

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

  function initScreen()
  {
    showSceneBtn("tactical-map-box", true)
    showSceneBtn("tactical-map", true)

    missionRules = ::g_mis_custom_state.getCurMissionRules()

    checkFirstInit()

    ::disable_flight_menu(true)

    needPlayersTbl = false
    isApplyPressed = false
    doRespawnCalled = false
    local wasIsRespawn = isRespawn
    isRespawn = ::is_respawn_screen()
    needRefreshSlotbarOnReinit = isRespawn || wasIsRespawn

    initStatsMissionParams()

    isFriendlyUnitsExists = isModeWithFriendlyUnits(gameType)

    updateCooldown = -1
    wasTimeLeft = -1000
    mplayerTable = ::get_local_mplayer() || {}
    missionTable = missionRules.missionParams

    readyForRespawn = readyForRespawn && isRespawn
    recountStayOnRespScreen()

    updateSpawnScore(true)
    updateLeftRespawns()

    local blk = ::dgs_get_game_params()
    autostartTime = blk.autostartTime;
    autostartShowTime = blk.autostartShowTime;
    autostartShowInColorTime = blk.autostartShowInColorTime;

    dagor.debug("stayOnRespScreen = "+stayOnRespScreen)

    local spectator = isSpectator()
    haveSlotbar = (gameType & (::GT_VERSUS | ::GT_COOPERATIVE)) &&
                  (gameMode != ::GM_SINGLE_MISSION && gameMode != ::GM_DYNAMIC) &&
                  !spectator
    isGTCooperative = (gameType & ::GT_COOPERATIVE) != 0
    canChangeAircraft = haveSlotbar && !stayOnRespScreen && isRespawn

    if (fetch_change_aircraft_on_start() && !stayOnRespScreen && !spectator)
    {
      dagor.debug("fetch_change_aircraft_on_start() true")
      isRespawn = true
      stayOnRespScreen = false
      canChangeAircraft = true
    }

    if (missionRules.isScoreRespawnEnabled)
      canChangeAircraft = canChangeAircraft && curSpawnScore >= missionRules.getMinimalRequiredSpawnScore()
    canChangeAircraft = canChangeAircraft && leftRespawns != 0

    setSpectatorMode(isRespawn && stayOnRespScreen && isFriendlyUnitsExists, true)
    createRespawnOptions()

    loadChat()

    updateRespawnBasesStatus()
    initAircraftSelect()
    init_options() //for disable menu only

    updateApplyText()
    updateButtons()
    ::add_tags_for_mp_players()

    showSceneBtn("screen_button_back", ::use_touchscreen && !isRespawn)
    showSceneBtn("gamercard_bottom", isRespawn)

    if (gameType & ::GT_RACE)
    {
      local finished = ::race_finished_by_local_player()
      if (finished && ::need_race_finish_results)
        ::gui_start_mpstatscreen_from_game()
      ::need_race_finish_results = !finished
    }

    local ordersButton = scene.findObject("btn_activateorder")
    if (::checkObj(ordersButton))
      ordersButton.setUserData(this)

    updateControlsAllowMask()
    updateVoiceChatWidget(!isRespawn)
    checkInRoomMembers()
  }

  function isModeWithFriendlyUnits(gt = null)
  {
    if (gt == null)
      gt = ::get_game_type()
    return !!(gt & ::GT_RACE) || !(gt & (::GT_FFA_DEATHMATCH | ::GT_FFA))
  }

  function recountStayOnRespScreen() //return isChanged
  {
    local newHaveSlots = ::has_available_slots()
    local newStayOnRespScreen = missionRules.isStayOnRespScreen() || !newHaveSlots
    if ((newHaveSlots == haveSlots) && (newStayOnRespScreen == stayOnRespScreen))
      return false

    haveSlots = newHaveSlots
    stayOnRespScreen = newStayOnRespScreen
    return true
  }

  function checkFirstInit()
  {
    if (!isFirstInit)
      return
    isFirstInit = false

    isFirstUnitOptionsInSession = ::before_first_flight_in_session

    scene.findObject("stat_update").setUserData(this)

    subHandlers.append(
      ::gui_load_mission_objectives(scene.findObject("primary_tasks_list"),   true, 1 << ::OBJECTIVE_TYPE_PRIMARY),
      ::gui_load_mission_objectives(scene.findObject("secondary_tasks_list"), true, 1 << ::OBJECTIVE_TYPE_SECONDARY)
    )

    local navBarObj = scene.findObject("gamercard_bottom_navbar_place")
    if (::checkObj(navBarObj))
    {
      navBarObj.show(true)
      navBarObj["id"] = "nav-help"
      guiScene.replaceContent(navBarObj, "gui/navRespawn.blk", this)
    }

    includeMissionInfoBlocksToGamercard()
    updateLeftPanelBlock()
    initTeamUnitsLeftView()

    tmapBtnObj  = scene.findObject("tmap_btn")
    tmapHintObj = scene.findObject("tmap_hint")
    tmapIconObj = scene.findObject("tmap_icon")
    tmapRespawnBaseTimerObj = scene.findObject("tmap_respawn_base_timer")
    SecondsUpdater(tmapRespawnBaseTimerObj, (@(obj, params) updateRespawnBaseTimerText()).bindenv(this))
  }

  function updateRespawnBaseTimerText()
  {
    local text = ""
    if (isRespawn && respawnBasesList.len())
    {
      local timeLeft = curRespawnBase ? ::get_respawn_base_time_left_by_id(curRespawnBase.id) : -1
      if (timeLeft > 0)
        text = ::loc("multiplayer/respawnBaseAvailableTime", { time = time.secondsToString(timeLeft) })
    }
    tmapRespawnBaseTimerObj.setValue(text)
  }

  function initTeamUnitsLeftView()
  {
    if (!missionRules.hasCustomUnitRespawns())
      return

    local handler = ::handlersManager.loadHandler(::gui_handlers.teamUnitsLeftView,
      { scene = scene.findObject("team_units_left_respawns"), missionRules = missionRules })
    registerSubHandler(handler)
    teamUnitsLeftWeak = handler?.weakref()
  }

  /*override*/ function onSceneActivate(show)
  {
    setOrdersEnabled(show && isSpectate)
    updateSpectatorRotationForced(show)
    updateTacticalMapUnitType(show ? null : false)
    base.onSceneActivate(show)
  }

  function getOrderStatusObj()
  {
    local statusObj = scene.findObject("respawn_order_status")
    return ::checkObj(statusObj) ? statusObj : null
  }

  function isSpectator()
  {
    return ::getTblValue("spectator", mplayerTable, false)
  }

  function updateRespawnBasesStatus() //return is isNoRespawns changed
  {
    local wasIsNoRespawns = isNoRespawns
    if (isGTCooperative)
    {
      isNoRespawns = false
      updateNoRespawnText()
      return wasIsNoRespawns != isNoRespawns
    }

    noRespText = ""
    if (!::g_mis_loading_state.isReadyToShowRespawn())
    {
      isNoRespawns = true
      readyForRespawn = false
      noRespText = ::loc("multiplayer/loadingMissionData")
    } else
    {
      local isAnyBases = missionRules.isAnyUnitHaveRespawnBases()
      readyForRespawn = readyForRespawn && isAnyBases

      isNoRespawns = true
      if (!isAnyBases)
        noRespText = ::loc("multiplayer/noRespawnBasesLeft")
      else if (missionRules.isScoreRespawnEnabled && curSpawnScore < missionRules.getMinimalRequiredSpawnScore())
        noRespText = isRespawn? ::loc("multiplayer/noSpawnScore") : ""
      else if (leftRespawns == 0)
        noRespText = ::loc("multiplayer/noRespawnsInMission")
      else if (!haveSlots)
        noRespText = ::loc("multiplayer/noCrewsLeft")
      else
        isNoRespawns = false
    }

    updateNoRespawnText()
    return wasIsNoRespawns != isNoRespawns
  }

  function updateCurSpawnScoreText()
  {
    local scoreObj = scene.findObject("gc_spawn_score")
    if (::checkObj(scoreObj) && missionRules.isScoreRespawnEnabled)
      scoreObj.setValue(::getCompoundedText(::loc("multiplayer/spawnScore") + " ", curSpawnScore, "activeTextColor"))
  }

  function updateSpawnScore(isOnInit = false)
  {
    if (!missionRules.isScoreRespawnEnabled ||
      !::g_mis_loading_state.isReadyToShowRespawn())
      return

    local newSpawnScore = missionRules.getCurSpawnScore()
    if (!isOnInit && curSpawnScore == newSpawnScore)
      return

    curSpawnScore = newSpawnScore

    local newSpawnScoreMask = calcCrewSpawnScoreMask()
    if (crewsSpawnScoreMask != newSpawnScoreMask)
    {
      crewsSpawnScoreMask = newSpawnScoreMask
      if (!isOnInit && isRespawn)
        return reinitScreen({})
      else
        updateAllCrewSlots()
    }

    updateCurSpawnScoreText()
  }

  function calcCrewSpawnScoreMask()
  {
    local res = 0
    foreach(idx, crew in ::get_crews_list_by_country(::get_local_player_country()))
    {
      local unit = ::g_crew.getCrewUnit(crew)
      if (unit && ::shop_get_spawn_score(unit.name, "", []) >= curSpawnScore)
        res = res | (1 << idx)
    }
    return res
  }

  function updateLeftRespawns()
  {
    leftRespawns = missionRules.getLeftRespawns()
    customStateCrewAvailableMask = missionRules.getCurCrewsRespawnMask()
  }

  function updateRespawnWhenChangedMissionRespawnBasesStatus()
  {
    local isStayOnrespScreenChanged = recountStayOnRespScreen()
    local isNoRespawnsChanged = updateRespawnBasesStatus()
    if (!stayOnRespScreen  && !isNoRespawns
        && (isStayOnrespScreenChanged || isNoRespawnsChanged))
    {
      reinitScreen({})
      return
    }

    reinitSlotbar()
    updateOtherOptions()
    updateButtons()
    updateApplyText()
    checkReady()
  }

  function onEventChangedMissionRespawnBasesStatus(params)
  {
    doWhenActiveOnce("updateRespawnWhenChangedMissionRespawnBasesStatus")
  }

  function updateNoRespawnText()
  {
    local noRespObj = scene.findObject("txt_no_respawn_bases")
    if (::checkObj(noRespObj))
    {
      noRespObj.setValue(noRespText)
      noRespObj.show(isNoRespawns)
    }
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initScreen()
  }

  function createRespawnOptions()
  {
    local dObj = scene.findObject("respawn_options_table")
    local optionObj = dObj.findObject("option_row_sample")
    local newOptionObj = null

    if(!::checkObj(optionObj))
      return

    foreach (option in ::respawn_options)
    {
      local isShow = option?.isVisible ? option.isVisible() : true
      if (!isShow)
        continue

      local newOptLableObj = null
      local newDroprightObj = null
      newOptionObj = optionObj.getClone(dObj, this)
      newOptionObj.id = option.id + "_tr"

      newOptLableObj = newOptionObj.findObject("option_lable")
      newOptLableObj.id = "lbl_" + option.id
      newOptLableObj.setValue(::loc(option.hint))

      newDroprightObj = newOptionObj.findObject("option")
      newDroprightObj.id = option.id
      if ("cb" in option && option.cb)
        newDroprightObj.on_select = option.cb
      else
        newDroprightObj.on_select = "checkReady"

      newOptionObj.show(true)
      newOptionObj.enable(isRespawn)
    }
    guiScene.destroyElement(optionObj)
  }

  function initAircraftSelect()
  {
    if (::show_aircraft == null)
      ::show_aircraft = getAircraftByName(::last_ca_aircraft)

    dagor.debug("initScreen aircraft "+ ::last_ca_aircraft + " show_aircraft " + ::show_aircraft);

    scene.findObject("CA_div").show(haveSlotbar)
    updateSessionWpBalance()

    if (haveSlotbar)
    {
      local needWaitSlotbar = !::g_mis_loading_state.isReadyToShowRespawn() && !isSpectator()
      showSceneBtn("slotbar_load_wait", needWaitSlotbar)
      if (!isSpectator() && ::g_mis_loading_state.isReadyToShowRespawn()
          && (needRefreshSlotbarOnReinit || !slotbarWeak))
      {
        slotbarInited = false
        beforeRefreshSlotbar()
        createSlotbar(getSlotbarParams()
          .__update({ slotbarHintText = getEventSlotbarHint(
            ::SessionLobby.getRoomEvent(), ::get_local_player_country()) }),
          "flight_menu_bgd")
        afterRefreshSlotbar()
        slotReadyAtHostMask = getCrewSlotReadyMask()
        slotbarInited = true
        updateUnitOptions()

        if (canChangeAircraft)
          readyForRespawn = false

        if (isRespawn)
          setMousePointerInitialPos(getSlotbar()?.getCurrentCrewSlot().findObject("extra_info_block"))
      }
    }
    else
    {
      destroySlotbar()
      local airName = ::last_ca_aircraft
      if (isGTCooperative)
        airName = ::getTblValue("aircraftName", mplayerTable, "")
      local air = ::getAircraftByName(airName)
      if (air)
      {
        ::show_aircraft = air
        scene.findObject("air_info_div").show(true)
        local data = ::build_aircraft_item(air.name, air, {
          showBR        = ::has_feature("SlotbarShowBattleRating")
          getEdiffFunc  = getCurrentEdiff.bindenv(this)
        })
        guiScene.replaceContentFromText(scene.findObject("air_item_place"), data, data.len(), this)
        ::fill_unit_item_timers(scene.findObject("air_item_place").findObject(air.name), air)
      }
    }

    setRespawnCost()
    reset_mp_autostart_countdown();
  }

  function getSlotbarParams()
  {
    local playerCountry = ::get_local_player_country()
    return {
      singleCountry = playerCountry
      hasActions = false
      showNewSlot = false
      showEmptySlot = false
      toBattle = canChangeAircraft
      haveRespawnCost = missionRules.hasRespawnCost
      haveSpawnDelay = missionRules.isSpawnDelayEnabled
      totalSpawnScore = curSpawnScore
      sessionWpBalance = sessionWpBalance
      checkRespawnBases = true
      missionRules = missionRules
      hasExtraInfoBlock = true
      shouldSelectAvailableUnit = isRespawn
      customViewCountryData = { [playerCountry] = {
        icon = missionRules.getOverrideCountryIconByTeam(::get_mp_local_team())
      }}

      beforeSlotbarSelect = beforeSlotbarSelect
      afterSlotbarSelect = onChangeUnit
      onSlotDblClick = ::Callback(@(crew) onApply(), this)
      beforeFullUpdate = beforeRefreshSlotbar
      afterFullUpdate = afterRefreshSlotbar
      onSlotBattleBtn = onApply
    }
  }

  function updateSessionWpBalance()
  {
    if (!(missionRules.isWarpointsRespawnEnabled && isRespawn))
      return

    local info = ::get_cur_rank_info()
    local curWpBalance = ::get_cur_warpoints()
    sessionWpBalance = curWpBalance + info.cur_award_positive - info.cur_award_negative
  }

  function setRespawnCost()
  {
    local showWPSpend = missionRules.isWarpointsRespawnEnabled && isRespawn
    local wpBalance = ""
    if (showWPSpend)
    {
      updateSessionWpBalance()
      local info = ::get_cur_rank_info()
      local curWpBalance = ::get_cur_warpoints()
      local total = sessionWpBalance
      if (curWpBalance != total || (info.cur_award_positive != 0 && info.cur_award_negative != 0))
      {
        local curWpBalanceString = ::Cost(curWpBalance).toStringWithParams({isWpAlwaysShown = true})
        local curPositiveIncrease = ""
        local curNegativeDecrease = ""
        local color = info.cur_award_positive > 0? "good" : "bad"
        local curDifference = info.cur_award_positive
        if (info.cur_award_positive < 0)
        {
          curDifference = info.cur_award_positive - info.cur_award_negative
          color = "bad"
        }
        else if (info.cur_award_negative != 0)
          curNegativeDecrease = "<color=@badTextColor>" +
            ::Cost(-1*info.cur_award_negative).toStringWithParams({isWpAlwaysShown = true}) + "</color>"

        if (curDifference != 0)
          curPositiveIncrease = "<color=@" + color + "TextColor>" + (curDifference > 0? "+" : "") +
            ::Cost(curDifference).toStringWithParams({isWpAlwaysShown = true}) + "</color>"

        local totalString = " = <color=@activeTextColor>" +
          ::Cost(total).toStringWithParams({isWpAlwaysShown = true}) + "</color>"
        wpBalance = curWpBalanceString + curPositiveIncrease + curNegativeDecrease + totalString
      }
    }

    local balanceObj = getObj("gc_wp_respawn_balance")
    if (::checkObj(balanceObj))
    {
      local text = ""
      if (wpBalance != "")
        text = ::getCompoundedText(::loc("multiplayer/wp_header"), wpBalance, "activeTextColor")
      balanceObj.setValue(text)
    }
  }

  function getRespawnWpTotalCost()
  {
    if(!missionRules.isWarpointsRespawnEnabled)
      return 0

    local air = getCurSlotUnit()
    local airRespawnCost = air ? ::get_unit_wp_to_respawn(air.name) : 0
    local weaponPrice = air ? getWeaponPrice(air.name, getSelWeapon()) : 0
    return airRespawnCost + weaponPrice
  }

  function isInAutoChangeDelay()
  {
    return ::dagor.getCurTime() - prevUnitAutoChangeTimeMsec < delayAfterAutoChangeUnitMsec
  }

  function beforeRefreshSlotbar()
  {
    if (!isInAutoChangeDelay())
      prevAutoChangedUnit = getCurSlotUnit()
  }

  function afterRefreshSlotbar()
  {
    local curUnit = getCurSlotUnit()
    if (curUnit && curUnit != prevAutoChangedUnit)
      prevUnitAutoChangeTimeMsec = ::dagor.getCurTime()

    updateApplyText()

    if (!needCheckSlotReady)
      return

    slotReadyAtHostMask = getCrewSlotReadyMask()
    slotsCostSum = getSlotsSpawnCostSumNoWeapon()
  }

  //hack: to check slotready changed
  function checkCrewAccessChange()
  {
    if (!getSlotbar()?.singleCountry || !slotbarInited)
      return

    local needReinitSlotbar = false

    local newMask = getCrewSlotReadyMask()
    if (newMask != slotReadyAtHostMask)
    {
      dagor.debug("Error: is_crew_slot_was_ready_at_host or is_crew_available_in_session have changed without cb. force reload slots")
      statsd.send_counter("sq.errors.change_disabled_slots", 1, {mission = ::get_current_mission_name()})
      needReinitSlotbar = true
    }

    local newSlotsCostSum = getSlotsSpawnCostSumNoWeapon()
    if (newSlotsCostSum != slotsCostSum)
    {
      dagor.debug("Error: slots spawn cost have changed without cb. force reload slots")
      statsd.send_counter("sq.errors.changed_slots_spawn_cost", 1, {mission = ::get_current_mission_name()})
      needReinitSlotbar = true
    }

    if (needReinitSlotbar && getSlotbar())
      getSlotbar().forceUpdate()
  }

  function getCrewSlotReadyMask()
  {
    local res = 0
    if (!::g_mis_loading_state.isCrewsListReceived())
      return res

    local MAX_UNIT_SLOTS = 16
    for(local i = 0; i < MAX_UNIT_SLOTS; i++)
      if (::is_crew_slot_was_ready_at_host(i, "", false) && ::is_crew_available_in_session(i, false))
        res += (1 << i)
    return res
  }

  function getSlotsSpawnCostSumNoWeapon()
  {
    local res = 0
    local crewsCountry = ::g_crews_list.get()?[getCurCrew()?.idCountry]
    if (!crewsCountry)
      return res

    foreach(crew in crewsCountry.crews)
    {
      local unit = ::g_crew.getCrewUnit(crew)
      if (unit)
        res += ::shop_get_spawn_score(unit.name, "", [])
    }
    return res
  }

  function beforeSlotbarSelect(onOk, onCancel, selSlot)
  {
    if (!canChangeAircraft && slotbarInited)
    {
      onCancel()
      return
    }

    local unit = ::getSlotAircraft(selSlot.countryId, selSlot.crewIdInCountry)
    local crew = ::getSlotItem(selSlot.countryId, selSlot.crewIdInCountry)
    local isAvailable = ::is_crew_available_in_session(selSlot.crewIdInCountry, false)
      && missionRules.isUnitEnabledBySessionRank(unit)
    if (crew == null) {
      onCancel()
      return
    }

    if (unit && (isAvailable || !slotbarInited))  //can init wnd without any available aircrafts
    {
      onOk()
      return
    }

    if (!::has_available_slots())
      return onOk()

    onCancel()

    local cantSpawnReason = getCantSpawnReason(crew)
    if (cantSpawnReason)
      ::showInfoMsgBox(cantSpawnReason.text, cantSpawnReason.id, true)
  }

  function onChangeUnit()
  {
    local unit = getCurSlotUnit()
    if (!unit)
      return

    if (slotbarInited)
      prevUnitAutoChangeTimeMsec = -1
    ::cur_aircraft_name = unit.name

    slotbarInited=true
    onAircraftUpdate()
  }

  function updateWeaponsSelector(isUnitChanged)
  {
    local unit = getCurSlotUnit()
    local isRandomUnit = unit && missionRules && missionRules.getRandomUnitsGroupName(unit.name)
    local shouldShowWeaponry = (!isRandomUnit || !isRespawn) && !getOverrideBullets(unit)
    local canChangeWeaponry = canChangeAircraft && shouldShowWeaponry

    local weaponsSelectorObj = scene.findObject("unit_weapons_selector")
    if (weaponsSelectorWeak)
    {
      weaponsSelectorWeak.setUnit(unit)
      weaponsSelectorWeak.setCanChangeWeaponry(canChangeWeaponry, isRespawn && !isUnitChanged)
      weaponsSelectorObj.show(shouldShowWeaponry)
      return
    }

    local handler = ::handlersManager.loadHandler(::gui_handlers.unitWeaponsHandler,
                                       { scene = weaponsSelectorObj
                                         unit = unit
                                         canShowPrice = true
                                         canChangeWeaponry = canChangeWeaponry
                                       })

    weaponsSelectorWeak = handler.weakref()
    registerSubHandler(handler)
    weaponsSelectorObj.show(shouldShowWeaponry)
  }

  function showOptionRow(id, show)
  {
    local obj = scene.findObject(id + "_tr")
    if (!::checkObj(obj))
      return false
    local respOption = ::u.search(::respawn_options, @(o) o.id == id)
    local isShowForRandomUnit = respOption?.isShowForRandomUnit ?? true

    local unit = getCurSlotUnit()
    local isRandomUnit = unit && missionRules && missionRules.getRandomUnitsGroupName(unit.name)
    show = show && (isShowForRandomUnit || !isRandomUnit)
    obj.show(show)
    obj.inactive = show ? null : "yes"
    return true
  }

  function getWeaponPrice(airName, weapon)
  {
    if(missionRules.isWarpointsRespawnEnabled
       && isRespawn
       && airName in ::used_planes
       && ::isInArray(weapon, ::used_planes[airName]))
    {
      local unit = ::getAircraftByName(airName)
      local count = getAmmoMaxAmountInSession(unit, weapon, AMMO.WEAPON) - getAmmoAmount(unit, weapon, AMMO.WEAPON)
      return (count * ::wp_get_cost2(airName, weapon))
    }
    return 0
  }

  function onSmokeTypeUpdate(obj)
  {
    checkReady(obj)
    showTripleSmokeOptions(isTripleColorSmokeAvailable())
  }

  function onRespawnbaseOptionUpdate(obj)
  {
    if (!isRespawn)
      return

    local idx = ::checkObj(obj) ? obj.getValue() : 0
    local spawn = respawnBasesList?[idx]
    if (!spawn)
      return

    if (curRespawnBase != spawn) //selected by user
      respawnBases.selectBase(getCurSlotUnit(), spawn)
    curRespawnBase = spawn
    ::select_respawnbase(curRespawnBase.mapId)
    updateRespawnBaseTimerText()
    checkReady()
  }

  function updateTacticalMapHint()
  {
    local hint = ""
    local hintIcon = ::show_console_buttons ? gamepadIcons.getTexture("r_trigger") : "#ui/gameuiskin#mouse_left"
    if (!isRespawn)
      hint = ::colorize("activeTextColor", ::loc("voice_message_attention_to_point_2"))
    else
    {
      local coords = ::get_mouse_relative_coords_on_obj(tmapBtnObj)
      if (!coords)
        hintIcon = ""
      else if (!canChooseRespawnBase)
      {
        hint = ::colorize("commonTextColor", ::loc("guiHints/respawn_base/choice_disabled"))
        hintIcon = ""
      }
      else
      {
        local spawnId = coords ? ::get_respawn_base(coords[0], coords[1]) : respawnBases.MAP_ID_NOTHING
        if (spawnId != respawnBases.MAP_ID_NOTHING)
          foreach (spawn in respawnBasesList)
            if (spawn.id == spawnId && spawn.isMapSelectable)
            {
              hint = ::colorize("userlogColoredText", spawn.getTitle())
              if (spawnId == curRespawnBase?.id)
                hint += ::colorize("activeTextColor",
                  ::loc("ui/parentheses/space",
                    { text = ::loc(curRespawnBase.isAutoSelected ? "ui/selected_auto" : "ui/selected") }))
              break
            }

        if (!hint.len())
        {
          hint = ::colorize("activeTextColor", ::loc("guiHints/respawn_base/choice_enabled"))
          hintIcon = ""
        }
      }
    }

    tmapHintObj.setValue(hint)
    tmapIconObj["background-image"] = hintIcon
  }

  function onTacticalmapClick(obj)
  {
    if (!isRespawn || !::checkObj(scene) || !canChooseRespawnBase)
      return

    local coords = ::get_mouse_relative_coords_on_obj(tmapBtnObj)
    local spawnId = coords ? ::get_respawn_base(coords[0], coords[1]) : respawnBases.MAP_ID_NOTHING

    local selIdx = -1
    if (spawnId != -1)
      foreach (idx, spawn in respawnBasesList)
        if (spawn.id == spawnId && spawn.isMapSelectable)
        {
          selIdx = idx
          break
        }

    if (selIdx == -1)
      foreach (idx, spawn in respawnBasesList)
        if (!spawn.isMapSelectable)
        {
          selIdx = idx
          break
        }

    if (selIdx != -1)
    {
      local optionObj = scene.findObject("respawn_base")
      if (::checkObj(optionObj))
        optionObj.setValue(selIdx)
    }
  }

  function onOtherOptionUpdate(obj)
  {
    reset_mp_autostart_countdown();
    if (!obj)
      return

    local air = getCurSlotUnit()
    if (!air) return

    ::aircraft_for_weapons = air.name
    local option = getUserOptionInRespawnOptions(obj?.id)
    if (!option)
      return

    local value = obj.getValue()
    ::set_option(option.type, value, option)
  }

  function getUserOptionInRespawnOptions(id)
  {
    if (!id)
      return null

    //search by respawn_option id
    foreach (option in ::respawn_options)
      if ("id" in option && option.id)
        if (id == option.id)
          if ("user_option" in option && option.user_option)
            return ::get_option(option.user_option)
          else
            return null

    //search by real option id
    foreach (option in ::respawn_options)
    {
      local optType = ::getTblValue("user_option", option)
      if (optType == null)
        continue

      local userOption = ::get_option(optType)
      if (userOption.id == id)
        return userOption
    }
    return null
  }

  function updateSkin()
  {
    local air = getCurSlotUnit()
    if (!air)
      return

    local skinObj = scene.findObject("skin")
    if (!::check_obj(skinObj))
      return

    local data = []
    local skinsData = ::g_decorator.getSkinsOption(air.name)
    local selIndex = skinsData.value

    skins = skinsData.values

    foreach (i, item in skinsData.items)
    {
      if (!canChangeAircraft && i != selIndex)
        continue
      local tooltipObjMarkup = DECORATION.getMarkup(skinsData.decorators[i].id, ::UNLOCKABLE_SKIN)
      data.append(::build_option_blk(item.text, item.image || "", i == selIndex, true,
        item.textStyle, false, "", tooltipObjMarkup))
    }

    data = ::g_string.implode(data)
    guiScene.replaceContentFromText(skinObj, data, data.len(), this)
    showOptionRow("skin", true)
  }

  function updateUserSkins()
  {
    local air = getCurSlotUnit()
    if (!air) return

    local userSkinsOption = ::get_option(::USEROPT_USER_SKIN)

    local data = ""
    for(local i = 0; i < userSkinsOption.items.len(); i++)
      data += ::build_option_blk(userSkinsOption.items[i].text, "", userSkinsOption.value == i, true, "", false, userSkinsOption.items[i].tooltip)

    local uskObj = scene.findObject("user_skins")
    if (::checkObj(uskObj))
      guiScene.replaceContentFromText(uskObj, data, data.len(), this)
    showOptionRow("user_skins", true)
  }

  function updateRespawnBases(air)
  {
    if (canChangeAircraft)
    {
      local crew = getCurCrew()
      ::set_selected_unit_info(air, crew.idInCountry)
      local rbData = respawnBases.getRespawnBasesData(air)
      curRespawnBase = rbData.selBase
      respawnBasesList = rbData.basesList
      haveRespawnBases = rbData.hasRespawnBases
      canChooseRespawnBase = rbData.canChooseRespawnBase
    } else
    {
      curRespawnBase = respawnBases.getSelectedBase()
      respawnBasesList = curRespawnBase ? [curRespawnBase] : []
      haveRespawnBases = curRespawnBase != null
      canChooseRespawnBase = false
    }

    if (haveRespawnBases)
    {
      local respawnBaseObj = scene.findObject("respawn_base")
      if (::checkObj(respawnBaseObj))
      {
        local data = ""
        foreach (i, spawn in respawnBasesList)
          data += ::build_option_blk(spawn.getTitle(), "", curRespawnBase == spawn)
        guiScene.replaceContentFromText(respawnBaseObj, data, data.len(), this);
        onRespawnbaseOptionUpdate(respawnBaseObj)
      }
    }

    showRespawnTr(haveRespawnBases)
  }

  function showRespawnTr(show)
  {
    local obj = scene.findObject("respawn_base_tr")
    if (::checkObj(obj))
      obj.show(show)
  }

  function updateGunVerticalOption(unit)
  {
    local isAir = unit && (unit.isAir() || unit.isHelicopter())
    showOptionRow("gunvertical", isAir && ::is_gun_vertical_convergence_allowed())

    local option = ::get_option(::USEROPT_GUN_VERTICAL_TARGETING)
    local gunVerticalObj = scene.findObject(option.id)
    if (::checkObj(gunVerticalObj))
    {
      if (gunVerticalObj.getValue() != option.value)
        gunVerticalObj.setValue(option.value)
    } else
    {
      gunVerticalObj = scene.findObject("gunvertical")
      if (!::checkObj(gunVerticalObj))
        return

      local parentObj = gunVerticalObj.getParent()
      option.cb <- "checkReady"
      local data = ::create_option_switchbox(option)
      guiScene.replaceContentFromText(parentObj, data, data.len(), this)
      gunVerticalObj = parentObj.findObject(option.id)
    }

    if (::checkObj(gunVerticalObj))
      gunVerticalObj.enable(canChangeAircraft)
  }

  function updateShipOptions(air, needUpdateOptionItems = true)
  {
    local depthChargeDescr = ::get_option(::USEROPT_DEPTHCHARGE_ACTIVATION_TIME)
    if (air.isDepthChargeAvailable() && needUpdateOptionItems)
    {
      local data = ""
      foreach (idx, item in depthChargeDescr.items)
        data += build_option_blk(item, "", idx == depthChargeDescr.value)
      local depthChargeTimeObj = scene.findObject(depthChargeDescr.id)
      if (::checkObj(depthChargeTimeObj))
        guiScene.replaceContentFromText(depthChargeTimeObj, data, data.len(), this)
    }
    showOptionRow(depthChargeDescr.id, air.isDepthChargeAvailable()
      && air.getAvailableSecondaryWeapons().hasDepthCharges)

    local torpedoDepthDescr = ::get_option(::USEROPT_TORPEDO_DIVE_DEPTH)
    local isShipOrBoat = air.isShipOrBoat()
    local torpedoDepthObj = scene.findObject(torpedoDepthDescr.id)
    if (isShipOrBoat && needUpdateOptionItems && ::check_obj(torpedoDepthObj)) {
      local data = []
      foreach (idx, item in torpedoDepthDescr.items)
        data.append(build_option_blk(item, "", idx == torpedoDepthDescr.value))
      data = "".join(data)
      guiScene.replaceContentFromText(torpedoDepthObj, data, data.len(), this)
    }
    showOptionRow(torpedoDepthDescr.id, isShipOrBoat
      && air.getAvailableSecondaryWeapons().hasTorpedoes)
  }

  function updateAircraftWeaponsOptions(unit, needUpdateOptionItems = true)
  {
    local aircraft = unit.isAir() || unit.isHelicopter()
    local bomb = false
    local rocket = false

    local weaponName = getSelWeapon()
    foreach(w in unit.weapons) {
      if (w.name == weaponName)
      {
        bomb = w.bomb
        rocket = w.rocket
      }
    }

    local bombDescr = ::get_option(::USEROPT_BOMB_ACTIVATION_TIME)
    local bombTimeObj = scene.findObject(bombDescr.id)
    if (needUpdateOptionItems && ::check_obj(bombTimeObj))
    {
      local markup = ""
      foreach (idx, item in bombDescr.items)
        if (canChangeAircraft || idx == bombDescr.value)
          markup += build_option_blk(item.text, "", idx == bombDescr.value, true, "", false, item.tooltip)
      guiScene.replaceContentFromText(bombTimeObj, markup, markup.len(), this)
    }
    showOptionRow(bombDescr.id, aircraft && bomb && unit.getAvailableSecondaryWeapons().hasBombs)

    local bombSeriesDescr = ::get_option(::USEROPT_BOMB_SERIES)
    local bombSeriesObj = scene.findObject(bombSeriesDescr.id)

    updateOptionImpl(bombSeriesDescr)
    if (needUpdateOptionItems && ::check_obj(bombSeriesObj))
    {
      local markup = ""
      foreach (idx, item in bombSeriesDescr.items)
        if (canChangeAircraft || idx == bombSeriesDescr.value)
        {
          if (idx == 0)
            markup += build_option_blk(item, "", idx == bombSeriesDescr.value)
          else
            markup += build_option_blk(item.text, "", idx == bombSeriesDescr.value, true, "", false, item.tooltip)
        }
      guiScene.replaceContentFromText(bombSeriesObj, markup, markup.len(), this)
    }
    showOptionRow(bombSeriesDescr.id, aircraft && bomb && bombNbr(unit) > 0)

    local rocketDescr = ::get_option(::USEROPT_ROCKET_FUSE_DIST)
    local rocketdistObj = scene.findObject(rocketDescr.id)
    if (needUpdateOptionItems && ::check_obj(rocketdistObj))
    {
      local markup = ""
      foreach (idx, item in rocketDescr.items)
        if (canChangeAircraft || idx == rocketDescr.value)
          markup += build_option_blk(item, "", idx == rocketDescr.value)
      guiScene.replaceContentFromText(rocketdistObj, markup, markup.len(), this)
      rocketdistObj.setValue(rocketDescr.value)
    }
    showOptionRow(rocketDescr.id,
      aircraft && rocket && unit.getAvailableSecondaryWeapons().hasRocketDistanceFuse)

    //countermeasures
    local countermeasuresPeriodsDescr = ::get_option(::USEROPT_COUNTERMEASURES_PERIODS)
    local countermeasurePeriodsObj = scene.findObject(countermeasuresPeriodsDescr.id)
    if (needUpdateOptionItems && ::check_obj(countermeasurePeriodsObj))
    {
      local markup = ""
      foreach (idx, item in countermeasuresPeriodsDescr.items)
        if (canChangeAircraft || idx == countermeasuresPeriodsDescr.value)
          markup += build_option_blk(item.text, "", idx == countermeasuresPeriodsDescr.value, true, "", false, item.tooltip)
      guiScene.replaceContentFromText(countermeasurePeriodsObj, markup, markup.len(), this)
    }
    showOptionRow(countermeasuresPeriodsDescr.id, aircraft && hasCountermeasures(unit))

    local countermeasuresSeriesPeriodsDescr = ::get_option(::USEROPT_COUNTERMEASURES_SERIES_PERIODS)
    local countermeasureSeriesPeriodsObj = scene.findObject(countermeasuresSeriesPeriodsDescr.id)
    if (needUpdateOptionItems && ::check_obj(countermeasureSeriesPeriodsObj))
    {
      local markup = ""
      foreach (idx, item in countermeasuresSeriesPeriodsDescr.items)
        if (canChangeAircraft || idx == countermeasuresSeriesPeriodsDescr.value)
          markup += build_option_blk(item.text, "", idx == countermeasuresSeriesPeriodsDescr.value, true, "", false, item.tooltip)
      guiScene.replaceContentFromText(countermeasureSeriesPeriodsObj, markup, markup.len(), this)
    }
    showOptionRow(countermeasuresSeriesPeriodsDescr.id, aircraft && hasCountermeasures(unit))

    local countermeasuresSeriesDescr = ::get_option(::USEROPT_COUNTERMEASURES_SERIES)
    local countermeasureSeriesObj = scene.findObject(countermeasuresSeriesDescr.id)
    if (needUpdateOptionItems && ::check_obj(countermeasureSeriesObj))
    {
      local markup = ""
      foreach (idx, item in countermeasuresSeriesDescr.items)
        if (canChangeAircraft || idx == countermeasuresSeriesDescr.value)
          markup += build_option_blk(item.text, "", idx == countermeasuresSeriesDescr.value, true, "", false, item.tooltip)
      guiScene.replaceContentFromText(countermeasureSeriesObj, markup, markup.len(), this)
    }
    showOptionRow(countermeasuresSeriesDescr.id, aircraft && hasCountermeasures(unit))
  }

  function updateOptionImpl(option)
  {
    local obj = scene.findObject(option.id)
    if (!::check_obj(obj))
      return

    if (option.controlType == optionControlType.LIST)
    {
      local markup = ::create_option_combobox(option.id, option.items, option.value, null, false)
      guiScene.replaceContentFromText(obj, markup, markup.len(), this)
    } else
      obj.setValue(option.value)
  }

  function fillSmokeOptions()
  {
    foreach (option in ::respawn_options)
      if (option?.isSmokeColor || option?.isSmokeType)
      {
        local optionObj = scene.findObject(option.id)
        if (!optionObj?.isValid())
          continue
        local optionDescr = ::get_option(option.user_option)
        local data = ""
        foreach (idx, item in optionDescr.items)
          if (canChangeAircraft || idx == optionDescr.value)
            data += build_option_blk(item, "", idx == optionDescr.value)
        guiScene.replaceContentFromText(optionObj, data, data.len(), this)
      }
  }

  function showTripleSmokeOptions(show)
  {
    foreach (option in ::respawn_options)
      if (option?.isSmokeColor)
        showOptionRow(option.id, show)
  }

  function updateSmokeOptions()
  {
    if (!getCurSlotUnit()?.isAir())
    {
      showOptionRow("smoke_type", false)
      showTripleSmokeOptions(false)
      return
    }

    fillSmokeOptions()
    showOptionRow("smoke_type", true)
    showTripleSmokeOptions(isTripleColorSmokeAvailable())
  }

  function updateOtherOptions()
  {
    local air = getCurSlotUnit()
    if (!air)
      return

    updateShipOptions(air)
    updateAircraftWeaponsOptions(air)
    updateRespawnBases(air)

    local aircraft = air.isAir() || air.isHelicopter()

    local gunDescr = ::get_option(::USEROPT_GUN_TARGET_DISTANCE)
    local data = ""
    foreach (idx, item in gunDescr.items)
      if (canChangeAircraft || idx == gunDescr.value)
        data += build_option_blk(item, "", idx == gunDescr.value)
    local gundistObj = scene.findObject("gundist")
    if (::checkObj(gundistObj))
      guiScene.replaceContentFromText(gundistObj, data, data.len(), this)
    showOptionRow("gundist", aircraft)

    updateGunVerticalOption(air)

    local fuelObj = scene.findObject("fuel")
    if (::checkObj(fuelObj))
    {
      local fuelDescr = ::get_option(::USEROPT_LOAD_FUEL_AMOUNT)
      data = ""
      foreach (idx, item in fuelDescr.items)
        if (canChangeAircraft || idx == fuelDescr.value)
          data += build_option_blk(item, "", idx == fuelDescr.value, true, "id:t='fuel_opt"+idx+"'; ")
      guiScene.replaceContentFromText(fuelObj, data, data.len(), this)
      fuelObj.setValue(fuelDescr.value)
    }

    showOptionRow("fuel", aircraft) //TODO: fuel for tanks
  }

  function updateUnitOptions()
  {
    local unit = getCurSlotUnit()
    local isUnitChanged = false
    if (unit)
    {
      isUnitChanged = ::aircraft_for_weapons != unit.name
      ::cur_aircraft_name = unit.name //used in some options
      ::aircraft_for_weapons = unit.name
      ::show_aircraft = unit

      if (isUnitChanged || isFirstUnitOptionsInSession)
        preselectUnitWeapon(unit)
    }

    updateTacticalMapUnitType()

    updateWeaponsSelector(isUnitChanged)
    updateOtherOptions()
    updateSkin()
    updateUserSkins()
    updateSmokeOptions()
    isFirstUnitOptionsInSession = false
    updateLeftPanelBlock()
  }

  function preselectUnitWeapon(unit)
  {
    if (unit && missionRules.getRandomUnitsGroupName(unit.name))
    {
      setLastWeapon(unit.name, missionRules.getWeaponForRandomUnit(unit, "forceWeapon"))
      return
    }

    if (!missionRules.hasWeaponLimits())
      return

    foreach(weapon in (unit?.weapons ?? []))
      if (isWeaponVisible(unit, weapon)
          && isWeaponEnabled(unit, weapon)
          && missionRules.getUnitWeaponRespawnsLeft(unit, weapon) > 0) //limited and available
     {
       setLastWeapon(unit.name, weapon.name)
       break
     }
  }

  function updateTacticalMapUnitType(isMapForSelectedUnit = null)
  {
    local hudType = ::HUD_TYPE_UNKNOWN
    if (isRespawn)
    {
      if (isMapForSelectedUnit == null)
        isMapForSelectedUnit = !isSpectate
      local unit = isMapForSelectedUnit ? getCurSlotUnit() : null
      if (unit)
        hudType = unit.unitType.hudTypeCode
    }
    ::set_tactical_map_hud_type(hudType)
  }

  function onDestroy()
  {
    updateTacticalMapUnitType(false)
  }

  function onAircraftUpdate()
  {
    updateUnitOptions()
    checkReady()
  }

  function getSelWeapon()
  {
    local unit = getCurSlotUnit()
    if (unit)
      return getLastWeapon(unit.name)
    return null
  }

  function getSelBulletsList()
  {
    local unit = getCurSlotUnit()
    if (unit)
      return getUnitLastBullets(unit)
    return null
  }

  function getSelSkin()
  {
    local skinObj = scene.findObject("skin")
    local skinIndex = null
    if (!::checkObj(skinObj))
      return skinIndex
    skinIndex = skinObj.getValue()
    if (skinIndex >= 0 && skinIndex < skins.len())
      return skins[skinIndex]
    return null
  }

  function doSelectAircraftSkipAmmo()
  {
    doSelectAircraft(false)
  }

  function doSelectAircraft(checkAmmo = true)
  {
    if (requestInProgress)
      return

    local requestData = getSelectedRequestData(false)
    if (!requestData)
      return
    if (checkAmmo && !checkCurAirAmmo(doSelectAircraftSkipAmmo))
      return
    if (!checkCurUnitSkin(doSelectAircraftSkipAmmo))
      return

    requestAircraftAndWeapon(requestData)
    if (scene.findObject("skin").getValue() > 0)
      ::req_unlock_by_client("non_standard_skin", false)

    actionBarInfo.cacheActionDescs(requestData.name)

    ::set_show_aircraft(::getAircraftByName(requestData.name))
  }

  function getSelectedRequestData(silent = true)
  {
    local air = getCurSlotUnit()
    if (!air)
    {
      dagor.debug("getCurSlotUnit() returned null?")
      return null
    }

    if (prevAutoChangedUnit && prevAutoChangedUnit != air && isInAutoChangeDelay())
    {
      if (!silent)
      {
        local msg = missionRules.getSpecialCantRespawnMessage(prevAutoChangedUnit)
        if (msg)
          ::g_popups.add(null, msg)
        prevUnitAutoChangeTimeMsec = -1
      }
      return null
    }

    local crew = getCurCrew()
    local weapon = getLastWeapon(air.name)
    local skin = ::g_decorator.getRealSkin(air.name)
    ::g_decorator.setCurSkinToHangar(air.name)
    if (!weapon || !skin)
    {
      dagor.debug("no weapon or skin selected?")
      return null
    }

    local cantSpawnReason = getCantSpawnReason(crew, silent)
    if (cantSpawnReason)
    {
      if (!silent)
        ::showInfoMsgBox(cantSpawnReason.text, cantSpawnReason.id, true)
      return null
    }

    local res = {
      name = air.name
      weapon = weapon
      skin = skin
      respBaseId = curRespawnBase?.id ?? -1
      idInCountry = crew.idInCountry
    }

    local bulletInd = 0;
    local bulletGroups = weaponsSelectorWeak ? weaponsSelectorWeak.bulletsManager.getBulletsGroups() : []
    foreach(groupIndex, bulGroup in bulletGroups)
    {
      if (!bulGroup.active)
        continue
      local modName = bulGroup.selectedName
      if (!modName)
        continue

      local count = bulGroup.bulletsCount * bulGroup.guns
      if (bulGroup.canChangeBulletsCount() && bulGroup.bulletsCount <= 0)
        continue

      if (getModificationByName(air, modName)) //!default bullets (fake)
        res["bullets" + bulletInd] <- modName
      else
        res["bullets" + bulletInd] <- ""
      res["bulletCount" + bulletInd] <- count
      bulletInd++;
    }
    while(bulletInd < ::BULLETS_SETS_QUANTITY)
    {
      res["bullets" + bulletInd] <- ""
      res["bulletCount" + bulletInd] <- 0
      bulletInd++;
    }

    local editSlotbarBullets = getOverrideBullets(air);
    if (editSlotbarBullets)
      for (local i = 0; i < ::BULLETS_SETS_QUANTITY; i++)
      {
        res["bullets" + i] = editSlotbarBullets?["bullets" + i] ?? ""
        res["bulletCount" + i] = editSlotbarBullets?["bulletsCount" + i] ?? 0
      }

    foreach(optId in [::USEROPT_GUN_TARGET_DISTANCE, ::USEROPT_GUN_VERTICAL_TARGETING,
                      ::USEROPT_BOMB_ACTIVATION_TIME,
                      ::USEROPT_ROCKET_FUSE_DIST, ::USEROPT_LOAD_FUEL_AMOUNT,
                      ::USEROPT_TORPEDO_DIVE_DEPTH
                     ])
    {
      local opt = ::get_option(optId)
      if (opt.controlType == optionControlType.LIST)
        res[opt.id] <- ::getTblValue(opt.value, opt.values)
      else
        res[opt.id] <- opt.value
    }

    return res
  }

  function getCantSpawnReason(crew, silent = true)
  {
    local unit = ::g_crew.getCrewUnit(crew)
    if (unit == null)
      return null

    local ruleMsg = missionRules.getSpecialCantRespawnMessage(unit)
    if (!::u.isEmpty(ruleMsg))
      return { text = ruleMsg, id = "cant_spawn_by_mission_rules" }

    if (isRespawn && !missionRules.isUnitEnabledBySessionRank(unit))
      return {
        text = ::loc("multiplayer/lowVehicleRank",
          { minSessionRank = ::calc_battle_rating_from_rank(missionRules.getMinSessionRank()) })
        id = "low_vehicle_rank"
      }

    if (! haveRespawnBases)
      return { text = ::loc("multiplayer/noRespawnBasesLeft"), id = "no_respawn_bases" }

    if (missionRules.isWarpointsRespawnEnabled && isRespawn)
    {
      local respawnPrice = getRespawnWpTotalCost()
      if (respawnPrice > 0 && respawnPrice > sessionWpBalance)
        return { text = ::loc("msg/not_enought_warpoints_for_respawn"), id = "not_enought_wp" }
    }

    if (missionRules.isScoreRespawnEnabled && isRespawn &&
      (curSpawnScore < ::shop_get_spawn_score(unit.name, getSelWeapon() ?? "", getSelBulletsList() ?? [])))
        return { text = ::loc("multiplayer/noSpawnScore"), id = "not_enought_score" }

    if (missionRules.isSpawnDelayEnabled && isRespawn)
    {
      local slotDelay = ::get_slot_delay(unit.name)
      if (slotDelay > 0)
      {
        local text = ::loc("multiplayer/slotDelay", { time = time.secondsToString(slotDelay) })
        return { text = text, id = "wait_for_slot_delay" }
      }
    }

    if (!::is_crew_available_in_session(crew.idInCountry, !silent))
    {
      local locId = "not_available_aircraft"
      if ((::SessionLobby.getUnitTypesMask() & (1 << ::get_es_unit_type(unit))) != 0)
        locId = "crew_not_available"
      return { text = ::SessionLobby.getNotAvailableUnitByBRText(unit) || ::loc(locId),
        id = "crew_not_available" }
    }

    if (!silent)
      dagor.debug("try to select aircraft " + unit.name)

    if (!::is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, !silent))
    {
      if (!silent)
        dagor.debug("is_crew_slot_was_ready_at_host return false for" +
          crew.idInCountry + " - " + unit.name)
      return { text = ::loc("aircraft_not_repaired"), id = "aircraft_not_repaired" }
    }

    return null
  }

  function requestAircraftAndWeapon(requestData)
  {
    if (requestInProgress)
      return

    ::set_aircraft_accepted_cb(this, aircraftAcceptedCb);
    local _taskId = ::request_aircraft_and_weapon(requestData, requestData.idInCountry, requestData.respBaseId)
    if (_taskId < 0)
      ::set_aircraft_accepted_cb(null, null);
    else
    {
      requestInProgress = true
      showTaskProgressBox(::loc("charServer/purchase0"), function() { requestInProgress = false })

      lastRequestData = requestData
    }
  }

  function aircraftAcceptedCb(result)
  {
    ::set_aircraft_accepted_cb(null, null)
    destroyProgressBox()
    requestInProgress = false

    if (!isValid())
      return

    reset_mp_autostart_countdown()

    switch (result)
    {
      case ::ERR_ACCEPT:
        onApplyAircraft(lastRequestData)
        ::update_gamercards() //update balance
        break;

      case ::ERR_REJECT_SESSION_FINISHED:
      case ::ERR_REJECT_DISCONNECTED:
        break;

      default:
        dagor.debug("Respawn Erorr: aircraft accepted cb result = " + result + ", on request:")
        debugTableData(lastRequestData)
        lastRequestData = null
        if (!::checkObj(guiScene["char_connecting_error"]))
          ::showInfoMsgBox(::loc("changeAircraftResult/"+result.tostring()), "char_connecting_error")
        break
    }
  }

  function onApplyAircraft(requestData)
  {
    if (requestData)
      ::last_ca_aircraft = requestData.name

    checkReady()
    if (readyForRespawn)
      onApply()
  }

  function checkReady(obj=null)
  {
    onOtherOptionUpdate(obj)

    readyForRespawn = lastRequestData != null && ::u.isEqual(lastRequestData, getSelectedRequestData())

    if (!readyForRespawn && isApplyPressed)
      if (!doRespawnCalled)
        isApplyPressed = false
      else
        dagor.debug("Something has changed in the aircraft selection, but too late - do_respawn was called before.")
    updateApplyText()
  }

  function updateApplyText()
  {
    local unit = getCurSlotUnit()
    local isAvailResp = haveRespawnBases || isGTCooperative
    local tooltipText = ""
    local tooltipEndText = ""
    local infoTextsArr = []
    local costTextArr = []
    local shortCostText = "" //for slot battle button

    if (isApplyPressed)
      applyText = ::loc("mainmenu/btnCancel")
    else
    {
      applyText = ::loc("mainmenu/toBattle")
      tooltipText = ::loc("mainmenu/selectAircraftTooltip")
      if (::is_platform_pc)
        tooltipEndText = ::format(" [%s]", ::loc("key/Enter"))

      if (haveSlotbar)
      {
        local wpCost = getRespawnWpTotalCost()
        if (wpCost > 0)
        {
          shortCostText = ::Cost(wpCost).getUncoloredText()
          costTextArr.append(shortCostText)
        }

        if (missionRules.isScoreRespawnEnabled && unit)
        {
          local curScore = ::shop_get_spawn_score(unit.name, getSelWeapon() ?? "", getSelBulletsList() ?? [])
          isAvailResp = isAvailResp && (curScore <= curSpawnScore)
          if (curScore > 0)
            costTextArr.append(::loc("shop/spawnScore", { cost = curScore }))
        }

        if (leftRespawns > 0)
          infoTextsArr.append(::loc("respawn/leftRespawns", { num = leftRespawns.tostring() }))

        infoTextsArr.append(missionRules.getRespawnInfoTextForUnit(unit))
        isAvailResp = isAvailResp && missionRules.isRespawnAvailable(unit)
      }
    }

    local isCrewDelayed = false
    if (missionRules.isSpawnDelayEnabled && unit)
    {
      local slotDelay = ::get_slot_delay(unit.name)
      isCrewDelayed = slotDelay > 0
    }

    //******************** combine final texts ********************************

    local applyTextShort = applyText //for slot battle button

    if (shortCostText.len())
      applyTextShort = ::format("%s<b> %s</b>", ::loc("mainmenu/toBattle/short"), shortCostText)

    local costText = ::g_string.implode(costTextArr, ", ")
    if (costText.len())
      applyText += ::loc("ui/parentheses/space", { text = costText })

    local infoText = ::g_string.implode(infoTextsArr, ", ")
    if (infoText.len())
      applyText += ::loc("ui/parentheses/space", { text = infoText })

    //******************  uodate buttons objects ******************************

    foreach (btnId in mainButtonsId)
    {
      local buttonSelectObj = setColoredDoubleTextToButton(scene.findObject("nav-help"), btnId, applyText)
      buttonSelectObj.tooltip = isSpectate ? tooltipText : tooltipText + tooltipEndText
      buttonSelectObj.isCancel = isApplyPressed ? "yes" : "no"
      buttonSelectObj.inactiveColor = (isAvailResp && !isCrewDelayed) ? "no" : "yes"
    }

    local crew = getCurCrew()
    local slotObj = crew && ::get_slot_obj(scene, crew.idCountry, crew.idInCountry)
    local slotBtnObj = setColoredDoubleTextToButton(slotObj, "slotBtn_battle", applyTextShort)
    if (slotBtnObj)
    {
      slotBtnObj.isCancel = isApplyPressed ? "yes" : "no"
      slotBtnObj.inactiveColor = (isAvailResp && !isCrewDelayed) ? "no" : "yes"
    }

    showRespawnTr(isAvailResp && !isCrewDelayed)
  }

  function setApplyPressed()
  {
    isApplyPressed = !isApplyPressed
    updateApplyText()
  }

  function onApply()
  {
    if (doRespawnCalled)
      return

    if (!haveSlots || leftRespawns == 0) {
      if (isNoRespawns)
        ::g_popups.add(null, noRespText)
      return
    }

    reset_mp_autostart_countdown()
    if (readyForRespawn)
      setApplyPressed()
    else if (canChangeAircraft && !isApplyPressed && ::can_request_aircraft_now())
      doSelectAircraft()
  }

  function checkCurAirAmmo(applyFunc)
  {
    local bulletsManager = weaponsSelectorWeak?.bulletsManager
    if (!bulletsManager)
      return true

    if (bulletsManager.canChangeBulletsCount())
      return bulletsManager.checkChosenBulletsCount(true, ::Callback(@() applyFunc(), this))

    local air = getCurSlotUnit()
    if (!air)
      return true

    local text = "";
    local zero = false;

    local weapon = getSelWeapon()
    if (weapon)
    {
      local weaponText = getAmmoAmountData(air, weapon, AMMO.WEAPON)
      if (weaponText.warning)
      {
        text += getWeaponNameText(air.name, false, -1, ", ") + weaponText.text;
        if (!weaponText.amount)
          zero = true
      }
    }


    local bulletGroups = bulletsManager.getBulletsGroups()
    foreach(groupIndex, bulGroup in bulletGroups)
    {
      if (!bulGroup.active)
        continue
      local modifName = bulGroup.selectedName
      if (modifName == "")
        continue

      local modificationText = getAmmoAmountData(air, modifName, AMMO.MODIFICATION)
      if (!modificationText.warning)
        continue

      if (text != "")
        text += "\n"
      text += getModificationName(air, modifName)
        + modificationText.text
      if (!modificationText.amount)
        zero = true
    }

    if (!zero && !::is_game_mode_with_spendable_weapons())
      return true

    if (text != "" && (zero || !::get_gui_option(::USEROPT_SKIP_WEAPON_WARNING))) //skip warning only
    {
      ::gui_start_modal_wnd(::gui_handlers.WeaponWarningHandler,
        {
          parentHandler = this
          message = ::loc(zero ? "msgbox/zero_ammo_warning" : "controls/no_ammo_left_warning")
          list = text
          ableToStartAndSkip = !zero
          onStartPressed = applyFunc
        })
      return false
    }
    return true
  }

  function checkCurUnitSkin(applyFunc)
  {
    local unit = getCurSlotUnit()
    if (!unit)
      return true

    local skinId = getSelSkin()
    if (!skinId)
      return true

    local diffCode = ::get_mission_difficulty_int()

    local curPresetId = contentPreset.getCurPresetId(diffCode)
    local newPresetId = contentPreset.getPresetIdBySkin(diffCode, unit.name, skinId)
    if (newPresetId == curPresetId)
      return true

    if (contentPreset.isAgreed(diffCode, newPresetId))
      return true // User already agreed to set this or higher preset.

  ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox, {
      parentHandler = this
      onStartPressed = function() {
        contentPreset.setPreset(diffCode, newPresetId, true)
        applyFunc()
      }
      message = ::loc("msgbox/optionWillBeChanged/content_allowed_preset")
        + " " + ::loc("msgbox/optionWillBeChanged", {
          name     = ::colorize("userlogColoredText", ::loc("options/content_allowed_preset"))
          oldValue = ::colorize("userlogColoredText", ::loc("content/tag/" + curPresetId))
          newValue = ::colorize("userlogColoredText", ::loc("content/tag/" + newPresetId))
        }) + " " + ::loc("msgbox/optionWillBeChanged/comment")
    })
    return false
  }

  function use_autostart()
  {
    if (!(::get_game_type() & ::GT_AUTO_SPAWN))
      return false;
    local crew = getCurCrew()
    if (isSpectate || !crew || !::before_first_flight_in_session || missionRules.isWarpointsRespawnEnabled)
      return false;

    local air = getCurSlotUnit()
    if (!air)
      return false

    return !::is_spare_aircraft_in_slot(crew.idInCountry) &&
      ::is_crew_slot_was_ready_at_host(crew.idInCountry, air.name, false)
  }

  function onUpdate(obj, dt)
  {
    if (needCheckSlotReady)
      checkCrewAccessChange()

    updateSwitchSpectatorTarget(dt)
    if (missionRules.isSpawnDelayEnabled)
      updateSlotDelays()

    updateSpawnScore(false)

    autostartTimer += dt;

    local countdown = ::get_mp_respawn_countdown()
    updateCountdown(countdown)

    updateTimeToKick(dt)
    updateTables(dt)
    setInfo()

    updateTacticalMapHint()

    if (use_autostart() && get_mp_autostart_countdown() <= 0 && !isApplyPressed)
    {
      onApply()
      return
    }

    if (isApplyPressed)
    {
      if (checkSpawnInterrupt())
        return

      if (::can_respawn_ca_now() && countdown < -100)
      {
        ::disable_flight_menu(false)
        if (respawnRecallTimer < 0)
        {
          respawnRecallTimer = 3.0
          doRespawn()
        }
        else
          respawnRecallTimer -= dt
      }
    }

    if (isRespawn && isSpectate)
      updateSpectatorName()

    if (isRespawn && ::get_mission_status() > ::MISSION_STATUS_RUNNING)
      ::quit_to_debriefing()
  }

  function doRespawn()
  {
    dagor.debug("do_respawn_player called")
    ::before_first_flight_in_session = false
    doRespawnCalled = ::do_respawn_player()
    if (!doRespawnCalled)
    {
      onApply()
      ::showInfoMsgBox(::loc("msg/something_went_wrong"), "something_went_wrong", true)
      return
    }

    ::broadcastEvent("PlayerSpawn", lastRequestData)
    if (lastRequestData)
    {
      lastSpawnUnitName = lastRequestData.name
      local requestedWeapon = lastRequestData.weapon
      if (!(lastSpawnUnitName in ::used_planes))
        ::used_planes[lastSpawnUnitName] <- []
      if (!::isInArray(requestedWeapon, ::used_planes[lastSpawnUnitName]))
        ::used_planes[lastSpawnUnitName].append(requestedWeapon)
      lastRequestData = null
    }
    updateButtons()
    ::select_respawnbase(-1)
  }

  function checkSpawnInterrupt()
  {
    if (!doRespawnCalled || !isRespawn)
      return false

    local unit = ::getAircraftByName(lastRequestData?.name ?? lastSpawnUnitName)
    if (!unit || missionRules.getUnitLeftRespawns(unit) != 0)
      return false

    guiScene.performDelayed(this, function()
    {
      if (!doRespawnCalled)
        return

      local msg = ::loc("multiplayer/noTeamUnitLeft",
                        { unitName = lastSpawnUnitName.len() ? ::getUnitName(lastSpawnUnitName) : "" })
      reinitScreen()
      ::g_popups.add(null, msg)
    })
    return true
  }

  function updateSlotDelays()
  {
    if (!::checkObj(scene))
      return

    local crews = ::get_crews_list_by_country(::get_local_player_country())
    local currentIdInCountry = getCurCrew()?.idInCountry
    foreach(crew in crews)
    {
      local idInCountry = crew.idInCountry
      if (!(idInCountry in slotDelayDataByCrewIdx))
        slotDelayDataByCrewIdx[idInCountry] <- { slotDelay = -1, updateTime = 0 }
      local slotDelayData = slotDelayDataByCrewIdx[idInCountry]

      local prevSlotDelay = ::getTblValue("slotDelay", slotDelayData, -1)
      local curSlotDelay = ::get_slot_delay_by_slot(idInCountry)
      if (prevSlotDelay != curSlotDelay)
      {
        slotDelayData.slotDelay = curSlotDelay
        slotDelayData.updateTime = ::dagor.getCurTime()
      }
      else if (curSlotDelay < 0)
        continue

      if (currentIdInCountry == idInCountry)
        updateApplyText()
      updateCrewSlot(crew)
    }
  }

  //only for crews of current country
  function updateCrewSlot(crew)
  {
    local unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      return

    local idInCountry = crew.idInCountry
    local countryId = crew.idCountry
    local slotObj = ::get_slot_obj(scene, countryId, idInCountry)
    if (!slotObj)
      return

    local params = getSlotbarParams()
    params.curSlotIdInCountry <- idInCountry
    params.curSlotCountryId <- countryId
    params.unlocked <- ::isUnitUnlocked(unit, countryId, idInCountry, ::get_local_player_country(), missionRules)
    params.weaponPrice <- getWeaponPrice(unit.name, getLastWeapon(unit.name))
    if (idInCountry in slotDelayDataByCrewIdx)
      params.slotDelayData <- slotDelayDataByCrewIdx[idInCountry]

    local priceTextObj = slotObj.findObject("bottom_item_price_text")
    if (::checkObj(priceTextObj))
    {
      local bottomText = ::get_unit_item_price_text(unit, params)
      priceTextObj.tinyFont = ::is_unit_price_text_long(bottomText) ? "yes" : "no"
      priceTextObj.setValue(bottomText)
    }

    local nameObj = slotObj.findObject(::get_slot_obj_id(countryId, idInCountry) + "_txt")
    if (::checkObj(nameObj))
      nameObj.setValue(::get_slot_unit_name_text(unit, params))

    if (!missionRules.isRespawnAvailable(unit))
      slotObj.shopStat = "disabled"
  }

  function updateAllCrewSlots()
  {
    foreach(crew in ::get_crews_list_by_country(::get_local_player_country()))
      updateCrewSlot(crew)
  }

  function get_mp_autostart_countdown()
  {
    local countdown = autostartTime - autostartTimer;
    return ::ceil(countdown);
  }
  function reset_mp_autostart_countdown()
  {
    autostartTimer = 0;
  }

  function showLoadAnim(show)
  {
    if (::checkObj(scene))
      scene.findObject("loadanim").show(show)

    if (show)
      reset_mp_autostart_countdown();
  }

  function updateButtons(show = null, checkShowChange = false)
  {
    if ((checkShowChange && show == showButtons) || !::check_obj(scene))
      return

    if (show != null)
      showButtons = show

    local buttons = {
      btn_select =          showButtons && isRespawn && !isNoRespawns && !stayOnRespScreen && !doRespawnCalled && !isSpectate
      btn_select_no_enter = showButtons && isRespawn && !isNoRespawns && !stayOnRespScreen && !doRespawnCalled && isSpectate
      btn_spectator =       showButtons && isRespawn && isFriendlyUnitsExists && (!isSpectate || ::is_has_multiplayer())
      btn_mpStat =          showButtons && isRespawn && ::is_has_multiplayer()
      btn_QuitMission =     showButtons && isRespawn && isNoRespawns && ::g_mis_loading_state.isReadyToShowRespawn()
      btn_back =            showButtons && ::use_touchscreen && !isRespawn
      btn_activateorder =   showButtons && isRespawn && ::g_orders.showActivateOrderButton() && (!isSpectate || !::show_console_buttons)
    }
    foreach(id, value in buttons)
      showSceneBtn(id, value)

    local crew = getCurCrew()
    local slotObj = crew && ::get_slot_obj(scene, crew.idCountry, crew.idInCountry)
    showBtn("buttonsDiv", show && isRespawn, slotObj)
  }

  function updateCountdown(countdown)
  {
    local isLoadingUnitModel = !stayOnRespScreen && !::can_request_aircraft_now()
    showLoadAnim(!isGTCooperative
      && (isLoadingUnitModel || !::g_mis_loading_state.isReadyToShowRespawn()))
    updateButtons(!isLoadingUnitModel, true)

    if (isLoadingUnitModel || !use_autostart())
      reset_mp_autostart_countdown();

    if (stayOnRespScreen)
      return

    local btnText = applyText
    if (countdown > 0 && readyForRespawn && isApplyPressed)
      btnText += ::loc("ui/parentheses/space", { text = countdown  + ::loc("mainmenu/seconds") })

    foreach (btnId in mainButtonsId)
      setColoredDoubleTextToButton(scene, btnId, btnText)

    local textObj = scene.findObject("autostart_countdown_text")
    if (!::checkObj(textObj))
      return

    local autostartCountdown = get_mp_autostart_countdown()
    local text = ""
    if (use_autostart() && autostartCountdown > 0 && autostartCountdown <= autostartShowTime)
    {
      text = ::loc("mainmenu/autostartCountdown") + " " + autostartCountdown + ::loc("mainmenu/seconds")
      if (autostartCountdown <= autostartShowInColorTime)
        text = ::colorize("warningTextColor", text)
      else
        text = ::colorize("activeTextColor", text)
    }
    textObj.setValue(text)
  }

  curChatBlk = ""
  curChatData = null
  function loadChat()
  {
    local chatBlkName = isSpectate? "gui/chat/gameChat.blk" : "gui/chat/gameChatRespawn.blk"
    if (!curChatData || chatBlkName != curChatBlk)
      loadChatScene(chatBlkName)
    if (curChatData)
      ::hide_game_chat_scene_input(curChatData, !isRespawn && !isSpectate)
  }

  function loadChatScene(chatBlkName)
  {
    local chatObj = scene.findObject(isSpectate ? "mpChatInSpectator" : "mpChatInRespawn")
    if (!::checkObj(chatObj))
      return

    if (curChatData)
    {
      if (::checkObj(curChatData.scene))
        guiScene.replaceContentFromText(curChatData.scene, "", 0, null)
      ::detachGameChatSceneData(curChatData)
    }

    curChatData = ::loadGameChatToObj(chatObj, chatBlkName, this,
      { selfHideInput = isSpectate, isInSpectateMode = isSpectate, isInputSelected = isSpectate })
    curChatBlk = chatBlkName

    if (!isSpectate)
      return

    local voiceChatNestObj = chatObj.findObject("voice_chat_nest")
    if (::check_obj(voiceChatNestObj))
      guiScene.replaceContent(voiceChatNestObj, "gui/chat/voiceChatWidget.blk", this)
  }

  function updateSpectatorRotationForced(isRespawnSceneActive = null)
  {
    if (isRespawnSceneActive == null)
      isRespawnSceneActive = isSceneActive()
    ::force_spectator_camera_rotation(isRespawnSceneActive && isSpectate)
  }

  function setSpectatorMode(is_spectator, forceShowInfo = false)
  {
    if (isSpectate == is_spectator && !forceShowInfo)
      return

    isSpectate = is_spectator
    showSpectatorInfo(is_spectator)
    setOrdersEnabled(isSpectate)
    updateSpectatorRotationForced()

    shouldBlurSceneBg = !isSpectate ? needUseHangarDof() : false
    ::handlersManager.updateSceneBgBlur()

    updateTacticalMapUnitType()
    if ("set_tactical_map_type_without_unit" in ::getroottable()) //compatibility with wop_1_69_1_X
      if (isSpectate)
        ::switch_spectator_target(true) //at second openng local player is selected
      else
        ::switch_spectator_target_by_id(::getTblValue("id", ::get_local_mplayer(), 0))

    if (is_spectator)
    {
      scene.findObject("btn_spectator").setValue(canChangeAircraft? ::loc("multiplayer/changeAircraft") : ::loc("multiplayer/backToMap"))
      updateSpectatorName()
    }
    else
      scene.findObject("btn_spectator").setValue(::loc("multiplayer/spectator"))

    loadChat()

    updateListsButtons()

    ::on_spectator_mode(is_spectator)

    updateApplyText()
    updateControlsAllowMask()
  }

  function updateControlsAllowMask()
  {
    switchControlsAllowMask(
      !isRespawn ? (
        CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP |
        CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD |
        CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY)
      : isSpectate ? CtrlsInGui.CTRL_ALLOW_SPECTATOR
      : CtrlsInGui.CTRL_ALLOW_NONE)
  }

  function setOrdersEnabled(value)
  {
    local statusObj = getOrderStatusObj()
    if (statusObj == null)
      return
    statusObj.show(value)
    statusObj.enable(value)
    if (value)
      ::g_orders.enableOrders(statusObj)
  }

  function showSpectatorInfo(status)
  {
    if (!::checkObj(scene))
      return

    setSceneTitle(status ? "" : getCurMpTitle(), scene, "respawn_title")

    scene.findObject("spectator_mode_title").show(status)
    scene.findObject("flight_menu_bgd").show(!status)
    scene.findObject("spectator_controls").show(status)
    scene.findObject("btn_show_hud").enable(status)
    updateButtons()
  }

  function getEndTimeObj()
  {
    return scene.findObject("respawn_time_end")
  }

  function getScoreLimitObj()
  {
    return scene.findObject("respawn_score_limit")
  }

  function getTimeToKickObj()
  {
    return scene.findObject("respawn_time_to_kick")
  }

  function updateSpectatorName()
  {
    if (!::checkObj(scene))
      return

    local name = ::get_spectator_target_name()
    if (name == lastSpectatorTargetName)
      return
    lastSpectatorTargetName = name

    local title = ::get_spectator_target_title()
    local text = $"{name} {title}"

    local targetId = ::get_spectator_target_id()
    local player = ::get_mplayers_list(GET_MPLAYERS_LIST, true).findvalue(@(p) p.id == targetId)
    local color = player != null ? ::get_mplayer_color(player) : "teamBlueColor"

    scene.findObject("spectator_name").setValue(::colorize(color, text))
  }

  function onChatCancel()
  {
    if (curChatData?.selfHideInput ?? false)
      return
    onGamemenu(null)
  }

  function onEmptyChatEntered()
  {
    if (!isSpectate)
      onApply()
  }

  function onGamemenu(obj)
  {
    if (showHud())
      return; //was hidden, ignore menu opening

    if (!isRespawn || !::can_request_aircraft_now())
      return

    if (isSpectate && onSpectator() && ::has_available_slots())
      return

    guiScene.performDelayed(this, function() {
      ::disable_flight_menu(false)
      gui_start_flight_menu()
    })
  }

  function onSpectator(obj = null)
  {
    if (!::can_request_aircraft_now() || !isRespawn)
      return false
    setSpectatorMode(!isSpectate)
    return true
  }

  function setHudVisibility(obj)
  {
    if(!isSpectate)
      return

    ::show_hud(!scene.findObject("respawn_screen").isVisible())
  }

  function showHud()
  {
    if (!::checkObj(scene) || scene.findObject("respawn_screen").isVisible())
      return false
    ::show_hud(true)
    return true
  }

  function updateSwitchSpectatorTarget(dt)
  {
    spectator_switch_timer -= dt;

    if (spectator_switch_direction == ESwitchSpectatorTarget.E_DO_NOTHING)
      return; //do nothing
    if (spectator_switch_timer <= 0)
    {
      ::switch_spectator_target(spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT);
      updateSpectatorName();

      spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING;
      spectator_switch_timer = spectator_switch_timer_max;
    }
  }
  function switchSpectatorTargetToNext()
  {
    if (spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT)
      return; //already switching
    if (spectator_switch_direction == ESwitchSpectatorTarget.E_PREV)
    {
      spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING; //switch back
      return;
    }
    spectator_switch_direction = ESwitchSpectatorTarget.E_NEXT;
  }
  function switchSpectatorTargetToPrev()
  {
    if (spectator_switch_direction == ESwitchSpectatorTarget.E_PREV)
      return; //already switching
    if (spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT)
    {
      spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING; //switch back
      return;
    }
    spectator_switch_direction = ESwitchSpectatorTarget.E_PREV;
  }

  function onHideHUD(obj)
  {
    ::show_hud(false)
  }

  function onShowHud(show = true, needApplyPending = false) //return - was changed
  {
    if (!isSceneActive())
      return

    if (!::checkObj(scene))
      return

    local obj = scene.findObject("respawn_screen")
    local isHidden = obj?.display == "hide" //until scene recount obj.isVisible will return false, because it was full hidden
    if (isHidden != show)
      return

    obj.show(show)
  }

  function onSpectatorNext(obj)
  {
    if (!::can_request_aircraft_now())
      return
    if (isRespawn && isSpectate)
      switchSpectatorTargetToNext();
  }

  function onSpectatorPrev(obj)
  {
    if (!::can_request_aircraft_now())
      return
    if (isRespawn && isSpectate)
      switchSpectatorTargetToPrev();
  }

  function onMpStatScreen(obj)
  {
    if (!::can_request_aircraft_now())
      return

    guiScene.performDelayed(this, function() {
      ::disable_flight_menu(false)
      ::gui_start_mpstatscreen()
    })
  }

  function getCurrentEdiff()
  {
    return ::get_mission_mode()
  }

  function onQuitMission(obj)
  {
    ::quit_mission()
  }

  function goBack()
  {
    if (!isRespawn)
      ::close_ingame_gui()
  }

  function onEventUpdateEsFromHost(p)
  {
    if (isSceneActive())
      reinitScreen({})
  }

  function onEventUnitWeaponChanged(p)
  {
    local crew = getCurCrew()
    local unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      return

    if (missionRules.hasRespawnCost)
      updateCrewSlot(crew)

    updateShipOptions(unit, false)
    updateAircraftWeaponsOptions(unit, false)
    checkReady()
  }

  function onEventBulletsGroupsChanged(p)
  {
    local crew = getCurCrew()
    if (missionRules.hasRespawnCost)
      updateCrewSlot(crew)

    checkReady()
  }

  function onEventBulletsCountChanged(p)
  {
    checkReady()
  }

  function updateLeftPanelBlock()
  {
    local objectivesObj = scene.findObject("objectives")
    local separateObj = scene.findObject("separate_block")
    local chatObj = scene.findObject("mpChatInRespawn")
    local unitOptionsObj = scene.findObject("unit_options")
    objectivesObj.height = ""
    separateObj.height = ""
    unitOptionsObj.height = ""
    chatObj.height = "fh"

    // scene update needed to all objects has right size values
    guiScene.applyPendingChanges(false)

    local leftPanelObj = scene.findObject("panel-left")
    local minChatHeight = ::g_dagui_utils.toPixels(guiScene, "1@minChatHeight")
    local hOversize = unitOptionsObj.getSize()[1] + objectivesObj.getSize()[1] +
      minChatHeight - leftPanelObj.getSize()[1]

    local unitOptionsHeight = unitOptionsObj.getSize()[1]
    if (hOversize > 0)
    {
      unitOptionsHeight = ::max(unitOptionsObj.getSize()[1] - hOversize,
        unitOptionsObj.getSize()[1] / 2)
      unitOptionsObj.height = unitOptionsHeight
    }

    local maxChatHeight = ::g_dagui_utils.toPixels(guiScene, "1@maxChatHeight")
    canSwitchChatSize = chatObj.getSize()[1] < maxChatHeight
      && objectivesObj.getSize()[1] > ::g_dagui_utils.toPixels(guiScene, "1@minMisObjHeight")

    showSceneBtn("mis_obj_text_header", !canSwitchChatSize)
    showSceneBtn("mis_obj_button_header", canSwitchChatSize)

    isChatFullSize = !canSwitchChatSize ? true : ::loadLocalByScreenSize("isRespawnChatFullSize", null)
    updateChatSize(isChatFullSize)

    local separatorHeight = leftPanelObj.getSize()[1] - unitOptionsObj.getSize()[1] -
                           objectivesObj.getSize()[1] - maxChatHeight

    chatObj.height = separatorHeight > 0 ? "1@maxChatHeight" : "fh"
    separateObj.height = separatorHeight > 0 ? "fh" : ""

    objectivesObj["max-height"] = leftPanelObj.getSize()[1] - unitOptionsHeight - minChatHeight
  }

  function onSwitchChatSize()
  {
    if (!canSwitchChatSize)
      return

    updateChatSize(!isChatFullSize)
    ::saveLocalByScreenSize("isRespawnChatFullSize", isChatFullSize)
  }

  function updateChatSize(newIsChatFullSize)
  {
    isChatFullSize = newIsChatFullSize

    scene.findObject("mis_obj_button_header").direction = isChatFullSize ? "down" : "up"
    scene.findObject("objectives").height = canSwitchChatSize && isChatFullSize ? "1@minMisObjHeight" : ""
  }

  function checkUpdateCustomStateRespawns()
  {
    if (!isSceneActive())
      return //when scene become active again there will be full update on reinitScreen

    local newRespawnMask = missionRules.getCurCrewsRespawnMask()
    if (!customStateCrewAvailableMask && newRespawnMask)
    {
      reinitScreen({})
      return
    }

    if (customStateCrewAvailableMask == newRespawnMask)
      return updateApplyText() //unit left respawn text

    updateLeftRespawns()
    reinitSlotbar()
  }

  function onEventMissionCustomStateChanged(p)
  {
    doWhenActiveOnce("checkUpdateCustomStateRespawns")
    doWhenActiveOnce("updateAllCrewSlots")
  }

  function onEventMyCustomStateChanged(p)
  {
    doWhenActiveOnce("checkUpdateCustomStateRespawns")
    doWhenActiveOnce("updateAllCrewSlots")
  }

  function onEventMissionObjectiveUpdated(p)
  {
    updateLeftPanelBlock()
  }
}

::cant_respawn_anymore <- function cant_respawn_anymore() // called when no more respawn bases left
{
  if (::current_base_gui_handler && ("stayOnRespScreen" in ::current_base_gui_handler))
    ::current_base_gui_handler.stayOnRespScreen = true
}

::get_mouse_relative_coords_on_obj <- function get_mouse_relative_coords_on_obj(obj)
{
  if (!::checkObj(obj))
    return null

  local objPos  = obj.getPosRC()
  local objSize = obj.getSize()
  local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
  if (cursorPos[0] >= objPos[0] && cursorPos[0] <= objPos[0] + objSize[0] && cursorPos[1] >= objPos[1] && cursorPos[1] <= objPos[1] + objSize[1])
    return [
      1.0 * (cursorPos[0] - objPos[0]) / objSize[0],
      1.0 * (cursorPos[1] - objPos[1]) / objSize[1],
    ]

  return null
}

::has_available_slots <- function has_available_slots()
{
  if (!(::get_game_type() & (::GT_VERSUS | ::GT_COOPERATIVE)))
    return true

  if (::get_game_mode() == ::GM_SINGLE_MISSION || ::get_game_mode() == ::GM_DYNAMIC)
    return true

  if (!::g_mis_loading_state.isCrewsListReceived())
    return false

  local team = ::get_mp_local_team()
  local country = ::get_local_player_country()
  local crews = ::get_crews_list_by_country(country)
  if (!crews)
    return false

  dagor.debug("looking for country "+country+" in team "+team)

  local missionRules = ::g_mis_custom_state.getCurMissionRules()
  local leftRespawns = missionRules.getLeftRespawns()
  if (leftRespawns == 0)
    return false

  local curSpawnScore = missionRules.getCurSpawnScore()
  foreach (c in crews)
  {
    local air = ::g_crew.getCrewUnit(c)
    if (!air)
      continue

    if (!::is_crew_available_in_session(c.idInCountry, false)
        || !::is_crew_slot_was_ready_at_host(c.idInCountry, air.name, false)
        || !::get_available_respawn_bases(air.tags).len()
        || !missionRules.getUnitLeftRespawns(air)
        || !missionRules.isUnitEnabledBySessionRank(air)
        || air.disableFlyout)
      continue

    if (missionRules.isScoreRespawnEnabled
      && curSpawnScore >= 0
      && curSpawnScore < air.getMinimumSpawnScore())
      continue

    dagor.debug("has_available_slots true: unit "+air.name+" in slot "+c.idInCountry)
    return true
  }
  dagor.debug("has_available_slots false")
  return false
}
