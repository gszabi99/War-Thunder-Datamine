local contentPreset = require("scripts/customization/contentPreset.nut")
local { getWeaponNameText } = require("scripts/weaponry/weaponryVisual.nut")

::back_from_briefing <- ::gui_start_mainmenu

::g_script_reloader.registerPersistentData("BriefingGlobals", ::getroottable(), ["back_from_briefing"])

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
  battleMode = BATTLE_TYPES.AIR// only for random battles, must be removed when new modes will be added
}

::gui_start_flight <- function gui_start_flight()
{
  ::set_context_to_player("difficulty", ::get_mission_difficulty())
  ::do_start_flight()
}

::gui_start_briefing <- function gui_start_briefing() //Is this function can be called from code atm?
{
  //FIX ME: Check below really can be in more easier way.
  if (::handlersManager.getLastBaseHandlerStartFunc()
      && !::isInArray(::handlersManager.lastLoadedBaseHandlerName,
                      ["MPLobby", "SessionsList", "DebriefingModal"])
     )
    ::back_from_briefing = ::handlersManager.getLastBaseHandlerStartFunc()

  local params = {
    backSceneFunc = ::back_from_briefing
    isRestart = false
  }
  params.applyFunc <- function()
  {
    if (::get_gui_option(::USEROPT_DIFFICULTY) == "custom")
      ::gui_start_cd_options(::briefing_options_apply, this)
    else
      ::briefing_options_apply.call(this)
  }
  ::handlersManager.loadHandler(::gui_handlers.Briefing)
}

::gui_start_briefing_restart <- function gui_start_briefing_restart()
{
  dagor.debug("gui_start_briefing_restart")
  local missionName = ::current_campaign_mission
  if (missionName != null)
  {
    local missionBlk = ::DataBlock()
    missionBlk.setFrom(::get_meta_mission_info_by_name(::current_campaign_mission))
    local briefingOptions = get_briefing_options(::get_game_mode(), ::get_game_type(), missionBlk)
    if (briefingOptions.len() == 0)
      return ::restart_current_mission()
  }

  local params = {
    isRestart = true
    backSceneFunc = ::gui_start_flight_menu
  }

  local finalApplyFunc = function()
  {
    ::set_context_to_player("difficulty", ::get_mission_difficulty())
    ::restart_current_mission()
  }
  params.applyFunc <- (@(finalApplyFunc) function() {
    if (::get_gui_option(::USEROPT_DIFFICULTY) == "custom")
      ::gui_start_cd_options(finalApplyFunc)
    else
      finalApplyFunc()
  })(finalApplyFunc)

  ::handlersManager.loadHandler(::gui_handlers.Briefing, params)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_briefing_restart)
}

