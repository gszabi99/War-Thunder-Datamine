import "DataBlock" as DataBlock
from "%scripts/missions/missionsStates.nut" import currentCampaignMission, set_mission_for_takeoff, get_mission_settings, get_mutable_mission_settings, set_mission_settings
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/missionBuilder/missionBuilderTuner.nut" import MissionBuilderTuner
from "%scripts/mainmenu/mainMenuHandler.nut" import MainMenu
from "%scripts/genericOptions.nut" import GenericOptions, GenericOptionsModal
from "%scripts/slotbar/playerCurUnit.nut" import showedUnit
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_obj
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/missions/dynCampaingState.nut" import dynamicInitAsync
from "%scripts/missions/mapPreview.nut" import setSummaryPreview
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_DYNAMIC, USEROPT_DYN_MAP, USEROPT_DYN_ZONE, USEROPT_DYN_SURROUND, USEROPT_DMP_MAP, USEROPT_FRIENDLY_SKILL, USEROPT_ENEMY_SKILL
  , USEROPT_DIFFICULTY, USEROPT_TIME, USEROPT_CLIME, USEROPT_TAKEOFF_MODE, USEROPT_LIMITED_FUEL, USEROPT_LIMITED_AMMO, USEROPT_WEAPONS
  , USEROPT_SKIN, USEROPT_DYN_ALLIES, USEROPT_DYN_ENEMIES
from "%scripts/options/optionsExt.nut" import create_options_container, get_option
from "%scripts/slotbar/slotbarState.nut" import getCurSlotbarUnit
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%scripts/unit/unitInfo.nut" import getBattleTypeByUnit
from "%scripts/weaponry/unitForWeapons.nut" import unitNameForWeapons
from "%scripts/unit/unitInSlotbarStatus.nut" import isUnitAvailableForGM
from "%scripts/missions/missionsUtils.nut" import addMissionListFull, getMaxPlayersForGamemode
from "%scripts/clientState/contentPacks.nut" import checkDiffPkg
from "%scripts/squads/squadUtils.nut" import canJoinFlightMsgBox
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "dagor.random" import rnd
from "guiOptions" import get_gui_option, getCdBaseDifficulty
from "dynamicMission" import dynamicGetList, dynamicTune, dynamicSetTakeoffMode
from "guiMission" import select_mission_full
from "%scripts/dagui_natives.nut" import fetch_first_builder
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_combobox, create_option_list

