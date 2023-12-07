//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let DataBlock = require("DataBlock")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { rnd } = require("dagor.random")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_obj, handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_gui_option, getCdBaseDifficulty } = require("guiOptions")
let { dynamicInit, dynamicGetList, dynamicTune, dynamicSetTakeoffMode,
} = require("dynamicMission")
let { select_mission_full } = require("guiMission")
let { setSummaryPreview } = require("%scripts/missions/mapPreview.nut")
let { OPTIONS_MODE_DYNAMIC, USEROPT_DYN_MAP, USEROPT_DYN_ZONE, USEROPT_DYN_SURROUND,
  USEROPT_DMP_MAP, USEROPT_FRIENDLY_SKILL, USEROPT_ENEMY_SKILL, USEROPT_DIFFICULTY,
  USEROPT_TIME, USEROPT_CLIME, USEROPT_TAKEOFF_MODE, USEROPT_LIMITED_FUEL,
  USEROPT_LIMITED_AMMO, USEROPT_WEAPONS, USEROPT_SKIN, USEROPT_DYN_ALLIES,
  USEROPT_DYN_ENEMIES
} = require("%scripts/options/optionsExtNames.nut")
let { create_options_container } = require("%scripts/options/optionsExt.nut")
let { getCurSlotbarUnit } = require("%scripts/slotbar/slotbarState.nut")

::gui_start_builder <- function gui_start_builder(params = {}) {
  loadHandler(gui_handlers.MissionBuilder, params)
}

