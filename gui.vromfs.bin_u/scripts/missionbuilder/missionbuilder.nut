let { showedUnit } = require("scripts/slotbar/playerCurUnit.nut")
local { getCdBaseDifficulty } = ::require_native("guiOptions")

::gui_start_builder <- function gui_start_builder(params = {})
{
  ::gui_start_modal_wnd(::gui_handlers.MissionBuilder, params)
}

::gui_handlers.MissionBuilder <- class extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "%gui/navBuilderOptions.blk"
  wndGameMode = ::GM_BUILDER
  wndOptionsMode = ::OPTIONS_MODE_DYNAMIC

  applyAtClose = false
  can_generate_missions = true
  needSlotbar = true

  function initScreen()
  {
    ::gui_handlers.GenericOptions.initScreen.bindenv(this)()

    guiScene.setUpdatesEnabled(false, false)
    init_builder_map()
    generate_builder_list(true)

    let options =
    [
      [::USEROPT_DYN_MAP, "combobox"],
//      [::USEROPT_YEAR, "spinner"],
//      [::USEROPT_MP_TEAM, "spinner"],
      [::USEROPT_DYN_ZONE, "combobox"],
      [::USEROPT_DYN_SURROUND, "spinner"],
      [::USEROPT_DMP_MAP, "spinner"],
  //    [::USEROPT_DYN_ALLIES, "spinner"],
      [::USEROPT_FRIENDLY_SKILL, "spinner"],
  //    [::USEROPT_DYN_ENEMIES, "spinner"],
      [::USEROPT_ENEMY_SKILL, "spinner"],
      [::USEROPT_DIFFICULTY, "spinner"],
      [::USEROPT_TIME, "spinner"],
      [::USEROPT_WEATHER, "spinner"],
      [::USEROPT_TAKEOFF_MODE, "combobox"],
      [::USEROPT_LIMITED_FUEL, "spinner"],
      [::USEROPT_LIMITED_AMMO, "spinner"],
  //    [::USEROPT_SESSION_PASSWORD, "editbox"],
    ]

    let container = create_options_container("builder_options", options, true, 0.5, true)
    let optListObj = scene.findObject("optionslist")
    guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)
    optionsContainers.append(container.descr)
    setSceneTitle(::loc("mainmenu/btnDynamicTraining"), scene, "menu-title")

    let desc = ::get_option(::USEROPT_DYN_ZONE)
    let dynZoneObj = guiScene["dyn_zone"]
    local value = desc.value
    if(::checkObj(dynZoneObj))
      value = guiScene["dyn_zone"].getValue()

    ::g_map_preview.setSummaryPreview(scene.findObject("tactical-map"), ::DataBlock(), desc.values[value])

    if (::mission_settings.dynlist.len() == 0)
      return msgBox("no_missions_error", ::loc("msgbox/appearError"),
                     [["ok", goBack ]], "ok", { cancel_fn = goBack})

    update_takeoff()

    reinitOptionsList()
    guiScene.setUpdatesEnabled(true, true)

    if (::fetch_first_builder())
      randomize_builder_options()

    if (needSlotbar)
      createSlotbar()

    ::move_mouse_on_obj(scene.findObject("btn_select"))
  }

  function reinitOptionsList()
  {
    if (!::check_obj(scene))
      return goBack()

    updateButtons()

    let showOptions = isBuilderAvailable()

    let optListObj = scene.findObject("options_data")
    let textObj = scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions ? ""
      : ::loc(showedUnit.value != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"))

    if (!showOptions)
      return

    update_dynamic_map()
  }

  function isBuilderAvailable()
  {
    return ::isUnitAvailableForGM(showedUnit.value, ::GM_BUILDER)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    let available = isBuilderAvailable()
    scene.findObject("btn_select").inactiveColor = available? "no" : "yes"
    showSceneBtn("btn_random", available)
    showSceneBtn("btn_inviteSquad", ::enable_coop_in_QMB && ::g_squad_manager.canInviteMember())
  }

  function onApply()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(::GM_BUILDER)
      }))
      return

    if (!isBuilderAvailable())
      return msgBox("not_available", ::loc(showedUnit.value != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"),
        [["ok"]], "ok")

    if (::isInArray(getSceneOptValue(::USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!::check_diff_pkg(::g_difficulty.SIMULATOR.diffCode))
        return

    applyOptions()
  }

  function getSceneOptRes(optName)
  {
    let option = ::get_option(optName)
    let obj = scene.findObject(option.id)
    local value = obj? obj.getValue() : -1
    if (!(value in option.items))
      value = option.value
    return { name = option.items[value], value = option.values[value] }
  }

  function init_builder_map()
  {
    let mapData = getSceneOptRes(::USEROPT_DYN_MAP)
    ::mission_settings.layout <- mapData.value
    ::mission_settings.layoutName <- mapData.name

    let settings = ::DataBlock();
    local playerSide = 1
    foreach (tag in (showedUnit.value?.tags ?? []))
      if (tag == "axis")
      {
        playerSide = 2
        break
      }
    settings.setInt("playerSide", /*getSceneOptValue(::USEROPT_MP_TEAM)*/playerSide)


    ::dynamic_init(settings, mapData.value);
  }

  function generate_builder_list(wait)
  {
    if (!can_generate_missions)
      return;
    if (showedUnit.value == null)
      return

    ::aircraft_for_weapons = showedUnit.value.name

    let settings = ::DataBlock();
    settings.setStr("player_class", showedUnit.value.name)
    settings.setStr("player_weapons", ::get_gui_option(::USEROPT_WEAPONS) ?? "")
    settings.setStr("player_skin", getSceneOptValue(::USEROPT_SKIN) || "")
    settings.setStr("wishSector", getSceneOptValue(::USEROPT_DYN_ZONE))
    settings.setInt("sectorSurround", getSceneOptValue(::USEROPT_DYN_SURROUND))
    settings.setStr("year", "year_any" /*getSceneOptValue(::USEROPT_YEAR)*/)
    settings.setBool("isQuickMissionBuilder", true)

    ::mission_settings.dynlist <- ::dynamic_get_list(settings, wait)

    let add = []
    for (local i = 0; i < ::mission_settings.dynlist.len(); i++)
    {
      let misblk = ::mission_settings.dynlist[i].mission_settings.mission

      ::mergeToBlk(::missionBuilderVehicleConfigForBlk, misblk)

      misblk.setStr("mis_file", ::mission_settings.layout)
      misblk.setStr("type", "builder")
      misblk.setStr("chapter", "builder")
      if (::mission_settings.coop)
        misblk.setBool("gt_cooperative", true);
      add.append(misblk)
    }
    ::add_mission_list_full(::GM_BUILDER, add, ::mission_settings.dynlist)
  }

  function update_dynamic_map()
  {
    let descr = ::get_option(::USEROPT_DYN_MAP)
    let txt = ::create_option_list(descr.id, descr.items, descr.value, descr.cb, false)
    let dObj = scene.findObject(descr.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    init_builder_map()
    if (descr.cb in this)
      this[descr.cb](dObj)
    return descr
  }

  function update_dynamic_layout(guiScene, obj, descr)
  {
    init_builder_map()

    let descrWeap = ::get_option(::USEROPT_DYN_ZONE)
    let txt = ::create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, "onSectorChange", false)
    let dObj = scene.findObject(descrWeap.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
    return descrWeap
  }

  function update_dynamic_sector(guiScene, obj, descr)
  {
    generate_builder_list(true)
    let descrWeap = ::get_option(::USEROPT_DMP_MAP)
    let txt = ::create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, null, false)
    let dObj = scene.findObject(descrWeap.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    update_takeoff()

    ::g_map_preview.setSummaryPreview(scene.findObject("tactical-map"), ::DataBlock(), getSceneOptValue(::USEROPT_DYN_ZONE))

    return descrWeap
  }

  function update_takeoff()
  {
    local haveTakeOff = false
    let mapObj = scene.findObject("dyn_mp_map")
    if (::checkObj(mapObj))
      ::mission_settings.currentMissionIdx = mapObj.getValue()

    let dynMission = ::getTblValue(::mission_settings.currentMissionIdx, ::mission_settings.dynlist)
    if (!dynMission)
      return

    if (dynMission.mission_settings.mission.paramExists("takeoff_mode"))
      haveTakeOff = true

    ::mission_name_for_takeoff <- dynMission.mission_settings.mission.name
    let descrWeap = ::get_option(::USEROPT_TAKEOFF_MODE)
    if (!haveTakeOff)
    {
      for(local i=0; i<descrWeap.items.len(); i++)
        descrWeap.items[i] = { text = descrWeap.items[i], enabled = (i==0) }
      descrWeap.value = 0
    }
    let txt = ::create_option_combobox(descrWeap.id, descrWeap.items, descrWeap.value, "onMissionChange", false)
    let dObj = scene.findObject(descrWeap.id)
    if (::checkObj(dObj))
      guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
  }

  function setRandomOpt(optName)
  {
    let desc = ::get_option(optName)
    let obj = scene.findObject(desc.id)
    if(desc.values.len() == 0)
    {
      let settings = ::toString({                      // warning disable: -declared-never-used
          DYN_MAP = getSceneOptValue(::USEROPT_DYN_MAP),
          DYN_ZONE = getSceneOptValue(::USEROPT_DYN_ZONE),
          DYN_SURROUND = getSceneOptValue(::USEROPT_DYN_SURROUND),
          DMP_MAP = getSceneOptValue(::USEROPT_DMP_MAP),
          FRIENDLY_SKILL = getSceneOptValue(::USEROPT_FRIENDLY_SKILL),
          ENEMY_SKILL = getSceneOptValue(::USEROPT_ENEMY_SKILL),
          DIFFICULTY = getSceneOptValue(::USEROPT_DIFFICULTY),
          TIME = getSceneOptValue(::USEROPT_TIME),
          WEATHER = getSceneOptValue(::USEROPT_WEATHER),
          TAKEOFF_MODE = getSceneOptValue(::USEROPT_TAKEOFF_MODE),
          LIMITED_FUEL = scene.findObject(::get_option(::USEROPT_LIMITED_FUEL)?.id ?? "").getValue(),
          LIMITED_AMMO = scene.findObject(::get_option(::USEROPT_LIMITED_AMMO)?.id ?? "").getValue()
        })
      let currentUnit = showedUnit.value?.name         // warning disable: -declared-never-used
      let slotbarUnit = ::get_cur_slotbar_unit()?.name // warning disable: -declared-never-used
      let optId = desc.id                              // warning disable: -declared-never-used
      let values = ::toString(desc.values)             // warning disable: -declared-never-used
      ::script_net_assert_once("MissionBuilder", "ERROR: Empty value in options.")
      return
    }
    if (obj) obj.setValue(::math.rnd() % desc.values.len())
  }

  function randomize_builder_options()
  {
    if (!::checkObj(scene))
      return

    can_generate_missions = false;

    guiScene.setUpdatesEnabled(false, false)
    foreach(o in [/*::USEROPT_YEAR,*/ ::USEROPT_DYN_MAP /*, ::USEROPT_MP_TEAM*/ ] )
      setRandomOpt(o)

    onLayoutChange(scene.findObject("dyn_map"))
    setRandomOpt(::USEROPT_DYN_ZONE)
    guiScene.setUpdatesEnabled(true, true)

    guiScene.performDelayed(this, function()
      {
        if (!isValid())
          return
        foreach(o in [::USEROPT_TIME, ::USEROPT_WEATHER, ::USEROPT_DYN_SURROUND])
          setRandomOpt(o)

        onSectorChange(scene.findObject("dyn_zone"))

        guiScene.performDelayed(this, function()
          {
            if (!isValid())
              return
            can_generate_missions = true

            setRandomOpt(::USEROPT_DMP_MAP)
            update_takeoff()
          }
        )
      }
    )
  }

  function applyFunc()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(::GM_BUILDER)
      }))
      return

    ::mission_settings.currentMissionIdx = scene.findObject("dyn_mp_map").getValue()
    let fullMissionBlk = ::getTblValue(::mission_settings.currentMissionIdx, ::mission_settings.dynlist)
    if (!fullMissionBlk)
      return

    if (fullMissionBlk.mission_settings.mission.paramExists("takeoff_mode"))
    {
      let takeoff_mode = scene.findObject("takeoff_mode").getValue()
      ::dynamic_set_takeoff_mode(fullMissionBlk, takeoff_mode, takeoff_mode)
    }

    let settings = DataBlock()
    settings.setInt("allyCount",  getSceneOptValue(::USEROPT_DYN_ALLIES))
    settings.setInt("enemyCount", getSceneOptValue(::USEROPT_DYN_ENEMIES))
    settings.setInt("allySkill",  getSceneOptValue(::USEROPT_FRIENDLY_SKILL))
    settings.setInt("enemySkill", getSceneOptValue(::USEROPT_ENEMY_SKILL))
    settings.setStr("dayTime",    getSceneOptValue(::USEROPT_TIME))
    settings.setStr("weather",    getSceneOptValue(::USEROPT_WEATHER))

    ::mission_settings.coop = (::enable_coop_in_QMB && ::g_squad_manager.isInSquad())
    ::mission_settings.friendOnly = false
    ::mission_settings.allowJIP = true

    ::dynamic_tune(settings, fullMissionBlk)

    let missionBlk = fullMissionBlk.mission_settings.mission

    missionBlk.setInt("_gameMode", ::GM_BUILDER)
    missionBlk.setBool("gt_cooperative", ::mission_settings.coop)
    if (::mission_settings.coop)
    {
      ::mission_settings.players = 4;
      missionBlk.setInt("_players", 4)
      missionBlk.setInt("maxPlayers", 4)
      missionBlk.setBool("gt_use_lb", false)
      missionBlk.setBool("gt_use_replay", true)
      missionBlk.setBool("gt_use_stats", true)
      missionBlk.setBool("gt_sp_restart", false)
      missionBlk.setBool("isBotsAllowed", true)
      missionBlk.setBool("autoBalance", false)
      missionBlk.setBool("isPrivate", ::mission_settings.friendOnly)
      missionBlk.setBool("allowJIP", ! ::mission_settings.friendOnly)
    }

    missionBlk.setStr("difficulty", getSceneOptValue(::USEROPT_DIFFICULTY))
    missionBlk.setStr("restoreType", "attempts")

    missionBlk.setBool("isLimitedFuel", ::get_option(::USEROPT_LIMITED_FUEL).value)
    missionBlk.setBool("isLimitedAmmo", ::get_option(::USEROPT_LIMITED_AMMO).value)

    ::current_campaign_mission = missionBlk.getStr("name","")
    ::mission_settings.mission = missionBlk
    ::mission_settings.missionFull = fullMissionBlk
    ::select_mission_full(missionBlk, fullMissionBlk);

    //dlog("missionBlk:"); debugTableData(missionBlk)

    ::gui_start_builder_tuner()
  }

  function onLayoutChange(obj)
  {
    guiScene.performDelayed(this, function() {
      if (!isValid())
        return
      updateOptionDescr(obj, update_dynamic_layout)
      updateOptionDescr(obj, update_dynamic_sector)
    })
  }

  function onMissionChange(obj)
  {
    update_takeoff()
  }

  function onSectorChange(obj)
  {
    guiScene.performDelayed(this, function() {
      if (!isValid())
        return
      updateOptionDescr(obj, update_dynamic_sector)
    })
  }

  function onYearChange(obj)
  {
    guiScene.performDelayed(this, function() {
      if (!isValid())
        return
      updateOptionDescr(obj, update_dynamic_sector)
    })
  }

  function onRandom(obj)
  {
    randomize_builder_options()
  }

  function getCurrentEdiff()
  {
    let diffValue = getSceneOptValue(::USEROPT_DIFFICULTY)
    let difficulty = (diffValue == "custom") ?
      ::g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()) :
      ::g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1)
    {
      let battleType = ::get_battle_type_by_unit(showedUnit.value)
      return difficulty.getEdiff(battleType)
    }
    return ::get_current_ediff()
  }

  function getHandlerRestoreData()
  {
    return {
      openData = { needSlotbar = needSlotbar }
    }
  }

  function onEventBeforeStartMissionBuilder(p)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  onEventShowedUnitChanged = @(p) reinitOptionsList()
}