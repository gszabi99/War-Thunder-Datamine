from "%scripts/dagui_natives.nut" import add_last_played, show_gui, string_to_restore_type, map_to_location
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import *
from "%scripts/gameModes/gameModeConsts.nut" import BATTLE_TYPES
from "%scripts/mainConsts.nut" import global_max_players_versus

let { fillBlock } = require("%sqstd/datablock.nut")
let { is_user_mission } = require("%scripts/missions/missionsUtilsModule.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let DataBlock = require("DataBlock")
let { format } = require("string")
let contentPreset = require("%scripts/customization/contentPreset.nut")
let { getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let { isGameModeCoop } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { getMaxEconomicRank } = require("%appGlobals/ranks_common_shared.nut")
let { setGuiOptionsMode, set_gui_option } = require("guiOptions")
let { is_benchmark_game_mode, get_game_mode, get_game_type } = require("mission")
let { get_meta_mission_info_by_gm_and_name,
  select_mission, select_mission_full, quit_to_debriefing
} = require("guiMission")
let { dynamicSetTakeoffMode } = require("dynamicMission")
let { locCurrentMissionName, getMissionTimeText, getWeatherLocName
} = require("%scripts/missions/missionsUtils.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_current_mission_info } = require("blkGetters")
let { getClustersList } = require("%scripts/onlineInfo/clustersManagement.nut")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { create_options_container } = require("%scripts/options/optionsExt.nut")
let { currentCampaignId, currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")

::mission_settings <- {
  name = null
  postfix = null
  missionURL = null
  aircraft = null
  weapon = null
  diff = 1
  players = null
  time = null
  weather = null
  isLimitedFuel = false
  isLimitedAmmo = false
  takeoffMode = 0
  currentMissionIdx = -1

  mission = null
  missionFull = null
  friendOnly = false
  allowJIP = true
  dedicatedReplay = false
  coop = false
  layout = null
  sessionPassword = ""
  layoutName = ""
  isBotsAllowed = true
  rounds = 0
  arcadeCountry = false
  maxRespawns = -1
  autoBalance = true
  battleMode = BATTLE_TYPES.AIR // only for random battles, must be removed when new modes will be added
}

registerPersistentData("mission_settings", getroottable(), ["mission_settings"])

::get_briefing_options <- function get_briefing_options(gm, gt, missionBlk) {
  let optionItems = []
  if (is_benchmark_game_mode() || ::custom_miss_flight)
    return optionItems

  if (::get_mission_types_from_meta_mission_info(missionBlk).len())
    optionItems.append([USEROPT_MISSION_NAME_POSTFIX, "spinner"])

  if (gm != GM_DYNAMIC && missionBlk.getBool("openDiffLevels", true))
    optionItems.append([USEROPT_DIFFICULTY, "spinner"])

  if (gm == GM_TRAINING)
    return optionItems;

  if (!missionBlk.paramExists("environment") || (gm == GM_TEAMBATTLE) || (gm == GM_DOMINATION) || (gm == GM_SKIRMISH))
    optionItems.append([USEROPT_TIME, "spinner"])
  if (!missionBlk.paramExists("weather") || (gm == GM_TEAMBATTLE) || (gm == GM_DOMINATION) || (gm == GM_SKIRMISH))
    optionItems.append([USEROPT_CLIME, "spinner"])

  if (!missionBlk.paramExists("isLimitedFuel"))
    optionItems.append([USEROPT_LIMITED_FUEL, "spinner"])

  if (!missionBlk.paramExists("isLimitedAmmo"))
    optionItems.append([USEROPT_LIMITED_AMMO, "spinner"])

  if (missionBlk.getBool("optionalTakeOff", false))
    optionItems.append([USEROPT_OPTIONAL_TAKEOFF, "spinner"])

  if (missionBlk.paramExists("disableAirfields"))
    optionItems.append([USEROPT_DISABLE_AIRFIELDS, "spinner"])

  if (missionBlk?.isCustomVisualFilterAllowed != false && gm == GM_SKIRMISH
      && (hasFeature("EnableLiveSkins") || hasFeature("EnableLiveDecals"))
      && contentPreset.getContentPresets().len() > 0)
    optionItems.append([USEROPT_CONTENT_ALLOWED_PRESET, "combobox"])

  if (gm == GM_DYNAMIC) {
    if (missionBlk.paramExists("takeoff_mode")) {
        ::mission_name_for_takeoff = missionBlk?.name
        optionItems.append([USEROPT_TAKEOFF_MODE, "spinner"])
    }
//    if (missionBlk.paramExists("landing_mode"))
//        optionItems.append([USEROPT_LANDING_MODE, "spinner"])
  }

  if (gt & GT_RACE) {
    optionItems.append([USEROPT_RACE_LAPS, "spinner"])
    optionItems.append([USEROPT_RACE_WINNERS, "spinner"])
    optionItems.append([USEROPT_RACE_CAN_SHOOT, "spinner"])
  }

  if (gt & GT_VERSUS) {
    if (!missionBlk.paramExists("timeLimit") || gm == GM_SKIRMISH)
      optionItems.append([USEROPT_TIME_LIMIT, "spinner"])
//    if (!missionBlk.paramExists("rounds"))
//      optionItems.append([USEROPT_ROUNDS, "spinner"])
    if (missionBlk?.forceNoRespawnsByMission != true) //false or null
      optionItems.append([USEROPT_VERSUS_RESPAWN, "spinner"])

    if (missionBlk.paramExists("killLimit") && !(gt & GT_RACE))
      optionItems.append([USEROPT_KILL_LIMIT, "spinner"])
  }

  if (gm == GM_TOURNAMENT) {
    missionBlk.setBool("gt_mp_solo", false)
    missionBlk.setBool("allowJIP", false)
    missionBlk.setBool("isPrivate", false)
    missionBlk.setBool("isBotsAllowed", false)
    missionBlk.setInt("minPlayers", 0)
    missionBlk.setInt("maxPlayers", 0)
  }
  else if (gm == GM_DOMINATION || gm == GM_SKIRMISH) {
    if (gm == GM_SKIRMISH) {
      optionItems.append([USEROPT_MISSION_COUNTRIES_TYPE, "spinner"])
      optionItems.append([USEROPT_BIT_COUNTRIES_TEAM_A, "multiselect"])
      optionItems.append([USEROPT_BIT_COUNTRIES_TEAM_B, "multiselect"])

      if (::is_skirmish_with_killstreaks(missionBlk))
        optionItems.append([USEROPT_USE_KILLSTREAKS, "spinner"])

      optionItems.append([USEROPT_BIT_UNIT_TYPES, "multiselect"])
      optionItems.append([USEROPT_BR_MIN, "spinner"])
      optionItems.append([USEROPT_BR_MAX, "spinner"])
    }

    let canUseBots = !(gt & GT_RACE)
    let isBotsAllowed = missionBlk?.isBotsAllowed
    if (canUseBots && isBotsAllowed == null) {
      optionItems.append([USEROPT_IS_BOTS_ALLOWED, "spinner"])
    }
    if (canUseBots && isBotsAllowed != false
        && ::is_mission_for_unittype(missionBlk, ES_UNIT_TYPE_TANK)) {
      optionItems.append([USEROPT_USE_TANK_BOTS, "spinner"])
      optionItems.append([USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, "spinner"])
    }
    if (canUseBots && isBotsAllowed != false && hasFeature("ShipBotsOption") &&
      ::is_mission_for_unittype(missionBlk, ES_UNIT_TYPE_SHIP))
      optionItems.append([USEROPT_USE_SHIP_BOTS, "spinner"])

    optionItems.append([USEROPT_KEEP_DEAD, "spinner"])

    if (!isInSessionRoom.get())
      optionItems.append([USEROPT_MAX_PLAYERS, "spinner"])

    if (gm == GM_SKIRMISH) {
      if (gt & GT_RACE)
        missionBlk.setBool("allowJIP", false)
      else
        optionItems.append([USEROPT_ALLOW_JIP, "spinner"])
    }

    optionItems.append([USEROPT_ALLOW_EMPTY_TEAMS, "spinner"])
  }

  if (gm == GM_SKIRMISH || (g_squad_manager.isInSquad() && isGameModeCoop(gm)))
    optionItems.append([USEROPT_CLUSTERS, "spinner"])

  if ((gt & GT_SP_USE_SKIN) && !(gt & GT_VERSUS)) {
    let aircraft = missionBlk.getStr("player_class", "")
    unitNameForWeapons.set(aircraft)
    optionItems.append([USEROPT_SKIN, "spinner"])
  }

  if (gm == GM_SKIRMISH && hasFeature("LiveBroadcast"))
    optionItems.append([USEROPT_DEDICATED_REPLAY, "spinner"])

  if (gm == GM_SKIRMISH)
    optionItems.append([USEROPT_SESSION_PASSWORD, "editbox"])

  return optionItems
}

::get_mission_types_from_meta_mission_info <- function get_mission_types_from_meta_mission_info(metaInfo) {
  let types = [];
  let missionTypes = metaInfo.getBlockByName("missionType")
  if (missionTypes) {
    foreach (key, val in missionTypes)
      if (val)
        types.append(key)
  }
  return types
}

function get_mission_desc_text(missionBlk) {
  local descrAdd = ""

  let sm_location = missionBlk.getStr("locationName",
                            map_to_location(missionBlk.getStr("level", "")))
  if (sm_location != "")
    descrAdd = "".concat(descrAdd, loc("options/location"), loc("ui/colon"), loc($"location/{sm_location}"))

  let sm_time = missionBlk.getStr("time", missionBlk.getStr("environment", ""))
  if (sm_time != "")
    descrAdd = "".concat(descrAdd, (descrAdd != "" ? "; " : ""), getMissionTimeText(sm_time))

  let sm_weather = missionBlk.getStr("weather", "")
  if (sm_weather != "")
    descrAdd = "".concat(descrAdd, (descrAdd != "" ? "; " : ""), getWeatherLocName(sm_weather))

  let aircraft = missionBlk.getStr("player_class", "")
  if (aircraft != "") {
    let sm_aircraft = "".concat(loc("options/aircraft"), loc("ui/colon"), getUnitName(aircraft), "; ",
      getWeaponNameText(aircraft, null, missionBlk.getStr("player_weapons", ""), ", "))

    descrAdd = $"{descrAdd}\n{sm_aircraft}"
  }

  if (missionBlk.getStr("recommendedPlayers", "") != "")
    descrAdd = "".concat(
      descrAdd,
      "\n",
      format(loc("players_recommended"), missionBlk.getStr("recommendedPlayers", "1-4")),
      "\n"
    )

  return descrAdd
}

gui_handlers.Briefing <- class (gui_handlers.GenericOptions) {
  sceneBlkName = "%gui/briefing.blk"
  sceneNavBlkName = "%gui/navBriefing.blk"

  function initScreen() {
    base.initScreen()
    let gm = get_game_mode()
    setGuiOptionsMode(::get_options_mode(gm))

    let campaignName = currentCampaignId.get()
    this.missionName = currentCampaignMission.get()

    if (campaignName == null || this.missionName == null)
      return

    this.missionBlk = DataBlock()
    this.missionBlk.setFrom(get_meta_mission_info_by_gm_and_name(gm, this.missionName))

    if (gm == GM_EVENT)
      ::mission_settings.coop = true;
    else if ((gm != GM_SINGLE_MISSION) && (gm != GM_USER_MISSION) && (gm != GM_BUILDER))
      ::mission_settings.coop = false;
    else if (gm == GM_SINGLE_MISSION) {
      if (!this.missionBlk.getBool("gt_cooperative", false) || is_user_mission(this.missionBlk))
        ::mission_settings.coop = false;
    }
    //otherwise it's set from menu

    this.missionBlk.setBool("gt_cooperative", ::mission_settings.coop)
    this.missionBlk.setInt("_gameMode", gm)
    if (gm == GM_DYNAMIC || gm == GM_BUILDER)
      if (this.missionBlk.getStr("restoreType", "attempts") == "tactical control")
        this.missionBlk.setStr("restoreType", "attempts");

    if (this.isRestart) { //temp hack because it doesn't work for some weird reason
      this.missionBlk.setBool("isLimitedFuel", ::mission_settings.isLimitedFuel)
      this.missionBlk.setBool("isLimitedAmmo", ::mission_settings.isLimitedAmmo)
    }

    select_mission(this.missionBlk, false);

    let gt = get_game_type(); //we know it after select_mission()

    log(format("[BRIEFING] mode %d, type %d, mission %s", gm, gt, this.missionName))

    let title = locCurrentMissionName()
    local desc = ::loc_current_mission_desc()
    this.picture = this.missionBlk.getStr("backgroundImage", "")
    this.restoreType = string_to_restore_type(this.missionBlk.getStr("restoreType", "attempts"))
    this.isTakeOff = this.missionBlk.getBool("optionalTakeOff", false)
    this.isOnline = this.missionBlk.getBool("isOnline", false)

    let aircraft = this.missionBlk.getStr("player_class", "")
    unitNameForWeapons.set(aircraft)

    ::mission_settings.name = this.missionName
    ::mission_settings.postfix = null
    ::mission_settings.aircraft  = aircraft
    ::mission_settings.weapon = this.missionBlk.getStr("player_weapons", "")
    ::mission_settings.players = 4;

    let descrAdd = get_mission_desc_text(this.missionBlk)
    if (descrAdd != "")
      desc = "".concat(desc, (desc.len() ? "\n\n" : ""), descrAdd)

    this.scene.findObject("mission_title").setValue(title)
    this.scene.findObject("mission_desc").setValue(desc)

    this.optionsContainers = []

    let optionItems = ::get_briefing_options(gm, gt, this.missionBlk)
    let container = create_options_container("briefing_options", optionItems, true)
    this.guiScene.replaceContentFromText(this.scene.findObject("optionslist"), container.tbl, container.tbl.len(), this)
    if (optionItems.len() > 0) {
      let listObj = showObjById("optionslist", true, this.scene)
      listObj.height = $"{optionItems.len()}*@baseTrHeight" //bad solution, but freeheight doesn't work correct
    }
    this.optionsContainers.append(container.descr)

    if (this.restoreType == ERT_TACTICAL_CONTROL) {
      showObjById("attempts", false, this.scene)
      showObjById("lbl_attempts", false, this.scene)
    }

    if (this.isRestart)
      showObjById("btn_back", false, this.scene)
  }

  function onApply(_obj) {
    this.finalApply(this.missionBlk)
    this.onFinalApply2()
  }

  function finalApply(misBlk) {
    if (!this.isValid())
      return

    let gm = get_game_mode()
    let gt = get_game_type()
    local value = ""

    if (!misBlk) {
      misBlk = DataBlock()
      get_current_mission_info(misBlk)
    }

    if (gm == GM_DYNAMIC) {
      ::mission_settings.missionFull = ::mission_settings.dynlist[::mission_settings.currentMissionIdx]
      misBlk.setFrom(::mission_settings.missionFull.mission_settings.mission);
      misBlk.setInt("currentMissionIdx", ::mission_settings.currentMissionIdx);
      misBlk.setInt("takeoffMode", ::mission_settings.takeoffMode);
    }

    misBlk.setInt("_gameMode", gm)

    if (!("loc_name" in misBlk))
      misBlk.setStr("loc_name", "")

    set_gui_option(USEROPT_NUM_ATTEMPTS, -1)

    if (gm == GM_DYNAMIC) {
      misBlk.setStr("difficulty", ::get_option(USEROPT_DIFFICULTY).values[::mission_settings.diff])
    }
    else if (this.getObj("difficulty") != null) {
      ::mission_settings.diff = this.getObj("difficulty").getValue();
      misBlk.setStr("difficulty", ::get_option(USEROPT_DIFFICULTY).values[::mission_settings.diff])
    }
    else
      ::mission_settings.diff = 0;

    value = this.getOptValue(USEROPT_LIMITED_FUEL, false)
    if (value != null) {
      ::mission_settings.isLimitedFuel = value
      misBlk.setBool("isLimitedFuel", ::mission_settings.isLimitedFuel)
    }

    value = this.getOptValue(USEROPT_LIMITED_AMMO, false)
    if (value != null) {
      ::mission_settings.isLimitedAmmo = value
      misBlk.setBool("isLimitedAmmo", ::mission_settings.isLimitedAmmo)
    }

    value = this.getOptValue(USEROPT_OPTIONAL_TAKEOFF, false)
    if (value != null)
      misBlk.setBool("takeOffOnStart", value && misBlk.getBool("isOptionalTakeOff", false))

    value = this.getOptValue(USEROPT_DISABLE_AIRFIELDS, false)
    if (value != null)
      misBlk.setBool("disableAirfields", value)

    value = this.getOptValue(USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, false)
    if (value != null)
      misBlk.setBool("spawnAiTankOnTankMaps", value)

    value = this.getOptValue(USEROPT_SKIN, false)
    if (value != null && (gt & GT_DYNAMIC)) {
      let ar = ::mission_settings.missionFull.units % "armada";
      for (local i = 0; i < ar.len(); i++) {
        if (ar[i].name.indexof("#player.") != null)
          ar[i].props.skin = value;
      }
    }

    ::mission_settings.coop = ::mission_settings.coop && g_squad_manager.isNotAloneOnline()
    misBlk.setBool("gt_cooperative", ::mission_settings.coop)
    misBlk.setBool("gt_versus", (gt & GT_VERSUS))

    if (::mission_settings.coop) {
      ::mission_settings.players = 4;
      misBlk.setInt("_players", 4)
      misBlk.setInt("maxPlayers", 4)
      misBlk.setBool("gt_use_lb", gm == GM_EVENT)
      misBlk.setBool("gt_use_replay", true)
      misBlk.setBool("gt_use_stats", true)
      misBlk.setBool("gt_sp_restart", false)
      misBlk.setBool("isBotsAllowed", true)
      misBlk.setBool("autoBalance", false)
    }
    if (gt & GT_VERSUS) {
      misBlk.setBool("gt_use_lb", true)
      misBlk.setBool("gt_use_replay", true)
      misBlk.setBool("gt_use_stats", true)
      misBlk.setBool("gt_sp_restart", false)
    }

    value = this.getOptValue(USEROPT_TIME_LIMIT, false)
    if (value != null)
      misBlk.setInt("timeLimit", value)

    value = this.getOptValue(USEROPT_KILL_LIMIT, false)
    if (value != null)
      misBlk.setInt("killLimit", value)

    value = this.getOptValue(USEROPT_ROUNDS, false)
    if (value != null) {
      misBlk.setInt("rounds", value)
      ::mission_settings.rounds = value
    }

    value = this.getOptValue(USEROPT_VERSUS_RESPAWN, false)
    if (value != null) {
      misBlk.setInt("maxRespawns", value)
      ::mission_settings.maxRespawns = value
    }

    if (gm == GM_SKIRMISH) {
      value = this.getOptValue(USEROPT_ALLOW_JIP, false)
      if (value != null) {
        misBlk.setBool("allowJIP", value)
        ::mission_settings.allowJIP = value
      }

      if (::is_skirmish_with_killstreaks(misBlk)) {
        value = this.getOptValue(USEROPT_USE_KILLSTREAKS, false)
        misBlk.setBool("useKillStreaks", value)
      }
    }
    misBlk.allowEmptyTeams = this.getOptValue(USEROPT_ALLOW_EMPTY_TEAMS, false)

    local isBotsAllowed = this.getOptValue(USEROPT_IS_BOTS_ALLOWED, false)
    if (value == null)
      if (misBlk.paramExists("isBotsAllowed"))
        isBotsAllowed = misBlk.isBotsAllowed
      else
        isBotsAllowed = (gm == GM_DOMINATION || gm == GM_SKIRMISH)
                        && !(gt & GT_RACE)
                        && this.getOptValue(USEROPT_IS_BOTS_ALLOWED)

    misBlk.setBool("isBotsAllowed", isBotsAllowed)
    ::mission_settings.isBotsAllowed = isBotsAllowed

    if (isBotsAllowed)
      misBlk.useTankBots = this.getOptValue(USEROPT_USE_TANK_BOTS, false)

    if (isBotsAllowed)
      misBlk.useShipBots = this.getOptValue(USEROPT_USE_SHIP_BOTS, false)

    misBlk.keepDead = this.getOptValue(USEROPT_KEEP_DEAD, true)

    if (gm == GM_SKIRMISH) {
      value = hasFeature("LiveBroadcast") ? this.getOptValue(USEROPT_DEDICATED_REPLAY) : false
      misBlk.setBool("dedicatedReplay", value)
      ::mission_settings.dedicatedReplay = value
    }

    if (!("url" in misBlk))
      misBlk.setStr("url", "") //Must-be param, to override on matching if used before

    ::mission_settings.missionURL = misBlk.url
    ::mission_settings.sessionPassword =  ::get_option(USEROPT_SESSION_PASSWORD).value

    if (misBlk.paramExists("autoBalance")) {
      ::mission_settings.autoBalance = misBlk.getBool("autoBalance", true)
    }

    value = this.getOptValue(USEROPT_MIN_PLAYERS, false)
    if (value != null)
      misBlk.setInt("minPlayers", value)

    value = this.getOptValue(USEROPT_MAX_PLAYERS, false)
    if (value != null) {
      misBlk.setInt("maxPlayers", value)
      ::mission_settings.players = value;
      misBlk.setInt("_players", value)
    }
    else if (gt & GT_VERSUS) {
      if (isInSessionRoom.get()) {
        misBlk.setInt("maxPlayers", ::SessionLobby.getMaxMembersCount())
        ::mission_settings.players = ::SessionLobby.getMaxMembersCount()
      }
      else {
        ::mission_settings.players = global_max_players_versus;
        misBlk.setInt("_players", global_max_players_versus)
      }
    }

    value = this.getOptValue(USEROPT_CLUSTERS, false)
    if (value != null)
      ::mission_settings.cluster <- value == "auto"
        ? getClustersList().filter(@(info) info.isDefault)[0].name
        : value
    value = this.getOptValue(USEROPT_FRIENDS_ONLY, false)
    if (value != null) {
      misBlk.setBool("isPrivate", value)
      ::mission_settings.friendOnly = value
      misBlk.setBool("allowJIP", !value)
      ::mission_settings.allowJIP = !value
    }
    else if (gm == GM_DYNAMIC) {
      misBlk.setBool("isPrivate", ::mission_settings.friendOnly)
      misBlk.setBool("allowJIP", ! ::mission_settings.friendOnly)
      misBlk.setBool("isBotsAllowed", true)
      misBlk.setBool("autoBalance", false)
    }
    else if ((gm == GM_SINGLE_MISSION) && (this.guiScene["coop_mode"] != null)) {
      misBlk.setBool("isPrivate", ::mission_settings.friendOnly)
      misBlk.setBool("allowJIP", ! ::mission_settings.friendOnly)
    }
    else if ((gm != GM_DYNAMIC) && !isInSessionRoom.get())
      ::mission_settings.friendOnly = false

    value = this.getOptValue(USEROPT_TIME, false)
    if (value != null)
      misBlk.setStr("environment", value)

    value = this.getOptValue(USEROPT_CLIME, false)
    if (value != null)
      misBlk.setStr("weather", value)

    value = this.getOptValue(USEROPT_MISSION_COUNTRIES_TYPE, false)
    if (value != null)
      ::mission_settings.countriesType <- value

    foreach (opt in [USEROPT_BIT_COUNTRIES_TEAM_A, USEROPT_BIT_COUNTRIES_TEAM_B]) {
      let option = ::get_option(opt)
      let obj = this.scene.findObject(option.id)
      if (obj)
        ::mission_settings[$"{option.sideTag}_bitmask"] <- obj.getValue()
    }

    value = this.getOptValue(USEROPT_BIT_UNIT_TYPES, false)
    let option = ::get_option(USEROPT_BIT_UNIT_TYPES)
    if (value != null && value != option.availableUnitTypesMask)
      ::mission_settings.userAllowedUnitTypesMask <- value

    let mrankMin = this.getOptValue(USEROPT_BR_MIN, 0)
    let mrankMax = this.getOptValue(USEROPT_BR_MAX, 0)
    fillBlock("ranks", misBlk, { min = mrankMin, max = mrankMax })
    if (mrankMin > 0 || mrankMax < getMaxEconomicRank()) {
      ::mission_settings.mrankMin <- mrankMin
      ::mission_settings.mrankMax <- mrankMax
    }

    value = this.getOptValue(USEROPT_CONTENT_ALLOWED_PRESET, false)
    if (value != null)
      misBlk.setStr("allowedTagsPreset", value)

    if (gt & GT_RACE) {
      misBlk.raceLaps = this.getOptValue(USEROPT_RACE_LAPS)
      misBlk.raceWinners = this.getOptValue(USEROPT_RACE_WINNERS)
      misBlk.raceForceCannotShoot = !this.getOptValue(USEROPT_RACE_CAN_SHOOT)
    }

    misBlk.setInt("_gameMode", gm)
    if (isInSessionRoom.get()) {
      misBlk.setBool("isPrivate", ::mission_settings.friendOnly)
      misBlk.setBool("allowJIP", ::mission_settings.allowJIP)
    }

    if (gm == GM_DYNAMIC || gm == GM_BUILDER)
      if (misBlk.getStr("restoreType", "attempts") == "tactical control")
        misBlk.setStr("restoreType", "attempts");

    ::mission_settings.time = misBlk.getStr("environment", "")
    ::mission_settings.weather = misBlk.getStr("weather", "")
    ::mission_settings.isLimitedFuel = misBlk.getBool("isLimitedFuel", false)
    ::mission_settings.isLimitedAmmo = misBlk.getBool("isLimitedAmmo", false)
    ::mission_settings.takeoffMode = this.getOptValue(USEROPT_TAKEOFF_MODE, true)

    ::mission_settings.mission = misBlk

    if (gm == GM_DYNAMIC) {
      ::mission_settings.missionFull = ::mission_settings.dynlist[::mission_settings.currentMissionIdx]

      let mode = ::mission_settings.takeoffMode;
      dynamicSetTakeoffMode(::mission_settings.missionFull, mode, mode)
    }

    if (gm == GM_SKIRMISH || gm == GM_CAMPAIGN || gm == GM_SINGLE_MISSION)
      if (misBlk?.name && misBlk?.chapter)
        add_last_played(misBlk.chapter, misBlk.name, gm, false)
      else if (misBlk?.url)
        add_last_played("url", misBlk.url, gm, false)

    if (gm == GM_DYNAMIC)
      select_mission_full(misBlk, ::mission_settings.missionFull);
    else
      select_mission(misBlk, false)
  }

  function onFinalApply2() {
    if (this.isRestart)
      this.applyOptions()
    else {
      show_gui(false);

      let guihandler = this
      local nextFunc = function() {
          get_gui_scene().performDelayed(guihandler, function() {
            show_gui(true);
            this.applyOptions()
          })
        }

      this.guiScene.performDelayed(guihandler, nextFunc)
    }
  }

  function goBack() {
    base.goBack()
  }

  function onExit() {
    showObjById("mission_box", false, this.scene)
    quit_to_debriefing()
  }

  tempVar = 0

  isRestart = false
  restoreType = ERT_ATTEMPTS
  isTakeOff = false
  isOnline = false
  missionName = null
  missionBlk = null
  picture = ""
}