gui_handlers.MissionBuilder <- class (gui_handlers.GenericOptionsModal) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "%gui/navBuilderOptions.blk"
  wndGameMode = GM_BUILDER
  wndOptionsMode = OPTIONS_MODE_DYNAMIC

  applyAtClose = false
  can_generate_missions = true //FIXME:
  // Remove can_generate_missions parameter and find out how not to generate two map regenerations
  needSlotbar = true

  function initScreen() {
    gui_handlers.GenericOptions.initScreen.bindenv(this)()

    this.guiScene.setUpdatesEnabled(false, false)
    this.init_builder_map()
    this.generate_builder_list(true)

    let options =
    [
      [USEROPT_DYN_MAP, "combobox"],
      [USEROPT_DYN_ZONE, "combobox"],
      [USEROPT_DYN_SURROUND, "spinner"],
      [USEROPT_DMP_MAP, "spinner"],
      [USEROPT_FRIENDLY_SKILL, "spinner"],
      [USEROPT_ENEMY_SKILL, "spinner"],
      [USEROPT_DIFFICULTY, "spinner"],
      [USEROPT_TIME, "spinner"],
      [USEROPT_CLIME, "spinner"],
      [USEROPT_TAKEOFF_MODE, "combobox"],
      [USEROPT_LIMITED_FUEL, "spinner"],
      [USEROPT_LIMITED_AMMO, "spinner"],
    ]

    let container = create_options_container("builder_options", options, true, 0.5, true)
    let optListObj = this.scene.findObject("optionslist")
    this.guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)
    this.optionsContainers.append(container.descr)
    this.setSceneTitle(loc("mainmenu/btnDynamicTraining"), this.scene, "menu-title")

    let desc = ::get_option(USEROPT_DYN_ZONE)
    let dynZoneObj = this.guiScene["dyn_zone"]
    local value = desc.value
    if (checkObj(dynZoneObj))
      value = this.guiScene["dyn_zone"].getValue()

    setSummaryPreview(this.scene.findObject("tactical-map"), DataBlock(), desc.values[value])

    if (::mission_settings.dynlist.len() == 0)
      return this.msgBox("no_missions_error", loc("msgbox/appearError"),
                     [["ok", this.goBack ]], "ok", { cancel_fn = this.goBack })

    this.update_takeoff()

    this.reinitOptionsList()
    this.guiScene.setUpdatesEnabled(true, true)

    if (::fetch_first_builder())
      this.randomize_builder_options()

    if (this.needSlotbar)
      this.createSlotbar()

    move_mouse_on_obj(this.scene.findObject("btn_select"))
  }

  function reinitOptionsList() {
    if (!checkObj(this.scene))
      return this.goBack()

    this.updateButtons()

    let showOptions = this.isBuilderAvailable()

    let optListObj = this.scene.findObject("options_data")
    let textObj = this.scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions ? ""
      : loc(showedUnit.value != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"))

    if (!showOptions)
      return

    this.update_dynamic_map()
  }

  function isBuilderAvailable() {
    return ::isUnitAvailableForGM(showedUnit.value, GM_BUILDER)
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return

    let available = this.isBuilderAvailable()
    this.scene.findObject("btn_select").inactiveColor = available ? "no" : "yes"
    this.showSceneBtn("btn_random", available)
    this.showSceneBtn("btn_inviteSquad", ::enable_coop_in_QMB && ::g_squad_manager.canInviteMember())
  }

  function onApply() {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(GM_BUILDER)
      }))
      return

    if (!this.isBuilderAvailable())
      return this.msgBox("not_available", loc(showedUnit.value != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"),
        [["ok"]], "ok")

    if (isInArray(this.getSceneOptValue(USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!::check_diff_pkg(::g_difficulty.SIMULATOR.diffCode))
        return

    this.applyOptions()
  }

  function getSceneOptRes(optName) {
    let option = ::get_option(optName)
    let obj = this.scene.findObject(option.id)
    local value = obj ? obj.getValue() : -1
    if (!(value in option.items))
      value = option.value
    return { name = option.items[value], value = option.values[value] }
  }

  function init_builder_map() {
    let mapData = this.getSceneOptRes(USEROPT_DYN_MAP)
    ::mission_settings.layout <- mapData.value
    ::mission_settings.layoutName <- mapData.name

    let settings = DataBlock();
    local playerSide = 1
    foreach (tag in (showedUnit.value?.tags ?? []))
      if (tag == "axis") {
        playerSide = 2
        break
      }
    settings.setInt("playerSide", playerSide)
    dynamicInit(settings, mapData.value)
  }

  function generate_builder_list(wait) {
    if (!this.can_generate_missions)
      return
    if (showedUnit.value == null)
      return

    ::aircraft_for_weapons = showedUnit.value.name

    let settings = DataBlock();
    settings.setStr("player_class", showedUnit.value.name)
    settings.setStr("player_weapons", get_gui_option(USEROPT_WEAPONS) ?? "")
    settings.setStr("player_skin", this.getSceneOptValue(USEROPT_SKIN) || "")
    settings.setStr("wishSector", this.getSceneOptValue(USEROPT_DYN_ZONE))
    settings.setInt("sectorSurround", this.getSceneOptValue(USEROPT_DYN_SURROUND))
    settings.setStr("year", "year_any")
    settings.setBool("isQuickMissionBuilder", true)

    ::mission_settings.dynlist <- dynamicGetList(settings, wait)

    let add = []
    for (local i = 0; i < ::mission_settings.dynlist.len(); i++) {
      let misblk = ::mission_settings.dynlist[i].mission_settings.mission

      ::mergeToBlk(::missionBuilderVehicleConfigForBlk, misblk)

      misblk.setStr("mis_file", ::mission_settings.layout)
      misblk.setStr("type", "builder")
      misblk.setStr("chapter", "builder")
      if (::mission_settings.coop)
        misblk.setBool("gt_cooperative", true);
      add.append(misblk)
    }
    ::add_mission_list_full(GM_BUILDER, add, ::mission_settings.dynlist)
  }

  function update_dynamic_map() {
    let descr = ::get_option(USEROPT_DYN_MAP)
    let txt = ::create_option_list(descr.id, descr.items, descr.value, descr.cb, false)
    let dObj = this.scene.findObject(descr.id)
    this.guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    this.init_builder_map()
    if (descr.cb in this)
      this[descr.cb](dObj)
    return descr
  }

  function update_dynamic_layout(guiScene, _obj, _descr) {
    this.init_builder_map()

    let descrWeap = ::get_option(USEROPT_DYN_ZONE)
    let txt = ::create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, "onSectorChange", false)
    let dObj = this.scene.findObject(descrWeap.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
    return descrWeap
  }

  function update_dynamic_sector(guiScene, _obj, _descr) {
    this.generate_builder_list(true)
    let descrWeap = ::get_option(USEROPT_DMP_MAP)
    let txt = ::create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, null, false)
    let dObj = this.scene.findObject(descrWeap.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    this.update_takeoff()

    setSummaryPreview(this.scene.findObject("tactical-map"), DataBlock(), this.getSceneOptValue(USEROPT_DYN_ZONE))

    return descrWeap
  }

  function update_takeoff() {
    local haveTakeOff = false
    let mapObj = this.scene.findObject("dyn_mp_map")
    if (checkObj(mapObj))
      ::mission_settings.currentMissionIdx = mapObj.getValue()

    let dynMission = getTblValue(::mission_settings.currentMissionIdx, ::mission_settings.dynlist)
    if (!dynMission)
      return

    if (dynMission.mission_settings.mission.paramExists("takeoff_mode"))
      haveTakeOff = true

    ::mission_name_for_takeoff = dynMission.mission_settings.mission.name
    let descrWeap = ::get_option(USEROPT_TAKEOFF_MODE)
    if (!haveTakeOff) {
      for (local i = 0; i < descrWeap.items.len(); i++)
        descrWeap.items[i] = { text = descrWeap.items[i], enabled = (i == 0) }
      descrWeap.value = 0
    }
    let txt = ::create_option_combobox(descrWeap.id, descrWeap.items, descrWeap.value, "onMissionChange", false)
    let dObj = this.scene.findObject(descrWeap.id)
    if (checkObj(dObj))
      this.guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
  }

  function setRandomOpt(optName) {
    let desc = ::get_option(optName)
    let obj = this.scene.findObject(desc.id)

    if (desc.values.len() == 0) {
      let settings = toString({                      // warning disable: -declared-never-used
        DYN_MAP = this.getSceneOptValue(USEROPT_DYN_MAP),
        DYN_ZONE = this.getSceneOptValue(USEROPT_DYN_ZONE),
        DYN_SURROUND = this.getSceneOptValue(USEROPT_DYN_SURROUND),
        DMP_MAP = this.getSceneOptValue(USEROPT_DMP_MAP),
        FRIENDLY_SKILL = this.getSceneOptValue(USEROPT_FRIENDLY_SKILL),
        ENEMY_SKILL = this.getSceneOptValue(USEROPT_ENEMY_SKILL),
        DIFFICULTY = this.getSceneOptValue(USEROPT_DIFFICULTY),
        TIME = this.getSceneOptValue(USEROPT_TIME),
        WEATHER = this.getSceneOptValue(USEROPT_CLIME),
        TAKEOFF_MODE = this.getSceneOptValue(USEROPT_TAKEOFF_MODE),
        LIMITED_FUEL = this.scene.findObject(::get_option(USEROPT_LIMITED_FUEL)?.id ?? "").getValue(),
        LIMITED_AMMO = this.scene.findObject(::get_option(USEROPT_LIMITED_AMMO)?.id ?? "").getValue()
      })
      let currentUnit = showedUnit.value?.name         // warning disable: -declared-never-used
      let slotbarUnit = getCurSlotbarUnit()?.name // warning disable: -declared-never-used
      let optId = desc.id                              // warning disable: -declared-never-used
      let values = toString(desc.values)             // warning disable: -declared-never-used
      script_net_assert_once("MissionBuilder", "ERROR: Empty value in options.")
      return
    }

    if (obj)
      obj.setValue(rnd() % desc.values.len())
  }

  function randomize_builder_options() {
    if (!checkObj(this.scene))
      return

    this.can_generate_missions = false
    this.guiScene.setUpdatesEnabled(false, false)

    this.setRandomOpt(USEROPT_DYN_MAP)
    this.onLayoutChange(this.scene.findObject("dyn_map"))

    this.guiScene.performDelayed(this, function() {
        if (!this.isValid())
          return

        this.setRandomOpt(USEROPT_DYN_ZONE)
        this.onSectorChange(this.scene.findObject("dyn_zone"))

        this.guiScene.performDelayed(this, function() {
            if (!this.isValid())
              return

            foreach (o in [USEROPT_TIME, USEROPT_CLIME, USEROPT_DYN_SURROUND])
              this.setRandomOpt(o)

            this.guiScene.performDelayed(this, function() {
                if (!this.isValid())
                  return

                this.setRandomOpt(USEROPT_DMP_MAP)

                this.can_generate_missions = true
                this.guiScene.setUpdatesEnabled(true, true)

                this.update_takeoff()
              }
            )
          }
        )
      }
    )
  }

  function applyFunc() {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(GM_BUILDER)
      }))
      return

    ::mission_settings.currentMissionIdx = this.scene.findObject("dyn_mp_map").getValue()
    let fullMissionBlk = getTblValue(::mission_settings.currentMissionIdx, ::mission_settings.dynlist)
    if (!fullMissionBlk)
      return

    if (fullMissionBlk.mission_settings.mission.paramExists("takeoff_mode")) {
      let takeoff_mode = this.scene.findObject("takeoff_mode").getValue()
      let land_mode = takeoff_mode
      dynamicSetTakeoffMode(fullMissionBlk, takeoff_mode, land_mode)
    }

    let settings = DataBlock()
    settings.setInt("allyCount",  this.getSceneOptValue(USEROPT_DYN_ALLIES))
    settings.setInt("enemyCount", this.getSceneOptValue(USEROPT_DYN_ENEMIES))
    settings.setInt("allySkill",  this.getSceneOptValue(USEROPT_FRIENDLY_SKILL))
    settings.setInt("enemySkill", this.getSceneOptValue(USEROPT_ENEMY_SKILL))
    settings.setStr("dayTime",    this.getSceneOptValue(USEROPT_TIME))
    settings.setStr("weather",    this.getSceneOptValue(USEROPT_CLIME))

    ::mission_settings.coop = (::enable_coop_in_QMB && ::g_squad_manager.isInSquad())
    ::mission_settings.friendOnly = false
    ::mission_settings.allowJIP = true

    dynamicTune(settings, fullMissionBlk)

    let missionBlk = fullMissionBlk.mission_settings.mission

    missionBlk.setInt("_gameMode", GM_BUILDER)
    missionBlk.setBool("gt_cooperative", ::mission_settings.coop)
    if (::mission_settings.coop) {
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

    missionBlk.setStr("difficulty", this.getSceneOptValue(USEROPT_DIFFICULTY))
    missionBlk.setStr("restoreType", "attempts")

    missionBlk.setBool("isLimitedFuel", ::get_option(USEROPT_LIMITED_FUEL).value)
    missionBlk.setBool("isLimitedAmmo", ::get_option(USEROPT_LIMITED_AMMO).value)

    ::current_campaign_mission = missionBlk.getStr("name", "")
    ::mission_settings.mission = missionBlk
    ::mission_settings.missionFull = fullMissionBlk
    select_mission_full(missionBlk, fullMissionBlk);

    //dlog("missionBlk:"); debugTableData(missionBlk)

    ::gui_start_builder_tuner()
  }

  function onLayoutChange(obj) {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.updateOptionDescr(obj, this.update_dynamic_layout)
      this.updateOptionDescr(obj, this.update_dynamic_sector)
    })
  }

  function onMissionChange(_obj) {
    this.update_takeoff()
  }

  function onSectorChange(obj) {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.updateOptionDescr(obj, this.update_dynamic_sector)
    })
  }

  function onYearChange(obj) {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.updateOptionDescr(obj, this.update_dynamic_sector)
    })
  }

  function onRandom(_obj) {
    this.randomize_builder_options()
  }

  function getCurrentEdiff() {
    let diffValue = this.getSceneOptValue(USEROPT_DIFFICULTY)
    let difficulty = (diffValue == "custom") ?
      ::g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()) :
      ::g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1) {
      let battleType = ::get_battle_type_by_unit(showedUnit.value)
      return difficulty.getEdiff(battleType)
    }
    return ::get_current_ediff()
  }

  function getHandlerRestoreData() {
    return {
      openData = { needSlotbar = this.needSlotbar }
    }
  }

  function onEventBeforeStartMissionBuilder(_p) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  onEventShowedUnitChanged = @(_p) this.reinitOptionsList()
}