::briefing_options_apply <- function briefing_options_apply()
{
  local gt = ::get_game_type()
  local gm = ::get_game_mode()
  if (gm == ::GM_SINGLE_MISSION || gm == ::GM_DYNAMIC)
  {
    if (::SessionLobby.isInRoom())
    {
      if (!::is_host_in_room())
        ::SessionLobby.continueCoopWithSquad(::mission_settings);
      else
        ::scene_msg_box("wait_host_leave", null, ::loc("msgbox/please_wait"),
          [["cancel", function() {}]], "cancel",
            {
              cancel_fn = function() { ::SessionLobby.continueCoopWithSquad(::mission_settings); },
              need_cancel_fn = function() {return !::is_host_in_room(); }
              waitAnim = true,
              delayedButtons = 15
            })

      return;
    }

    if (!::g_squad_manager.isNotAloneOnline())
      return ::get_cur_base_gui_handler().goForward(::gui_start_flight)


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

  if (::SessionLobby.isInRoom())
  {
    ::SessionLobby.updateRoomAttributes(::mission_settings)
    ::get_cur_base_gui_handler().goForward(::gui_start_mp_lobby)
    return
  }

  if ((gt & ::GT_VERSUS) || ::mission_settings.missionURL != "")
    ::SessionLobby.createRoom(::mission_settings)
  else
    ::get_cur_base_gui_handler().goForward(::gui_start_flight);
}

::g_script_reloader.registerPersistentData("mission_settings", ::getroottable(), ["mission_settings"])

::get_briefing_options <- function get_briefing_options(gm, gt, missionBlk)
{
  local optionItems = []
  if (gm == ::GM_BENCHMARK || ::custom_miss_flight)
    return optionItems

  if (::get_mission_types_from_meta_mission_info(missionBlk).len())
    optionItems.append([::USEROPT_MISSION_NAME_POSTFIX, "spinner"])

  if (gm != ::GM_DYNAMIC && missionBlk.getBool("openDiffLevels", true))
    optionItems.append([::USEROPT_DIFFICULTY, "spinner"])

  if (gm==::GM_TRAINING)
    return optionItems;

  if (!missionBlk.paramExists("environment") || (gm == ::GM_TEAMBATTLE) || (gm == ::GM_DOMINATION) || (gm == ::GM_SKIRMISH))
    optionItems.append([::USEROPT_TIME, "spinner"])
  if (!missionBlk.paramExists("weather") || (gm == ::GM_TEAMBATTLE) || (gm == ::GM_DOMINATION) || (gm == ::GM_SKIRMISH))
    optionItems.append([::USEROPT_WEATHER, "spinner"])

  if (!missionBlk.paramExists("isLimitedFuel"))
    optionItems.append([::USEROPT_LIMITED_FUEL, "spinner"])

  if (!missionBlk.paramExists("isLimitedAmmo"))
    optionItems.append([::USEROPT_LIMITED_AMMO, "spinner"])

  if (missionBlk.getBool("optionalTakeOff", false))
    optionItems.append([::USEROPT_OPTIONAL_TAKEOFF, "spinner"])

  if (missionBlk.paramExists("disableAirfields"))
    optionItems.append([::USEROPT_DISABLE_AIRFIELDS, "spinner"])

  if (missionBlk?.isCustomVisualFilterAllowed != false && gm == ::GM_SKIRMISH
      && (::has_feature("EnableLiveSkins") || ::has_feature("EnableLiveDecals"))
      && contentPreset.getContentPresets().len() > 0)
    optionItems.append([::USEROPT_CONTENT_ALLOWED_PRESET, "combobox"])

  if (gm == ::GM_DYNAMIC)
  {
    if (missionBlk.paramExists("takeoff_mode"))
    {
        ::mission_name_for_takeoff <- missionBlk?.name
        optionItems.append([::USEROPT_TAKEOFF_MODE, "spinner"])
    }
//    if (missionBlk.paramExists("landing_mode"))
//        optionItems.append([::USEROPT_LANDING_MODE, "spinner"])
  }

  if (gt & ::GT_RACE)
  {
    optionItems.append([::USEROPT_RACE_LAPS, "spinner"])
    optionItems.append([::USEROPT_RACE_WINNERS, "spinner"])
    optionItems.append([::USEROPT_RACE_CAN_SHOOT, "spinner"])
  }

  if (gt & ::GT_VERSUS)
  {
    if (!missionBlk.paramExists("timeLimit") || gm == ::GM_SKIRMISH)
      optionItems.append([::USEROPT_TIME_LIMIT, "spinner"])
//    if (!missionBlk.paramExists("rounds"))
//      optionItems.append([::USEROPT_ROUNDS, "spinner"])
    if (missionBlk?.forceNoRespawnsByMission != true) //false or null
      optionItems.append([::USEROPT_VERSUS_RESPAWN, "spinner"])

    if (missionBlk.paramExists("killLimit") && !(gt & ::GT_RACE))
      optionItems.append([::USEROPT_KILL_LIMIT, "spinner"])
  }

  if (gm == ::GM_TOURNAMENT)
  {
    missionBlk.setBool("gt_mp_solo", false)
    missionBlk.setBool("allowJIP", false)
    missionBlk.setBool("isPrivate", false)
    missionBlk.setBool("isBotsAllowed", false)
    missionBlk.setInt("minPlayers", 0)
    missionBlk.setInt("maxPlayers", 0)
  } else if (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH)
  {
    if (gm == ::GM_SKIRMISH)
    {
      optionItems.append([::USEROPT_MISSION_COUNTRIES_TYPE, "spinner"])
      optionItems.append([::USEROPT_BIT_COUNTRIES_TEAM_A, "multiselect"])
      optionItems.append([::USEROPT_BIT_COUNTRIES_TEAM_B, "multiselect"])

      if (::is_skirmish_with_killstreaks(missionBlk))
        optionItems.append([::USEROPT_USE_KILLSTREAKS, "spinner"])

      optionItems.append([::USEROPT_BIT_UNIT_TYPES, "multiselect"])
      optionItems.append([::USEROPT_BR_MIN, "spinner"])
      optionItems.append([::USEROPT_BR_MAX, "spinner"])
    }

    local canUseBots = !(gt & ::GT_RACE)
    local isBotsAllowed = missionBlk?.isBotsAllowed
    if (canUseBots && isBotsAllowed == null)
    {
      optionItems.append([::USEROPT_IS_BOTS_ALLOWED, "spinner"])
      optionItems.append([::USEROPT_BOTS_RANKS, "list"])
    }
    if (canUseBots && isBotsAllowed != false && ::has_feature("Tanks") &&
      ::is_mission_for_unittype(missionBlk, ::ES_UNIT_TYPE_TANK))
    {
      optionItems.append([::USEROPT_USE_TANK_BOTS, "spinner"])
      optionItems.append([::USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, "spinner"])
    }
    if (canUseBots && isBotsAllowed != false && ::has_feature("ShipBotsOption") &&
      ::is_mission_for_unittype(missionBlk, ::ES_UNIT_TYPE_SHIP))
      optionItems.append([::USEROPT_USE_SHIP_BOTS, "spinner"])

    if (!::SessionLobby.isInRoom())
      optionItems.append([::USEROPT_MAX_PLAYERS, "spinner"])

    if (gm == ::GM_SKIRMISH)
    {
      if (gt & ::GT_RACE)
        missionBlk.setBool("allowJIP", false)
      else
        optionItems.append([::USEROPT_ALLOW_JIP, "spinner"])
    }

  }

  if (gm == ::GM_SKIRMISH || (::g_squad_manager.isInSquad() && ::is_gamemode_coop(gm)))
    optionItems.append([::USEROPT_CLUSTER, "spinner"])

  if ((gt & ::GT_SP_USE_SKIN) && !(gt & ::GT_VERSUS))
  {
    local aircraft = missionBlk.getStr("player_class", "")
    ::aircraft_for_weapons = aircraft
    optionItems.append([::USEROPT_SKIN, "spinner"])
  }

  if (gm == ::GM_SKIRMISH && ::has_feature("LiveBroadcast"))
    optionItems.append([::USEROPT_DEDICATED_REPLAY, "spinner"])

  if (gm == ::GM_SKIRMISH)
    optionItems.append([::USEROPT_SESSION_PASSWORD, "editbox"])

  return optionItems
}

::if_any_mission_completed_in <- function if_any_mission_completed_in(gm)
{
  local mi = ::get_meta_missions_info(gm)
  for (local i = 0; i < mi.len(); ++i)
  {
    local missionBlk = mi[i]

    local chapterName = missionBlk.getStr("chapter","")
    local name = missionBlk.getStr("name","")

    if (::get_mission_progress(chapterName + "/" + name) < 3) // completed
      return true;
  }
  return false
}

::if_any_mission_completed <- function if_any_mission_completed()
{
  return ::if_any_mission_completed_in(::GM_CAMPAIGN) ||
         ::if_any_mission_completed_in(::GM_SINGLE_MISSION)
}

::get_mission_types_from_meta_mission_info <- function get_mission_types_from_meta_mission_info(metaInfo)
{
  local types = [];
  local missionTypes = metaInfo.getBlockByName("missionType")
  if (missionTypes)
  {
    foreach (key, val in missionTypes)
      if (val)
        types.append(key)
  }
  return types
}

local function get_mission_desc_text(missionBlk)
{
  local descrAdd = ""

  local sm_location = missionBlk.getStr("locationName",
                            ::map_to_location(missionBlk.getStr("level", "")))
  if (sm_location != "")
    descrAdd += (::loc("options/location") + ::loc("ui/colon") + ::loc("location/" + sm_location))

  local sm_time = missionBlk.getStr("time", missionBlk.getStr("environment", ""))
  if (sm_time != "")
    descrAdd += (descrAdd != "" ? "; " : "") + ::get_mission_time_text(sm_time)

  local sm_weather = missionBlk.getStr("weather", "")
  if (sm_weather != "")
    descrAdd += (descrAdd != "" ? "; " : "") + ::loc("options/weather" + sm_weather)

  local aircraft = missionBlk.getStr("player_class", "")
  if (aircraft != "")
  {
    local sm_aircraft = ::loc("options/aircraft") + ::loc("ui/colon") +
      getUnitName(aircraft) + "; " +
      getWeaponNameText(aircraft, null, missionBlk.getStr("player_weapons", ""), ", ")

    descrAdd += "\n" + sm_aircraft
  }

  if (missionBlk.getStr("recommendedPlayers","") != "")
    descrAdd += ("\n" + ::format(::loc("players_recommended"), missionBlk.getStr("recommendedPlayers","1-4")) + "\n")

  return descrAdd
}

class ::gui_handlers.Briefing extends ::gui_handlers.GenericOptions
{
  sceneBlkName = "gui/briefing.blk"
  sceneNavBlkName = "gui/navBriefing.blk"

  function initScreen()
  {
    ::select_controller(true, true)
    base.initScreen()
    local gm = ::get_game_mode()
    ::set_gui_options_mode(::get_options_mode(gm))

    local campaignName = ::current_campaign_id
    missionName = ::current_campaign_mission

    if (campaignName == null || missionName == null)
      return

    missionBlk = ::DataBlock()
    missionBlk.setFrom(::get_meta_mission_info_by_name(missionName))

    if (gm == ::GM_EVENT)
      ::mission_settings.coop = true;
    else if ((gm != ::GM_SINGLE_MISSION) && (gm != ::GM_USER_MISSION) && (gm != ::GM_DYNAMIC) && (gm != ::GM_BUILDER))
      ::mission_settings.coop = false;
    else if (gm == ::GM_SINGLE_MISSION)
    {
      if (!missionBlk.getBool("gt_cooperative", false) || ::is_user_mission(missionBlk))
        ::mission_settings.coop = false;
    }
    //otherwise it's set from menu

    missionBlk.setBool("gt_cooperative", ::mission_settings.coop)
    missionBlk.setInt("_gameMode", gm)
    if (gm == ::GM_DYNAMIC || gm == ::GM_BUILDER)
      if (missionBlk.getStr("restoreType", "attempts") == "tactical control")
        missionBlk.setStr("restoreType", "attempts");

    if (isRestart) //temp hack because it doesn't work for some weird reason
    {
      missionBlk.setBool("isLimitedFuel", ::mission_settings.isLimitedFuel)
      missionBlk.setBool("isLimitedAmmo", ::mission_settings.isLimitedAmmo)
    }

    ::select_mission(missionBlk, false);

    local gt = ::get_game_type(); //we know it after select_mission()

    dagor.debug(::format("[BRIEFING] mode %d, type %d, mission %s", gm, gt, missionName))

    local title = ::loc_current_mission_name()
    local desc = ::loc_current_mission_desc()
    picture = missionBlk.getStr("backgroundImage", "")
    restoreType = ::string_to_restore_type(missionBlk.getStr("restoreType", "attempts"))
    isTakeOff = missionBlk.getBool("optionalTakeOff", false)
    isOnline = missionBlk.getBool("isOnline", false)

    local aircraft = missionBlk.getStr("player_class", "")
    ::aircraft_for_weapons = aircraft

    ::mission_settings.name = missionName
    ::mission_settings.postfix = null
    ::mission_settings.aircraft  = aircraft
    ::mission_settings.weapon = missionBlk.getStr("player_weapons", "")
    ::mission_settings.players = 4;

    local descrAdd = get_mission_desc_text(missionBlk)
    if (descrAdd != "")
      desc += (desc.len() ? "\n\n" : "") + descrAdd

    scene.findObject("mission_title").setValue(title)
    scene.findObject("mission_desc").setValue(desc)

    optionsContainers = []

    local optionItems = get_briefing_options(gm, gt, missionBlk)
    local container = create_options_container("briefing_options", optionItems, true)
    guiScene.replaceContentFromText("optionslist", container.tbl, container.tbl.len(), this)
    if (optionItems.len()>0)
    {
      local listObj = showSceneBtn("optionslist", true)
      listObj.height = "" + optionItems.len() + "*@baseTrHeight" //bad solution, but freeheight doesn't work correct
    }
    optionsContainers.append(container.descr)

    if (restoreType == ::ERT_TACTICAL_CONTROL)
    {
      showSceneBtn("attempts", false)
      showSceneBtn("lbl_attempts", false)
    }

    if (isRestart)
      showSceneBtn("btn_back", false)
  }

  function onApply(obj)
  {
    finalApply(missionBlk)
    onFinalApply2()
  }

  function finalApply(misBlk)
  {
    if (!isValid())
      return

    local gm = ::get_game_mode()
    local gt = ::get_game_type()
    local value = ""

    if (!misBlk)
    {
      misBlk = ::DataBlock()
      ::get_current_mission_info(misBlk)
    }

    if (gm == ::GM_DYNAMIC)
    {
      ::mission_settings.missionFull = ::mission_settings.dynlist[::mission_settings.currentMissionIdx]
      misBlk.setFrom(::mission_settings.missionFull.mission_settings.mission);
      misBlk.setInt("currentMissionIdx", ::mission_settings.currentMissionIdx);
      misBlk.setInt("takeoffMode", ::mission_settings.takeoffMode);
    }

    misBlk.setInt("_gameMode", gm)

    if (!("loc_name" in misBlk))
      misBlk.setStr("loc_name", "")

    ::select_controller(false, true)

    ::set_gui_option(::USEROPT_NUM_ATTEMPTS, -1)

    if (gm == ::GM_DYNAMIC)
    {
      misBlk.setStr("difficulty", ::get_option(::USEROPT_DIFFICULTY).values[::mission_settings.diff])
    }
    else if (getObj("difficulty") != null)
    {
      ::mission_settings.diff = getObj("difficulty").getValue();
      misBlk.setStr("difficulty", ::get_option(::USEROPT_DIFFICULTY).values[::mission_settings.diff])
    }
    else
      ::mission_settings.diff = 0;

    value = getOptValue(::USEROPT_LIMITED_FUEL, false)
    if (value!=null)
    {
      ::mission_settings.isLimitedFuel = value
      misBlk.setBool("isLimitedFuel", ::mission_settings.isLimitedFuel)
    }

    value = getOptValue(::USEROPT_LIMITED_AMMO, false)
    if (value!=null)
    {
      ::mission_settings.isLimitedAmmo = value
      misBlk.setBool("isLimitedAmmo", ::mission_settings.isLimitedAmmo)
    }

    value = getOptValue(::USEROPT_OPTIONAL_TAKEOFF, false)
    if (value!=null)
      misBlk.setBool("takeOffOnStart", value && misBlk.getBool("isOptionalTakeOff",false))

    value = getOptValue(::USEROPT_DISABLE_AIRFIELDS, false)
    if (value!=null)
      misBlk.setBool("disableAirfields", value)

    value = getOptValue(::USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, false)
    if (value!=null)
      misBlk.setBool("spawnAiTankOnTankMaps", value)

    value = getOptValue(::USEROPT_SKIN, false)
    if (value!=null && (gt & ::GT_DYNAMIC))
    {
      local ar = ::mission_settings.missionFull.units % "armada";
      for (local i = 0; i < ar.len(); i++)
      {
        if (ar[i].name.indexof("#player.") != null)
          ar[i].props.skin = value;
      }
    }

    ::mission_settings.coop = ::mission_settings.coop && ::g_squad_manager.isNotAloneOnline()
    misBlk.setBool("gt_cooperative", ::mission_settings.coop)
    misBlk.setBool("gt_versus", (gt & ::GT_VERSUS))

    if (::mission_settings.coop)
    {
      ::mission_settings.players = 4;
      misBlk.setInt("_players", 4)
      misBlk.setInt("maxPlayers", 4)
      misBlk.setBool("gt_use_lb", gm == ::GM_EVENT)
      misBlk.setBool("gt_use_replay", true)
      misBlk.setBool("gt_use_stats", true)
      misBlk.setBool("gt_sp_restart", false)
      misBlk.setBool("isBotsAllowed", true)
      misBlk.setBool("autoBalance", false)
    }
    if (gt & ::GT_VERSUS)
    {
      misBlk.setBool("gt_use_lb", true)
      misBlk.setBool("gt_use_replay", true)
      misBlk.setBool("gt_use_stats", true)
      misBlk.setBool("gt_sp_restart", false)
    }

    value = getOptValue(::USEROPT_TIME_LIMIT, false)
    if (value!=null)
      misBlk.setInt("timeLimit", value)

    value = getOptValue(::USEROPT_KILL_LIMIT, false)
    if (value!=null)
      misBlk.setInt("killLimit", value)

    value = getOptValue(::USEROPT_ROUNDS, false)
    if (value!=null)
    {
      misBlk.setInt("rounds", value)
      ::mission_settings.rounds = value
    }

    value = getOptValue(::USEROPT_VERSUS_RESPAWN, false)
    if (value!=null)
    {
      misBlk.setInt("maxRespawns", value)
      ::mission_settings.maxRespawns = value
    }

    if (gm == ::GM_SKIRMISH)
    {
      value = getOptValue(::USEROPT_ALLOW_JIP, false)
      if (value != null)
      {
        misBlk.setBool("allowJIP", value)
        ::mission_settings.allowJIP = value
      }

      if (::is_skirmish_with_killstreaks(misBlk))
      {
        value = getOptValue(::USEROPT_USE_KILLSTREAKS, false)
        misBlk.setBool("useKillStreaks", value)
      }
    }

    local isBotsAllowed = getOptValue(::USEROPT_IS_BOTS_ALLOWED, false)
    if (value == null)
      if (misBlk.paramExists("isBotsAllowed"))
        isBotsAllowed = misBlk.isBotsAllowed
      else
        isBotsAllowed = (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH)
                        && !(gt & ::GT_RACE)
                        && getOptValue(::USEROPT_IS_BOTS_ALLOWED)

    misBlk.setBool("isBotsAllowed", isBotsAllowed)
    ::mission_settings.isBotsAllowed = isBotsAllowed

    if (isBotsAllowed)
      misBlk.useTankBots = ::has_feature("Tanks") && getOptValue(::USEROPT_USE_TANK_BOTS, false)

    if (isBotsAllowed)
      misBlk.useShipBots = ::has_feature("Ships") && getOptValue(::USEROPT_USE_SHIP_BOTS, false)

    if (isBotsAllowed)
    {
      value = getOptValue(::USEROPT_BOTS_RANKS, false)
      if (value != null)
        misBlk.ranks = ::build_blk_from_container(value)
    }

    if (gm == ::GM_SKIRMISH)
    {
      value = ::has_feature("LiveBroadcast") ? getOptValue(::USEROPT_DEDICATED_REPLAY) : false
      misBlk.setBool("dedicatedReplay", value)
      ::mission_settings.dedicatedReplay = value
    }

    if (!("url" in misBlk))
      misBlk.setStr("url", "") //Must-be param, to override on matching if used before

    ::mission_settings.missionURL = misBlk.url
    ::mission_settings.sessionPassword =  get_option(::USEROPT_SESSION_PASSWORD).value

    if (misBlk.paramExists("autoBalance"))
    {
      ::mission_settings.autoBalance = misBlk.getBool("autoBalance", true)
    }

    value = getOptValue(::USEROPT_MIN_PLAYERS, false)
    if (value!=null)
      misBlk.setInt("minPlayers", value)

    value = getOptValue(::USEROPT_MAX_PLAYERS, false)
    if (value!=null)
    {
      misBlk.setInt("maxPlayers", value)
      ::mission_settings.players = value;
      misBlk.setInt("_players", value)
    }
    else if (gt & ::GT_VERSUS)
    {
      if (::SessionLobby.isInRoom())
      {
        misBlk.setInt("maxPlayers", ::SessionLobby.getMaxMembersCount())
        ::mission_settings.players = ::SessionLobby.getMaxMembersCount()
      }
      else
      {
        ::mission_settings.players = ::global_max_players_versus;
        misBlk.setInt("_players", ::global_max_players_versus)
      }
    }

    value = getOptValue(::USEROPT_CLUSTER, false)
    if (value!=null)
      ::mission_settings.cluster <- value

    value = getOptValue(::USEROPT_FRIENDS_ONLY, false)
    if (value!=null)
    {
      misBlk.setBool("isPrivate", value)
      ::mission_settings.friendOnly = value
      misBlk.setBool("allowJIP", !value)
      ::mission_settings.allowJIP = !value
    }
    else if (gm == ::GM_DYNAMIC)
    {
      misBlk.setBool("isPrivate", ::mission_settings.friendOnly)
      misBlk.setBool("allowJIP", ! ::mission_settings.friendOnly)
      misBlk.setBool("isBotsAllowed", true)
      misBlk.setBool("autoBalance", false)
    }
    else if ((gm == ::GM_SINGLE_MISSION) && (guiScene["coop_mode"] != null))
    {
      misBlk.setBool("isPrivate", ::mission_settings.friendOnly)
      misBlk.setBool("allowJIP", ! ::mission_settings.friendOnly)
    }
    else if ((gm != ::GM_DYNAMIC) && !::SessionLobby.isInRoom())
      ::mission_settings.friendOnly = false

    value = getOptValue(::USEROPT_TIME, false)
    if (value!=null)
      misBlk.setStr("environment", value)

    value = getOptValue(::USEROPT_WEATHER, false)
    if (value!=null)
      misBlk.setStr("weather", value)

    value = getOptValue(::USEROPT_MISSION_COUNTRIES_TYPE, false)
    if (value!=null)
      ::mission_settings.countriesType <- value

    foreach(opt in [::USEROPT_BIT_COUNTRIES_TEAM_A, ::USEROPT_BIT_COUNTRIES_TEAM_B])
    {
      local option = ::get_option(opt)
      local obj = scene.findObject(option.id)
      if (obj)
        ::mission_settings[option.sideTag + "_bitmask"] <- obj.getValue()
    }

    value = getOptValue(::USEROPT_BIT_UNIT_TYPES, false)
    local option = ::get_option(::USEROPT_BIT_UNIT_TYPES)
    if (value != null && value != option.availableUnitTypesMask)
      ::mission_settings.userAllowedUnitTypesMask <- value

    local mrankMin = getOptValue(::USEROPT_BR_MIN, 0)
    local mrankMax = getOptValue(::USEROPT_BR_MAX, 0)
    if (mrankMin > 0 || mrankMax < ::MAX_ECONOMIC_RANK)
    {
      ::mission_settings.mrankMin <- mrankMin
      ::mission_settings.mrankMax <- mrankMax
    }

    value = getOptValue(::USEROPT_CONTENT_ALLOWED_PRESET, false)
    if (value!=null)
      misBlk.setStr("allowedTagsPreset", value)

    if (gt & ::GT_RACE)
    {
      misBlk.raceLaps = getOptValue(::USEROPT_RACE_LAPS)
      misBlk.raceWinners = getOptValue(::USEROPT_RACE_WINNERS)
      misBlk.raceForceCannotShoot = !getOptValue(::USEROPT_RACE_CAN_SHOOT)
    }

    misBlk.setInt("_gameMode", gm)
    if (::SessionLobby.isInRoom())
    {
      misBlk.setBool("isPrivate", ::mission_settings.friendOnly)
      misBlk.setBool("allowJIP", ::mission_settings.allowJIP)
    }

    if (gm == ::GM_DYNAMIC || gm == ::GM_BUILDER)
      if (misBlk.getStr("restoreType", "attempts") == "tactical control")
        misBlk.setStr("restoreType", "attempts");

    ::mission_settings.time = misBlk.getStr("environment", "")
    ::mission_settings.weather = misBlk.getStr("weather", "")
    ::mission_settings.isLimitedFuel = misBlk.getBool("isLimitedFuel", false)
    ::mission_settings.isLimitedAmmo = misBlk.getBool("isLimitedAmmo", false)
    ::mission_settings.takeoffMode = getOptValue(::USEROPT_TAKEOFF_MODE, true)

    ::mission_settings.mission = misBlk

    if (gm == ::GM_DYNAMIC)
    {
      ::mission_settings.missionFull = ::mission_settings.dynlist[::mission_settings.currentMissionIdx]

      local mode = ::mission_settings.takeoffMode;
      ::dynamic_set_takeoff_mode(::mission_settings.missionFull, mode, mode);
    }

    if (gm == ::GM_SKIRMISH || gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION)
      if (misBlk?.name && misBlk?.chapter)
        ::add_last_played(misBlk.chapter, misBlk.name, gm, false)
      else if (misBlk?.url)
        ::add_last_played("url", misBlk.url, gm, false)

    if (gm == ::GM_DYNAMIC)
      ::select_mission_full(misBlk, ::mission_settings.missionFull);
    else
      ::select_mission(misBlk, false)
  }

  function onFinalApply2()
  {
    if (isRestart)
      applyOptions()
    else
    {
      ::show_gui(false);

      local guihandler = this
      local nextFunc = (@(guihandler) function() {
          ::get_gui_scene().performDelayed(guihandler, function()
          {
            ::show_gui(true);
            applyOptions()
          })
        })(guihandler)

      guiScene.performDelayed(guihandler, nextFunc)
    }
  }

  function goBack()
  {
    ::select_controller(false, true)
    base.goBack()
  }

  function onExit()
  {
    showSceneBtn("mission_box", false)
    ::quit_to_debriefing()
  }

  tempVar = 0

  isRestart = false
  restoreType = ::ERT_ATTEMPTS
  isTakeOff = false
  isOnline = false
  missionName = null
  missionBlk = null
  picture = ""
}