let { g_difficulty } = require("%scripts/difficulty.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { missionBuilderVehicleConfigForBlk } = require("%scripts/missionBuilder/testFlightState.nut")

function mergeToBlk(sourceTable, blk) {
  foreach (idx, val in sourceTable)
    blk[idx] = val
}

register_gui_handler("MissionBuilder", class (GenericOptionsModal) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "%gui/navBuilderOptions.blk"
  wndGameMode = GM_BUILDER
  wndOptionsMode = OPTIONS_MODE_DYNAMIC

  applyAtClose = false
  isInRandomizeOptionsProcess = false
  needSlotbar = true

  function initScreen() {
    GenericOptions.initScreen.bindenv(this)()

    this.guiScene.setUpdatesEnabled(false, false)
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

    if (this.needSlotbar)
      this.createSlotbar()

    this.guiScene.setUpdatesEnabled(true, true)

    if (fetch_first_builder())
      this.randomize_builder_options()
    else
      this.reinitOptionsList()

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
      : loc(showedUnit.get() != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"))

    if (!showOptions)
      return

    this.update_dynamic_map()
  }

  function isBuilderAvailable() {
    return isUnitAvailableForGM(showedUnit.get(), GM_BUILDER)
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return

    let available = this.isBuilderAvailable()
    this.scene.findObject("btn_select").inactiveColor = available ? "no" : "yes"
    showObjById("btn_random", available, this.scene)
  }

  function onApply() {
    if (!canJoinFlightMsgBox({
        maxSquadSize = getMaxPlayersForGamemode(GM_BUILDER)
      }))
      return

    if (!this.isBuilderAvailable())
      return this.msgBox("not_available", loc(showedUnit.get() != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"),
        [["ok"]], "ok")

    if (isInArray(this.getSceneOptValue(USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!checkDiffPkg(g_difficulty.SIMULATOR.diffCode))
        return

    this.applyOptions()
  }

  function getSceneOptRes(optName) {
    let option = get_option(optName)
    let obj = this.scene.findObject(option.id)
    local value = obj ? obj.getValue() : -1
    if (!(value in option.items))
      value = option.value
    return { name = option.items[value], value = option.values[value] }
  }

  function init_builder_map() {
    let mapData = this.getSceneOptRes(USEROPT_DYN_MAP)
    set_mission_settings("layout", mapData.value)
    set_mission_settings("layoutName", mapData.name)

    let settings = DataBlock();
    local playerSide = 1
    foreach (tag in (showedUnit.get()?.tags ?? []))
      if (tag == "axis") {
        playerSide = 2
        break
      }
    settings.setInt("playerSide", playerSide)
    dynamicInitAsync(settings, mapData.value)
  }

  function generate_builder_list(wait) {
    if (showedUnit.get() == null)
      return

    unitNameForWeapons.set(showedUnit.get().name)

    let settings = DataBlock();
    settings.setStr("player_class", showedUnit.get().name)
    settings.setStr("player_weapons", get_gui_option(USEROPT_WEAPONS) ?? "")
    settings.setStr("player_skin", this.getSceneOptValue(USEROPT_SKIN) ?? "")
    settings.setStr("wishSector", this.getSceneOptValue(USEROPT_DYN_ZONE))
    settings.setInt("sectorSurround", this.getSceneOptValue(USEROPT_DYN_SURROUND))
    settings.setStr("year", "year_any")
    settings.setBool("isQuickMissionBuilder", true)

    set_mission_settings("dynlist", dynamicGetList(settings, wait))

    let add = []
    foreach (mis in get_mutable_mission_settings().dynlist) {
      let misblk = mis.mission_settings.mission

      mergeToBlk(missionBuilderVehicleConfigForBlk, misblk)

      misblk.setStr("mis_file", get_mission_settings().layout)
      misblk.setStr("type", "builder")
      misblk.setStr("chapter", "builder")
      if (get_mission_settings().coop)
        misblk.setBool("gt_cooperative", true);
      add.append(misblk)
    }
    addMissionListFull(GM_BUILDER, add, get_mutable_mission_settings().dynlist)
  }

  function update_dynamic_map() {
    let descr = get_option(USEROPT_DYN_MAP)
    let dObj = this.scene.findObject(descr.id)
    if (!dObj?.isValid())
      return
    let txt = create_option_list(descr.id, descr.items, descr.value, descr.cb, false)
    this.guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
    this.onLayoutChange()
  }

  function update_dynamic_layout(guiScene, _obj, _descr) {
    let descrWeap = get_option(USEROPT_DYN_ZONE)
    let txt = create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, "onSectorChange", false)
    let dObj = this.scene.findObject(descrWeap.id)
    if (dObj?.isValid())
      guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
    return descrWeap
  }

  function update_dynamic_sector(guiScene, _obj, _descr) {
    this.generate_builder_list(true)
    let descrWeap = get_option(USEROPT_DMP_MAP)
    let txt = create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, null, false)
    let dObj = this.scene.findObject(descrWeap.id)
    if (dObj?.isValid())
      guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    this.update_takeoff()

    setSummaryPreview(this.scene.findObject("tactical-map"), DataBlock(), this.getSceneOptValue(USEROPT_DYN_ZONE))

    return descrWeap
  }

  function update_takeoff() {
    local haveTakeOff = false
    let mapObj = this.scene.findObject("dyn_mp_map")
    if (checkObj(mapObj))
      set_mission_settings("currentMissionIdx", mapObj.getValue())

    let dynMission = get_mutable_mission_settings().dynlist?[get_mission_settings().currentMissionIdx]
    if (!dynMission)
      return

    if (dynMission.mission_settings.mission.paramExists("takeoff_mode"))
      haveTakeOff = true

    set_mission_for_takeoff(dynMission.mission_settings.mission.name)
    let descrWeap = get_option(USEROPT_TAKEOFF_MODE)
    if (!haveTakeOff) {
      for (local i = 0; i < descrWeap.items.len(); i++)
        descrWeap.items[i] = { text = descrWeap.items[i], enabled = (i == 0) }
      descrWeap.value = 0
    }
    let txt = create_option_combobox(descrWeap.id, descrWeap.items, descrWeap.value, "onMissionChange", false)
    let dObj = this.scene.findObject(descrWeap.id)
    if (checkObj(dObj))
      this.guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
  }

  function getRandomizableOpt(optName) {
    let desc = get_option(optName)
    let obj = this.scene.findObject(desc.id)

    if (desc.values.len() == 0) {
      let settings = toString({
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
        LIMITED_FUEL = this.scene.findObject(get_option(USEROPT_LIMITED_FUEL)?.id ?? "").getValue(),
        LIMITED_AMMO = this.scene.findObject(get_option(USEROPT_LIMITED_AMMO)?.id ?? "").getValue()
      })
      let currentUnit = showedUnit.get()?.name
      let slotbarUnit = getCurSlotbarUnit()?.name
      let optId = desc.id
      let values = toString(desc.values)
      script_net_assert_once("MissionBuilder",
        $"ERROR: Empty value in options. /*settings = {settings}, currentUnit = {currentUnit}, slotbarUnit = {slotbarUnit}, optId = {optId}, values = {values}*/")
      return null
    }

    return obj?.isValid() ? { desc, obj } : null
  }

  function setRandomOpt(optName) {
    let opt = this.getRandomizableOpt(optName)
    if (opt == null)
      return false
    let { desc, obj } = opt
    let newValue = rnd() % desc.values.len()
    if (newValue == desc.value)
      return false
    obj.setValue(newValue)
    return true
  }

  function setRandomOptSilently(optName) {
    let opt = this.getRandomizableOpt(optName)
    if (opt == null)
      return
    let { desc, obj } = opt
    
    let txt = create_option_list(desc.id, desc.items, rnd() % desc.values.len(), desc.cb, false)
    this.guiScene.replaceContentFromText(obj, txt, txt.len(), this)
  }

  function randomize_builder_options() {
    if (!checkObj(this.scene))
      return

    this.isInRandomizeOptionsProcess = true

    let hasChaged = this.setRandomOpt(USEROPT_DYN_MAP)
    if (!hasChaged)
      this.onLayoutChange()
  }

  function applyFunc(_) {
    if (!canJoinFlightMsgBox({
        maxSquadSize = getMaxPlayersForGamemode(GM_BUILDER)
      }))
      return

    set_mission_settings("currentMissionIdx", this.scene.findObject("dyn_mp_map").getValue())
    let fullMissionBlk = get_mutable_mission_settings().dynlist?[get_mission_settings().currentMissionIdx]
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

    set_mission_settings("coop", false)
    set_mission_settings("friendOnly", false)
    set_mission_settings("allowJIP",  true)

    dynamicTune(settings, fullMissionBlk)

    let missionBlk = fullMissionBlk.mission_settings.mission

    missionBlk.setInt("_gameMode", GM_BUILDER)
    missionBlk.setBool("gt_cooperative", get_mission_settings().coop)
    if (get_mission_settings().coop) {
      set_mission_settings("players", 4)
      missionBlk.setInt("_players", 4)
      missionBlk.setInt("maxPlayers", 4)
      missionBlk.setBool("gt_use_lb", false)
      missionBlk.setBool("gt_use_replay", true)
      missionBlk.setBool("gt_use_stats", true)
      missionBlk.setBool("gt_sp_restart", false)
      missionBlk.setBool("isBotsAllowed", true)
      missionBlk.setBool("autoBalance", false)
      missionBlk.setBool("isPrivate", get_mission_settings().friendOnly)
      missionBlk.setBool("allowJIP", ! get_mission_settings().friendOnly)
    }

    missionBlk.setStr("difficulty", this.getSceneOptValue(USEROPT_DIFFICULTY))
    missionBlk.setStr("restoreType", "attempts")

    missionBlk.setBool("isLimitedFuel", get_option(USEROPT_LIMITED_FUEL).value)
    missionBlk.setBool("isLimitedAmmo", get_option(USEROPT_LIMITED_AMMO).value)

    currentCampaignMission.set(missionBlk.getStr("name", ""))
    set_mission_settings("mission", missionBlk)
    set_mission_settings("missionFull", fullMissionBlk)
    select_mission_full(missionBlk, fullMissionBlk);

    

    loadHandler(MissionBuilderTuner)
  }

  function onLayoutChange(_obj = null) {
    this.init_builder_map()
  }

  function onEventDynamicCampaignInited(_) {
    let obj = this.scene.findObject("dyn_map")
    this.updateOptionDescr(obj, this.update_dynamic_layout)
    let needRandomize = this.isInRandomizeOptionsProcess
    this.isInRandomizeOptionsProcess = false
    if (needRandomize) {
      let optionsRebuildingMissionList = [ USEROPT_DYN_ZONE, USEROPT_DYN_SURROUND ]
      foreach (o in optionsRebuildingMissionList)
        this.setRandomOptSilently(o)
    }
    this.updateOptionDescr(obj, this.update_dynamic_sector)
    if (needRandomize)
      foreach (o in [USEROPT_TIME, USEROPT_CLIME, USEROPT_DMP_MAP])
        this.setRandomOpt(o)
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
    if (this.isInRandomizeOptionsProcess)
      return
    this.randomize_builder_options()
  }

  function getCurrentEdiff() {
    let diffValue = this.getSceneOptValue(USEROPT_DIFFICULTY)
    let difficulty = (diffValue == "custom") ?
      g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()) :
      g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1) {
      let battleType = getBattleTypeByUnit(showedUnit.get())
      return difficulty.getEdiff(battleType)
    }
    return getCurrentGameModeEdiff()
  }

  function getHandlerRestoreData() {
    return {
      openData = { needSlotbar = this.needSlotbar }
    }
  }

  function onEventBeforeStartMissionBuilder(_p) {
    handlersManager.requestHandlerRestore(this, MainMenu)
  }

  onEventShowedUnitChanged = @(_p) this.reinitOptionsList()
})