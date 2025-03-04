from "%scripts/dagui_natives.nut" import hangar_show_external_dm_parts_change
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/rawShortcuts.nut" import GAMEPAD_ENTER_SHORTCUT

let { S_UNDEFINED, S_AIRCRAFT, S_HELICOPTER, S_TANK, S_SHIP, S_BOAT,
  getPartType, getPartNameLocText
} = require("%globalScripts/modeXrayLib.nut")
let { get_difficulty_by_ediff } = require("%scripts/difficulty.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let DataBlock = require("DataBlock")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { abs, round, sin, PI } = require("math")
let { hangar_get_current_unit_name, hangar_set_dm_viewer_mode, DM_VIEWER_NONE, DM_VIEWER_ARMOR, DM_VIEWER_XRAY,
  hangar_get_dm_viewer_parts_count, set_xray_parts_filter } = require("hangar")
let { blkOptFromPath, eachParam } = require("%sqstd/datablock.nut")
let { getParametersByCrewId } = require("%scripts/crew/crewSkillParameters.nut")
let { getWeaponXrayDescText } = require("%scripts/weaponry/weaponryDescription.nut")
let { KGF_TO_NEWTON, isCaliberCannon, getCommonWeapons, getLastPrimaryWeapon,
  getPrimaryWeaponsList, getWeaponNameByBlkPath, getTurretGuidanceSpeedMultByDiff
} = require("%scripts/weaponry/weaponryInfo.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { doesLocTextExist } = require("dagor.localize")
let { hasLoadedModel } = require("%scripts/hangarModelLoadManager.nut")
let { unique } = require("%sqstd/underscore.nut")
let { fileName } = require("%sqstd/path.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { TIME_DAY_IN_SECONDS } = require("%scripts/time.nut")
let { startsWith, utf8ToLower, cutPrefix } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { check_unit_mods_update } = require("%scripts/unit/unitChecks.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { get_game_params_blk, get_wpcost_blk, get_unittags_blk, get_modifications_blk } = require("blkGetters")
let { round_by_value } = require("%sqstd/math.nut")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { isStatsLoaded, isMeNewbieOnUnitType } = require("%scripts/myStats.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { measureType } = require("%scripts/measureType.nut")
let { eventbus_subscribe } = require("eventbus")
let { get_option, set_option } = require("%scripts/options/optionsExt.nut")
let { USEROPT_XRAY_FILTER_TANK, USEROPT_XRAY_FILTER_SHIP
} = require("%scripts/options/optionsExtNames.nut")
let { openPopupFilter, RESET_ID } = require("%scripts/popups/popupFilterWidget.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { skillParametersRequestType } = require("%scripts/crew/skillParametersRequestType.nut")
let { isModAvailableOrFree } = require("%scripts/weaponry/modificationInfo.nut")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { gui_modal_tutor } = require("%scripts/guiTutorial.nut")
let { getSimpleUnitType } = require("modeXrayUtils.nut")

/*
  dmViewer API:

  toggle(state = null)  - switch view_mode to state. if state == null view_mode will be increased by 1
  update()              - update dm viewer active status
                          depend on canShowDmViewer function in cur_base_gui_handler and topMenuHandler
                          and modal windows.
*/

let countMeasure = require("%scripts/options/optionsMeasureUnits.nut").countMeasure

const XRAY_FILTER_OBJ_PREFIX = "xray_filter_"

local compareWeaponFunc = @(w1, w2) u.isEqual(w1?.trigger ?? "", w2?.trigger ?? "")
  && u.isEqual(w1?.blk ?? "", w2?.blk ?? "")
  && u.isEqual(w1?.bullets ?? "", w2?.bullets ?? "")
  && u.isEqual(w1?.gunDm ?? "", w2?.gunDm ?? "")
  && u.isEqual(w1?.barrelDP ?? "", w2?.barrelDP ?? "")
  && u.isEqual(w1?.breechDP ?? "", w2?.breechDP ?? "")
  && u.isEqual(w1?.ammoDP ?? "", w2?.ammoDP ?? "")
  && u.isEqual(w1?.dm ?? "", w2?.dm ?? "")
  && u.isEqual(w1?.turret?.head ?? "", w2?.turret?.head ?? "")
  && u.isEqual(w1?.flash ?? "", w2?.flash ?? "")
  && u.isEqual(w1?.emitter ?? "", w2?.emitter ?? "")

const AFTERBURNER_CHAMBER = 3

const MAX_VIEW_MODE_TUTOR_SHOWS = 2

let extHintIconByPartType = {
  ammo_turret = "#ui/gameuiskin#icon_weapons_relocation_in_progress.svg"
  bridge = "#ui/gameuiskin#ship_crew_driver.svg"
  engine = "#ui/gameuiskin#engine_state_indicator.svg"
  engine_room = "#ui/gameuiskin#engine_state_indicator.svg"
  shaft = "#ui/gameuiskin#ship_transmission_state_indicator.svg"
  transmission = "#ui/gameuiskin#ship_transmission_state_indicator.svg"
  steering_gear = "#ui/gameuiskin#ship_steering_gear_state_indicator.svg"
  ammunition_storage = "#ui/gameuiskin#ship_ammo_wetting"
  ammunition_storage_shells = "#ui/gameuiskin#ship_ammo_wetting"
  ammunition_storage_charges = "#ui/gameuiskin#ship_ammo_wetting"
  ammunition_storage_aux = "#ui/gameuiskin#ship_ammo_wetting"
}

let extHintLocKeyByType = {
  shaft = "xray_ext_hint/shaft"
  ammo_turret = "xray_ext_hint/ammo_turret"
  pump = "xray_ext_hint/pump"
  bridge = "xray_ext_hint/bridge"
  radio_station = "xray_ext_hint/radio_station"
  fire_control_room = "xray_ext_hint/fire_control_room"
  aircraft = "xray_ext_hint/aircraft"
  engine_room = "xray_ext_hint/engine_room"
  transmission = "xray_ext_hint/transmission"
  funnel = "xray_ext_hint/funnel"
  steering_gear = "xray_ext_hint/steering_gear"
  fuel_tank = "xray_ext_hint/fuel_tank"
  coal_bunker = "xray_ext_hint/coal_bunker"
  mine = "xray_ext_hint/mine"
  depth_charge = "xray_ext_hint/depth_charge"
  elevator = "xray_ext_hint/elevator"
  tt = "xray_ext_hint/tt"
  antenna_target_location = "xray_ext_hint/antenna_target_location"
  ammunition_storage = "xray_ext_hint/ammunition_storage"
  antenna_target_tagging = "xray_ext_hint/antenna_target_tagging"
  fire_director = "xray_ext_hint/fire_director"
  rangefinder = "xray_ext_hint/rangefinder"
  catapult = "xray_ext_hint/catapult"
  main_caliber_turret = "xray_ext_hint/turret"
  auxiliary_caliber_turret = "xray_ext_hint/turret"
  aa_turret = "xray_ext_hint/turret"
  engine = "xray_ext_hint/engine_room"
  catapult_mount = "xray_ext_hint/catapult"
  ammunition_storage_shells = "xray_ext_hint/ammunition_storage"
  ammunition_storage_charges = "xray_ext_hint/ammunition_storage"
  ammunition_storage_aux = "xray_ext_hint/ammunition_storage"
  antenna_target_tagging_mount = "xray_ext_hint/antenna_target_tagging"
  fire_director_mount = "xray_ext_hint/fire_director"
  rangefinder_mount = "xray_ext_hint/rangefinder"
}

let tankCrewMemberToRole = {
  commander = "commander"
  driver = "driver"
  gunner = "tank_gunner"
  loader = "loader"
  machine_gunner = "radio_gunner"
}

let shipAmmunitionPartsIds = {
  elevator = true
  ammo_turret = true
  ammo_body = true
  ammunition_storage = true
  ammunition_storage_shells = true
  ammunition_storage_charges = true
  ammunition_storage_aux = true
}

let sensorsPartsIds = {
  radar = true
  antenna_target_location = true
  antenna_target_tagging = true
  antenna_target_tagging_mount = true
  optic_gun = true
}

let weaponPartsIds = {
  main_caliber_turret = true
  auxiliary_caliber_turret = true
  aa_turret = true
  mg = true
  gun = true
  mgun = true
  cannon = true
  mask = true
  gun_mask = true
  gun_barrel = true
  cannon_breech = true
  tt = true
  torpedo = true
  main_caliber_gun = true
  auxiliary_caliber_gun = true
  depth_charge = true
  mine = true
  aa_gun = true
}

let armorPartsIds = {
  firewall_armor = true
  composite_armor_hull = true
  composite_armor_turret = true
  ex_era_hull = true
  ex_era_turret = true
}

let avionicsPartsIds = {
  electronic_block = true
  optic_block = true
  cockpit_countrol = true
  ircm = true
}

eventbus_subscribe("on_check_protection", @(p) broadcastEvent("ProtectionAnalysisResult", p))

function isViewModeTutorAvailableForUser() {
  if (!isStatsLoaded())
    return false

  local res = loadLocalAccountSettings("tutor/dmViewer/isAvailable")
  if (res == null) {
    res = isMeNewbieOnUnitType(ES_UNIT_TYPE_SHIP)
    saveLocalAccountSettings("tutor/dmViewer/isAvailable", res)
  }
  return res
}

function distanceToStr(val) {
  return measureType.DISTANCE.getMeasureUnitsText(val)
}

function getRadarSensorType(sensorPropsBlk) {
  local isRadar = false
  local isIrst = false
  local isTv = false
  let transiversBlk = sensorPropsBlk.getBlockByName("transivers")
  for (local t = 0; t < (transiversBlk?.blockCount() ?? 0); t++) {
    let transiverBlk = transiversBlk.getBlock(t)
    let targetSignatureType = transiverBlk?.targetSignatureType ?? transiverBlk?.visibilityType
    if (targetSignatureType == "infraRed")
      isIrst = true
    else if (targetSignatureType == "optic")
      isTv = true
    else
      isRadar = true
  }
  return isRadar && isIrst ? "radar_irst"
    : isRadar ? "radar"
    : isIrst ? "irst"
    : isTv ? "tv"
    : "radar"
}

function getXrayFilterOption() {
  let unitName = hangar_get_current_unit_name()
  let unit = getAircraftByName(unitName)
  if (unit == null)
    return null

  if (unit.isTank())
    return get_option(USEROPT_XRAY_FILTER_TANK, { unitName })

  if (unit.isShipOrBoat())
    return get_option(USEROPT_XRAY_FILTER_SHIP, { unitName })

  return null
}

function getXrayFilterList() {
  let xrayFilterOption = getXrayFilterOption()
  if (xrayFilterOption == null)
    return []
  let res = []
  let value = xrayFilterOption.value
  foreach (idx, item in xrayFilterOption.items)
    res.append({
      id = $"{XRAY_FILTER_OBJ_PREFIX}{idx}"
      text = item
      value = (xrayFilterOption.values[idx] & value) != 0
    })
  return [{ checkbox = res }]
}

function applyXrayFilter(objId, _tName, value) {
  let xrayFilterOption = getXrayFilterOption()
  let optionId = xrayFilterOption.type
  if (objId == RESET_ID) {
    set_option(optionId, 0, xrayFilterOption)
    return
  }
  let idx = cutPrefix(objId, XRAY_FILTER_OBJ_PREFIX).tointeger()
  let optionValue = value ? (xrayFilterOption.value | xrayFilterOption.values[idx])
    : (xrayFilterOption.value & ~xrayFilterOption.values[idx])
  set_option(optionId, optionValue, xrayFilterOption)
}

local dmViewer
dmViewer = {
  active = false
  // This is saved view mode. It is used to restore
  // view mode after player returns from somewhere.
  view_mode = DM_VIEWER_NONE
  unit = null
  simUnitType = S_UNDEFINED
  maxValuesParams = null
  crew = null
  unitBlk = null
  unitWeaponBlkList = null
  unitSensorsBlkList = null
  xrayRemap = {}
  difficulty = null

  modes = {
    [DM_VIEWER_NONE]  = "none",
    [DM_VIEWER_ARMOR] = "armor",
    [DM_VIEWER_XRAY]  = "xray",
  }

  isVisibleExternalPartsArmor = true

  prevHintParams = {}

  screen = [ 0, 0 ]
  unsafe = [ 0, 0 ]
  offset = [ 0, 0 ]

  absoluteArmorThreshold = 500
  relativeArmorThreshold = 5.0

  showStellEquivForArmorClassesList = []
  armorClassToSteel = null

  xrayDescriptionCache = {}
  isDebugMode = false
  isDebugBatchExportProcess = false
  isSecondaryModsValid = false

  _currentViewMode = DM_VIEWER_NONE
  function getCurrentViewMode() { return this._currentViewMode }
  function setCurrentViewMode(value) {
    this._currentViewMode = value
    hangar_set_dm_viewer_mode(value)
    this.updateNoPartsNotification()
  }

  function init(handler) {
    this.screen = [ screen_width(), screen_height() ]
    this.unsafe = [ handler.guiScene.calcString("@bw", null), handler.guiScene.calcString("@bh", null) ]
    this.offset = [ this.screen[1] * 0.1, 0 ]

    let cfgBlk = GUI.get()?.xray
    this.absoluteArmorThreshold = cfgBlk?.armor_thickness_absolute_threshold ?? this.absoluteArmorThreshold
    this.relativeArmorThreshold = cfgBlk?.armor_thickness_relative_threshold ?? this.relativeArmorThreshold
    this.showStellEquivForArmorClassesList = (cfgBlk?.show_steel_thickness_equivalent_for_armor_class
      ?? DataBlock()) % "o"

    this.updateUnitInfo()
    let timerObj = handler.getObj("dmviewer_hint")
    if (timerObj)
      timerObj.setUserData(handler) //!!FIX ME: it a bad idea link timer to handler.
                                    //better to link all timers here, and switch them off when not active.

    this.update()
  }

  function updateSecondaryMods() {
    if (this.isDebugBatchExportProcess) {
      this.isSecondaryModsValid = true
      return
    }

    if (! this.unit)
      return
    this.isSecondaryModsValid = check_unit_mods_update(this.unit)
            && ::check_secondary_weapon_mods_recount(this.unit)
  }

  function onEventSecondWeaponModsUpdated(params) {
    if (! this.unit || this.unit.name != params?.unit.name)
      return
    this.isSecondaryModsValid = true
    this.resetXrayCache()
    this.prevHintParams = {}
    this.reinit()
  }

  function resetXrayCache() {
    this.xrayDescriptionCache.clear()
  }

  function canUse() {
    let hangarUnitName = hangar_get_current_unit_name()
    let hangarUnit = getAircraftByName(hangarUnitName)
    return hasFeature("DamageModelViewer") && hangarUnit
  }

  function reinit() {
    if (!isLoggedIn.get())
      return

    this.updateUnitInfo()
    this.update()
  }

  function updateUnitInfo(forcedUnitId = null) {
    let unitId = forcedUnitId ?? hangar_get_current_unit_name()
    if (this.unit && unitId == this.unit.name)
      return
    this.unit = getAircraftByName(unitId)
    if (! this.unit)
      return
    this.simUnitType = getSimpleUnitType(this.unit)
    this.maxValuesParams = skillParametersRequestType.MAX_VALUES.getParameters(-1, this.unit)
    this.crew = getCrewByAir(this.unit)
    this.loadUnitBlk()
    let map = getTblValue("xray", this.unitBlk)
    this.xrayRemap = map ? map.map(@(val) val) : {}
    this.armorClassToSteel = this.collectArmorClassToSteelMuls()
    this.resetXrayCache()
    this.clearHint()
    this.difficulty = get_difficulty_by_ediff(getCurrentGameModeEdiff())
    this.updateSecondaryMods()
  }

  function updateNoPartsNotification() {
    let isShow = hasLoadedModel()
      && this.getCurrentViewMode() == DM_VIEWER_ARMOR && hangar_get_dm_viewer_parts_count() == 0
    let handler = handlersManager.getActiveBaseHandler()
    if (!handler || !checkObj(handler.scene))
      return
    let obj = handler.scene.findObject("unit_has_no_armoring")
    if (!checkObj(obj))
      return
    obj.show(isShow)
    this.clearHint()
  }

  function loadUnitBlk() {
    // Unit weapons and sensors are part of unit blk, should be unloaded togeter with unitBlk
    this.clearCachedUnitBlkNodes()
    this.unitBlk = getFullUnitBlk(this.unit.name)
  }

  function getUnitWeaponList() {
    if (this.unitWeaponBlkList == null)
      this.recacheWeapons()
    return this.unitWeaponBlkList
  }

  function recacheWeapons() {
    this.unitWeaponBlkList = []
    if (! this.unitBlk)
      return

    let primaryList = [ getLastPrimaryWeapon(this.unit) ]
    foreach (modName in getPrimaryWeaponsList(this.unit))
      u.appendOnce(modName, primaryList)

    foreach (modName in primaryList)
      foreach (weapon in getCommonWeapons(this.unitBlk, modName))
        if (weapon?.blk && !weapon?.dummy)
          u.appendOnce(weapon, this.unitWeaponBlkList, false, compareWeaponFunc)

    let weapons = getUnitWeapons(this.unitBlk)
    foreach (weap in weapons)
      if (weap?.blk && !weap?.dummy)
        u.appendOnce(u.copy(weap), this.unitWeaponBlkList, false, compareWeaponFunc)
  }

  function getUnitSensorsList() {
    if (this.unitSensorsBlkList == null) {
      local sensorsBlk = this.findAnyModEffectValue("sensors")
      let isMod = sensorsBlk != null
      sensorsBlk = sensorsBlk ?? this.unitBlk?.sensors

      this.unitSensorsBlkList = []
      for (local b = 0; b < (sensorsBlk?.blockCount() ?? 0); b++)
        this.unitSensorsBlkList.append(sensorsBlk.getBlock(b))

      if (this.isDebugBatchExportProcess && isMod && this.unitBlk?.sensors != null)
        for (local b = 0; b < this.unitBlk.sensors.blockCount(); b++)
          u.appendOnce(this.unitBlk.sensors.getBlock(b), this.unitSensorsBlkList, false, u.isEqual)

      if (this.unitBlk?.WeaponSlots)
        foreach (slotBlk in this.unitBlk.WeaponSlots % "WeaponSlot")
          foreach (slotPresetBlk in (slotBlk % "WeaponPreset"))
            if (slotPresetBlk?.sensors && slotPresetBlk?.reqModification && isModAvailableOrFree(this.unit.name, slotPresetBlk.reqModification))
              for (local b = 0; b < slotPresetBlk.sensors.blockCount(); b++)
                u.appendOnce(slotPresetBlk.sensors.getBlock(b), this.unitSensorsBlkList, false, u.isEqual)
    }
    return this.unitSensorsBlkList
  }

  function collectArmorClassToSteelMuls() {
    let res = {}
    let armorClassesBlk = blkOptFromPath("gameData/damage_model/armor_classes.blk")
    let steelArmorQuality = armorClassesBlk?.ship_structural_steel.armorQuality ?? 0
    if (this.unitBlk?.DamageParts == null || steelArmorQuality == 0)
      return res
    for (local i = 0; i < this.unitBlk.DamageParts.blockCount(); i++) {
      let blk = this.unitBlk.DamageParts.getBlock(i)
      if (this.showStellEquivForArmorClassesList.contains(blk?.armorClass) && res?[blk.armorClass] == null)
        res[blk.armorClass] <- (armorClassesBlk?[blk.armorClass].armorQuality ?? 0) / steelArmorQuality
    }
    return res
  }

  function toggle(state = null) {
    if (state == this.view_mode)
      return

    this.view_mode =
      (state == null) ? ((this.view_mode + 1) % this.modes.len()) :
      (state in this.modes) ? state :
      DM_VIEWER_NONE

    //need to update active status before repaint
    if (!this.update() && this.active)
      this.show()
    if (!this.active || this.view_mode == DM_VIEWER_NONE)
      this.clearHint()
  }

  function show(vis = true) {
    this.active = vis
    let viewMode = (this.active && this.canUse()) ? this.view_mode : DM_VIEWER_NONE
    this.setCurrentViewMode(viewMode)
    if (!this.active)
      this.clearHint()
    this.repaint()
  }

  function update() {
    this.updateNoPartsNotification()

    local newActive = this.canUse() && !handlersManager.isAnyModalHandlerActive()
    if (!newActive && !this.active) //no need to check other conditions when not canUse and not active.
      return false

    let handler = handlersManager.getActiveBaseHandler()
    newActive = newActive && (handler?.canShowDmViewer() ?? false)
    if (topMenuHandler.value?.isSceneActive() ?? false)
      newActive = newActive && topMenuHandler.value.canShowDmViewer()

    if (newActive == this.active) {
      this.repaint()
      return false
    }

    this.show(newActive)
    return true
  }

  function needShowExtHints() {
    return loadLocalAccountSettings("dmViewer/needShowExtHints", true)
  }

  function checkShowViewModeTutor(modeId) {
    if (this.view_mode == modeId)
      return

    if (!this.unit?.isShipOrBoat())
      return

    if (handlersManager.isAnyModalHandlerActive())
      return

    if (!isProfileReceived.get())
      return

    if (!isViewModeTutorAvailableForUser())
      return

    let modeName = this.modes[modeId]
    let dmTutorData = loadLocalAccountSettings("tutor/dmViewer")
    let numShows = dmTutorData?.numShows[modeName] ?? 0
    if (numShows >= MAX_VIEW_MODE_TUTOR_SHOWS)
      return

    let lastSeen = dmTutorData?.lastSeen ?? 0
    if (lastSeen + TIME_DAY_IN_SECONDS > get_charserver_time_sec())
      return

    if (!isStatsLoaded() || isMeNewbieOnUnitType(ES_UNIT_TYPE_SHIP))
      return

    let needHasArmor = modeId == DM_VIEWER_ARMOR
    if (needHasArmor) {
      let hasArmor = get_unittags_blk()?[this.unit.name].Shop.armorThicknessCitadel != null
      if (!hasArmor)
        return
    }

    let handler = handlersManager.getActiveBaseHandler()
    if (!handler?.scene.isValid())
      return

    let listObj = handler.scene.findObject("air_info_dmviewer_listbox")
    if (!listObj?.isValid())
      return

    saveLocalAccountSettings($"tutor/dmViewer/numShows/{modeName}", numShows + 1)
    saveLocalAccountSettings("tutor/dmViewer/lastSeen", get_charserver_time_sec())

    let steps = [{
      obj = listObj.getChild(modeId)
      text = loc($"dm_viewer/tutor/{modeName}")
      actionType = tutorAction.OBJ_CLICK
      shortcut = GAMEPAD_ENTER_SHORTCUT
      cb = @() listObj?.isValid() && listObj.setValue(modeId)
    }]
    gui_modal_tutor(steps, handler, true)
  }

  function repaint() {
    let handler = handlersManager.getActiveBaseHandler()
    if (!handler)
      return

    local obj = showObjById("air_info_dmviewer_listbox", this.canUse(), handler.scene)
    if (!checkObj(obj))
      return

    obj.setValue(this.view_mode)

    // Protection analysis button
    if (hasFeature("DmViewerProtectionAnalysis")) {
      obj = handler.scene.findObject("dmviewer_protection_analysis_btn")
      if (checkObj(obj))
        obj.show(this.view_mode == DM_VIEWER_ARMOR && (this.unit?.unitType.canShowProtectionAnalysis() ?? false))
    }

    let isTankOrShip = this.unit != null && (this.unit.isTank() || this.unit.isShipOrBoat())
    // Outer parts visibility toggle in Armor and Xray modes
    if (hasFeature("DmViewerExternalArmorHiding")) {
      obj = handler.scene.findObject("dmviewer_show_external_dm")
      if (checkObj(obj)) {
        let isShowOption = this.view_mode == DM_VIEWER_ARMOR && isTankOrShip
        obj.show(isShowOption)
        if (isShowOption)
          obj.setValue(this.isVisibleExternalPartsArmor)
      }
    }

    obj = handler.scene.findObject("filter_nest")
    if (obj?.isValid()) {
      let xrayFilterOption = getXrayFilterOption()
      let isShowOption = this.view_mode == DM_VIEWER_XRAY && isTankOrShip
        && (xrayFilterOption?.values.len() ?? 0) > 0
      obj.show(isShowOption)
      if (isShowOption) {
        if (obj.childrenCount() == 0) {
          openPopupFilter({
            scene = obj
            btnTitle = loc("xray_part_filter")
            btnName = ""
            btnWidth = "1@airInfoPanelDmSwitcherWidth"
            popupAlign = "top"
            onChangeFn = applyXrayFilter
            filterTypesFn = getXrayFilterList
          })
        }
        else
          broadcastEvent("UpdateFiltersCount") //update filter count after validate option value
        set_xray_parts_filter(xrayFilterOption.value)
      } else if (this.view_mode == DM_VIEWER_XRAY && hasLoadedModel())
        set_xray_parts_filter(0)
    }

    obj = handler.scene.findObject("dmviewer_show_extended_hints")
    if (obj?.isValid()) {
      let isShowOption = this.view_mode == DM_VIEWER_XRAY && this.unit.isShipOrBoat()
      obj.show(isShowOption)
      if (isShowOption)
        obj.setValue(this.needShowExtHints())
    }

    // Customization navbar button
    obj = handler.scene.findObject("btn_dm_viewer")
    if (!checkObj(obj))
      return

    let modeNameCur  = this.modes[ this.view_mode  ]
    let modeNameNext = this.modes[ (this.view_mode + 1) % this.modes.len() ]

    obj.tooltip = loc($"mainmenu/viewDamageModel/tooltip_{modeNameNext}")
    obj.setValue(loc($"mainmenu/btn_dm_viewer_{modeNameNext}"))

    let objIcon = obj.findObject("btn_dm_viewer_icon")
    if (checkObj(objIcon))
      objIcon["background-image"] = $"#ui/gameuiskin#btn_dm_viewer_{modeNameCur}.svg"
  }

  function clearHint() {
    this.updateHint({ thickness = 0, name = null, posX = 0, posY = 0 })
  }

  function clearCachedUnitBlkNodes() {
    this.unitWeaponBlkList = null
    this.unitSensorsBlkList = null
  }

  function getHintObj() {
    let handler = handlersManager.getActiveBaseHandler()
    if (!handler)
      return null
    let res = handler.scene.findObject("dmviewer_hint")
    return checkObj(res) ? res : null
  }

  function resetPrevHint() {
    this.prevHintParams = {}
  }

  function hasPrevHint() {
    return this.prevHintParams.len() != 0
  }

  function findDmPartAnimationInBlk(partId, blk) {
    if (blk == null)
      return null
    for (local i = 0; i < blk.blockCount(); i++) {
      let xrayDmPartBlk = blk.getBlock(i)
      if (xrayDmPartBlk?.animation && startsWith(partId, xrayDmPartBlk?.name))
        return xrayDmPartBlk.animation
    }
    return null
  }

  function getDmPartAnimationSrc(partId) {
    let foundUnitAnim = this.findDmPartAnimationInBlk(partId, this.unitBlk?.viewer_xray_animations)
    if (foundUnitAnim)
      return foundUnitAnim

    let gameParamsXrayKey = this.unit.isAir() ? "armorPartNamesAir" : "armorPartNamesGround"
    let gameParamsXrayBlk = get_game_params_blk()[gameParamsXrayKey].viewer_xray

    return this.findDmPartAnimationInBlk(partId, gameParamsXrayBlk)
  }

  function updateHint(params) {
    if (!this.active) {
      if (this.hasPrevHint()) {
        this.resetPrevHint()
        let hintObj = this.getHintObj()
        if (hintObj)
          hintObj.show(false)
      }
      return
    }

    local needUpdatePos = false
    local needUpdateContent = false

    if (this.view_mode == DM_VIEWER_XRAY)
      // change tooltip info only for new unit part
      needUpdateContent = (getTblValue("name", params, true) != getTblValue("name", this.prevHintParams, false))
    else
      foreach (key, val in params)
        if (val != getTblValue(key, this.prevHintParams)) {
          if (key == "posX" || key == "posY")
            needUpdatePos = true
          else
            needUpdateContent = true
        }

    if (!needUpdatePos && !needUpdateContent)
      return
    this.prevHintParams = params

    let obj = this.getHintObj()
    if (!obj)
      return
    if (needUpdatePos && !needUpdateContent)
      return this.placeHint(obj)

    let name = params?.name ?? ""
    let nameId = this.view_mode == DM_VIEWER_XRAY ? getPartType(name, this.xrayRemap) : name

    let isVisible = nameId != ""
    obj.show(isVisible)
    if (!isVisible)
      return

    let handler = handlersManager.getActiveBaseHandler()
    local info = { title = "", desc = [] }
    let isUseCache = this.view_mode == DM_VIEWER_XRAY && !this.isDebugMode
    let cacheId = getTblValue("name", params, "")

    if (isUseCache && (cacheId in this.xrayDescriptionCache))
      info = this.xrayDescriptionCache[cacheId]
    else {
      info = this.getPartTooltipInfo(nameId, params)
      info.title = info.title.replace(" ", nbsp)

      if (isUseCache)
        this.xrayDescriptionCache[cacheId] <- info
    }

    obj.findObject("dmviewer_title").setValue(info.title)
    let descObj = obj.findObject("dmviewer_desc")
    if (info.desc != null) {
      let items = info.desc.map(@(v) "value" in v ? v : { value = v })
      let data = handyman.renderCached("%gui/dmViewer/dmViewerHintDescItem.tpl", { items })
      handler.guiScene.replaceContentFromText(descObj, data, data.len(), handler)

      obj.findObject("topValueHint").show(info.desc.findindex(@(v) "topValue" in v) != null)
    }
    showObjById("dmviewer_anim", !!info.animation, handler.scene)["movie-load"] = info.animation

    let needShowExtHint = info.extDesc != ""
    let extHintObj = obj.findObject("dmviewer_ext_hint")
    extHintObj.show(needShowExtHint)
    if (needShowExtHint) {
      handler.guiScene.applyPendingChanges(false)
      extHintObj.width = max(extHintObj.getSize()[0], descObj.getSize()[0])
      obj.findObject("dmviewer_ext_hint_desc").setValue(info.extDesc)
      obj.findObject("dmviewer_ext_hint_icon")["background-image"] = info.extIcon
      obj.findObject("dmviewer_ext_hint_shortcut").setValue(info.extShortcut)
    }

    this.placeHint(obj)
  }

  function placeHint(obj) {
    if (!checkObj(obj))
      return
    let guiScene = obj.getScene()

    guiScene.setUpdatesEnabled(true, true)
    let cursorPos = get_dagui_mouse_cursor_pos_RC()
    let size = obj.getSize()
    let posX = clamp(cursorPos[0] + this.offset[0], this.unsafe[0], max(this.unsafe[0], this.screen[0] - this.unsafe[0] - size[0]))
    let posY = clamp(cursorPos[1] + this.offset[1], this.unsafe[1], max(this.unsafe[1], this.screen[1] - this.unsafe[1] - size[1]))
    obj.pos = format("%d, %d", posX, posY)
  }

  function getPartLocNameByBlkFile(locKeyPrefix, blkFilePath, blk) {
    let nameLocId = $"{locKeyPrefix}/{blk?.nameLocId ?? fileName(blkFilePath).slice(0, -4)}"
    return doesLocTextExist(nameLocId) ? loc(nameLocId) : (blk?.name ?? nameLocId)
  }

  function getPartTooltipInfo(nameId, params) {
    let res = {
      title       = ""
      desc        = []
      extDesc     = ""
      extIcon     = ""
      extShortcut = ""
      animation   = null
    }

    if (nameId == "")
      return res

    let { overrideTitle = "", hideDescription = false } = this.unitBlk?.xrayOverride[params.name]

    params.nameId <- nameId
    if (this.view_mode == DM_VIEWER_ARMOR)
      res.desc = this.getDescriptionInArmorMode(params)
    else if (this.view_mode == DM_VIEWER_XRAY) {
      if (!hideDescription)
        res.desc = this.getDescriptionInXrayMode(params)
      res.animation = this.getDmPartAnimationSrc(params.name)
      res.__update(this.getExtendedHintInfo(params))
    }

    let titleLocId = overrideTitle != "" ? overrideTitle : (params?.partLocId ?? nameId)
    res.title = getPartNameLocText(titleLocId, this.simUnitType)

    return res
  }

  function getExtendedHintInfo(params) {
    if (!this.unit?.isShipOrBoat() || !this.unitBlk)
      return {}

    if (!this.needShowExtHints())
      return {}

    if (!hasFeature("XRayDescription") || !params?.name)
      return {}

    let partType = params?.nameId ?? ""
    let partName = params.name

    let extDescLocKey = this.getExtHintLocKey(partType, partName)

    return {
      extDesc = loc(extDescLocKey)
      extShortcut = loc($"{extDescLocKey}/shortcut", "")
      extIcon = extHintIconByPartType?[partType] ?? ""
    }
  }

  function isStockTorpedo(partName) {
    let ammoCount = this.unitBlk?.ammoStowages.blockCount() ?? 0
    for (local i = 0; i < ammoCount; ++i) {
      let ammo = this.unitBlk.ammoStowages.getBlock(i)
      if (ammo?.entityMunition != "torpedo") // skipping blocks without torpedos
        continue

      foreach (shells in (ammo % "shells"))
        for (local j = 0; j < shells.blockCount(); ++j)
          if (partName == shells.getBlock(j).getBlockName())
            return shells?.isStock ?? false
    }
    return false
  }

  function getExtHintLocKey(partType, partName) {
    if (partType == "torpedo")
      return this.isStockTorpedo(partName) ? $"xray_ext_hint/{partType}" : ""
    return extHintLocKeyByType?[partType] ?? ""
  }

  function getDescriptionInArmorMode(params) {
    let desc = []

    let solid = getTblValue("solid", params)
    let variableThickness = getTblValue("variable_thickness", params)
    let thickness = getTblValue("thickness", params)
    let effectiveThickness = getTblValue("effective_thickness", params)

    if (solid && variableThickness) {
      desc.append(loc("armor_class/variable_thickness_armor"))
    }
    else if (thickness) {
      let thicknessStr = thickness.tostring()
      desc.append("".concat(loc("armor_class/thickness"), nbsp,
        colorize("activeTextColor", thicknessStr), nbsp, loc("measureUnits/mm")))
    }

    let normalAngleValue = getTblValue("normal_angle", params, null)
    if (normalAngleValue != null)
      desc.append("".concat(loc("armor_class/normal_angle"), nbsp,
        (normalAngleValue + 0.5).tointeger(), nbsp, loc("measureUnits/deg")))

    let angleValue = getTblValue("angle", params, null)
    if (angleValue != null)
      desc.append("".concat(loc("armor_class/impact_angle"), nbsp, round(angleValue), nbsp, loc("measureUnits/deg")))

    if (effectiveThickness) {
      if (solid) {
        desc.append("".concat(loc("armor_class/armor_dimensions_at_point"), nbsp,
          colorize("activeTextColor", round(effectiveThickness)),
          nbsp, loc("measureUnits/mm")))

        if ((this.armorClassToSteel?[params.name] ?? 0) != 0) {
          let equivSteelMm = round(effectiveThickness * this.armorClassToSteel[params.name])
          desc.append(loc("shop/armorThicknessEquivalent/steel",
            { thickness = "".concat(colorize("activeTextColor", equivSteelMm), " ", loc("measureUnits/mm")) }))
        }
      }
      else {
        let effectiveThicknessClamped = min(effectiveThickness,
          min((this.relativeArmorThreshold * thickness).tointeger(), this.absoluteArmorThreshold))

        desc.append("".concat(loc("armor_class/effective_thickness"), nbsp,
          (effectiveThicknessClamped < effectiveThickness ? ">" : ""),
          round(effectiveThicknessClamped), nbsp, loc("measureUnits/mm")))
      }
    }

    if (this.isDebugMode)
      desc.append("".concat("\n", colorize("badTextColor", params.nameId)))

    let rawPartName = getTblValue("raw_name", params)
    if (rawPartName)
      desc.append(rawPartName)

    return desc
  }

  function getFirstFound(dataArray, getter, defValue = null) {
    local result = null
    foreach (data in dataArray) {
      result = getter(data)
      if (result != null)
        break
    }
    return result ?? defValue
  }

  function getCrewMemberBlkByDMPart(crewBlk, dmPart) {
    let l = crewBlk.blockCount()
    for (local i = 0; i < l; i++) {
      let memberBlk = crewBlk.getBlock(i)
      if (dmPart == memberBlk.dmPart)
        return memberBlk
    }
    return null
  }

  function findBlockByName(blk, name) {
    if (blk.getBlockByName(name) != null)
      return true
    for (local b = 0; b < blk.blockCount(); b++)
      if (this.findBlockByName(blk.getBlock(b), name))
        return true
    return false
  }

  function findBlockByNameWithParamValue(blk, blockName, paramName, paramValue) {
    for (local b = 0; b < blk.blockCount(); b++) {
      let block = blk.getBlock(b)
      if (block.getBlockName() == blockName)
        if (block?[paramName] == paramValue)
          return true
    }
    for (local b = 0; b < blk.blockCount(); b++)
      if (this.findBlockByNameWithParamValue(blk.getBlock(b), blockName, paramName, paramValue))
        return true
    return false
  }

  function addRwrDescription(sensorPropsBlk, indent, desc) {
    local bandsIndexes = []
    for (local band = 0; band < 16; ++band)
      if (sensorPropsBlk.getBool(format("band%d", band), false))
        bandsIndexes.append(band)

    local bands = "".concat(indent, loc("radar_freq_band"), loc("ui/colon"))
    if (bandsIndexes.len() > 1) {
      local bandStart = null
      for (local i = 0; i < bandsIndexes.len(); ++i) {
        let band = bandsIndexes[i]
        if (bandStart == null)
          bandStart = band
        else {
          let bandPrev = bandsIndexes[i - 1]
          if (band > bandPrev + 1) {
            if (bandPrev > bandStart)
              bands = "".concat(bands, loc(format("radar_freq_band_%d", bandStart)), "-",
                loc(format("radar_freq_band_%d", bandPrev)), ", ")
            else
              bands = "".concat(bands, loc(format("radar_freq_band_%d", bandStart)), ", ")
            bandStart = band
          }
        }
      }
      let bandLast = bandsIndexes[bandsIndexes.len() - 1]
      if (bandLast > bandStart)
        bands = "".concat(bands, loc(format("radar_freq_band_%d", bandStart)), "-",
          loc(format("radar_freq_band_%d", bandLast)), " ")
      else
        bands = "".concat(bands, loc(format("radar_freq_band_%d", bandStart)), " ")
    }
    else
      bands = "".concat(bands, loc(format("radar_freq_band_%d", bandsIndexes[0])))
    desc.append(bands)

    let rangeMax = sensorPropsBlk.getReal("range", 0.0)
    desc.append("".concat(indent, loc("radar_range_max"), loc("ui/colon"), distanceToStr(rangeMax)))

    local targetsDirectionGroups = {}
    let targetsDirectionGroupsBlk = sensorPropsBlk.getBlockByName("targetsDirectionGroups")
    for (local d = 0; d < (targetsDirectionGroupsBlk?.blockCount() ?? 0); d++) {
      let targetsDirectionGroupBlk = targetsDirectionGroupsBlk.getBlock(d)
      let targetsDirectionGroupText = targetsDirectionGroupBlk.getStr("text", "")
      if (!targetsDirectionGroups?[targetsDirectionGroupText])
        targetsDirectionGroups[targetsDirectionGroupText] <- true
    }
    if (targetsDirectionGroups.len() > 1)
      desc.append("".concat(indent, loc("rwr_scope_id_threats_types"), loc("ui/colon"), format("%d", targetsDirectionGroups.len())))

    let targetsPresenceGroupsBlk = sensorPropsBlk.getBlockByName("targetsPresenceGroups")
    let targetsPresenceGroupsCount = targetsPresenceGroupsBlk?.blockCount() ?? 0
    if (targetsPresenceGroupsCount > 1)
      desc.append("".concat(indent, loc("rwr_present_id_threats_types"), loc("ui/colon"), format("%d", targetsPresenceGroupsCount)))

    if (sensorPropsBlk.getBool("targetTracking", false))
      desc.append("".concat(indent, loc("rwr_tracked_threats_max"), loc("ui/colon"), format("%d", sensorPropsBlk.getInt("trackedTargetsMax", 16))))

    if (sensorPropsBlk.getBool("detectTracking", true))
      desc.append("".concat(indent, loc("rwr_tracking_detection")))

    let detectLaunch = sensorPropsBlk.getBool("detectLaunch", false)
    local launchingThreatTypes = {}

    if (!detectLaunch) {
      local groupsMap = {}
      let groupsBlk = sensorPropsBlk.getBlockByName("groups")
      for (local g = 0; g < (groupsBlk?.blockCount() ?? 0); g++) {
        let groupBlk = groupsBlk.getBlock(g)
        groupsMap[groupBlk.getStr("name", "")] <- groupBlk
      }

      for (local d = 0; d < (targetsDirectionGroupsBlk?.blockCount() ?? 0); d++) {
        let targetsDirectionGroupBlk = targetsDirectionGroupsBlk.getBlock(d)
        let targetsDirectionGroupText = targetsDirectionGroupBlk.getStr("text", "")
        for (local g = 0; g < targetsDirectionGroupBlk.paramCount(); ++g)
          if (targetsDirectionGroupBlk.getParamName(g) == "group") {
            let groupName = targetsDirectionGroupBlk.getParamValue(g)
            if (groupsMap?[groupName]?.getBool("detectLaunch", false) ?? false)
              if (!launchingThreatTypes?[targetsDirectionGroupText]) {
                launchingThreatTypes[targetsDirectionGroupText] <- true
                break
              }
          }
      }

      for (local p = 0; p < (targetsPresenceGroupsBlk?.blockCount() ?? 0); p++) {
        let targetsPresenceGroupBlk = targetsPresenceGroupsBlk.getBlock(p)
        let targetsPresenceGroupText = targetsPresenceGroupBlk.getStr("text", "")
        for (local g = 0; g < targetsPresenceGroupBlk.paramCount(); ++g)
          if (targetsPresenceGroupBlk.getParamName(g) == "group") {
            let groupName = targetsPresenceGroupBlk.getParamValue(g)
            if (groupsMap?[groupName]?.getBool("detectLaunch", false) ?? false)
              if (!launchingThreatTypes?[targetsPresenceGroupText]) {
                launchingThreatTypes[targetsPresenceGroupText] <- true
                break
              }
          }
      }
    }

    if (detectLaunch)
      desc.append("".concat(indent, loc("rwr_launch_detection")))
    else if (launchingThreatTypes.len() > 1)
      desc.append("".concat(indent, loc("rwr_launch_detection"), loc("ui/colon"), format("%d", launchingThreatTypes.len())))

    local rangeFinder = false
    foreach (rangeFinderParamName in ["targetRangeFinder", "searchRangeFinder", "trackRangeFinder", "launchRangeFinder"])
      if (sensorPropsBlk.getBool(rangeFinderParamName, false)) {
        rangeFinder = true
        break
      }
    if (rangeFinder)
      desc.append("".concat(indent, loc("rwr_signal_strength")))

    if (sensorPropsBlk.getBool("friendFoeId", false))
      desc.append("".concat(indent, loc("rwr_iff")))
  }

  function addRadarDescription(sensorPropsBlk, indent, desc) {

    local isRadar = false
    local isIrst = false
    local isTv = false
    local rangeMax = 0.0
    local radarFreqBand = 8
    local searchZoneAzimuthWidth = 0.0
    local searchZoneElevationWidth = 0.0
    let transiversBlk = sensorPropsBlk.getBlockByName("transivers")
    for (local t = 0; t < (transiversBlk?.blockCount() ?? 0); t++) {
      let transiverBlk = transiversBlk.getBlock(t)
      let range = transiverBlk.getReal("range", 0.0)
      rangeMax = max(rangeMax, range)
      let targetSignatureType = transiverBlk?.targetSignatureType != null ? transiverBlk?.targetSignatureType : transiverBlk?.visibilityType
      if (targetSignatureType == "infraRed")
        isIrst = true
      else if (targetSignatureType == "optic")
        isTv = true
      else {
        isRadar = true
        radarFreqBand = transiverBlk.getInt("band", 8)
      }
      if (transiverBlk?.antenna != null) {
        if (transiverBlk.antenna?.azimuth != null && transiverBlk.antenna?.elevation != null) {
          let azimuthWidth = 2.0 * (transiverBlk.antenna.azimuth?.angleHalfSens ?? 0.0)
          let elevationWidth = 2.0 * (transiverBlk.antenna.elevation?.angleHalfSens ?? 0.0)
          searchZoneAzimuthWidth = max(searchZoneAzimuthWidth, azimuthWidth)
          searchZoneElevationWidth = max(searchZoneElevationWidth, elevationWidth)
        }
        else {
          let width = 2.0 * (transiverBlk.antenna?.angleHalfSens ?? 0.0)
          searchZoneAzimuthWidth = max(searchZoneAzimuthWidth, width)
          searchZoneElevationWidth = max(searchZoneElevationWidth, width)
        }
      }
    }

    let isSearchRadar = this.findBlockByName(sensorPropsBlk, "addTarget")

    local anglesFinder = false
    local iff = false
    local lookUp = false
    local lookDownHeadOn = false
    local lookDownHeadOnVelocity = false
    local lookDownAllAspects = false
    let signalsBlk = sensorPropsBlk.getBlockByName("signals")
    for (local s = 0; s < (signalsBlk?.blockCount() ?? 0); s++) {
      let signalBlk = signalsBlk.getBlock(s)
      if (isSearchRadar && signalBlk.getBool("track", false))
        continue
      anglesFinder = anglesFinder || signalBlk.getBool("anglesFinder", true)
      iff = iff || signalBlk.getBool("friendFoeId", false)
      let groundClutter = signalBlk.getBool("groundClutter", false)
      let distanceBlk = signalBlk.getBlockByName("distance")
      let dopplerSpeedBlk = signalBlk.getBlockByName("dopplerSpeed")
      if (dopplerSpeedBlk && dopplerSpeedBlk.getBool("presents", false)) {
        let dopplerSpeedMin = dopplerSpeedBlk.getReal("minValue", 0.0)
        let dopplerSpeedMax = dopplerSpeedBlk.getReal("maxValue", 0.0)
        if (( signalBlk.getBool("mainBeamDopplerSpeed", false) &&
              !signalBlk.getBool("absDopplerSpeed", false) &&
              dopplerSpeedMax > 0.0 && (dopplerSpeedMin > 0.0 || dopplerSpeedMax > -dopplerSpeedMin * 0.25)) ||
             groundClutter) {
          if (!signalBlk.getBool("rangeFinder", true) && signalBlk.getBool("dopplerSpeedFinder", false) )
            lookDownHeadOnVelocity = true
          else
            lookDownHeadOn = true
        }
        else
          lookDownAllAspects = true
      }
      else if (distanceBlk && distanceBlk.getBool("presents", false))
        lookUp = true
    }

    let hasTws = this.findBlockByName(sensorPropsBlk, "updateTargetOfInterest")
    let hasTwsPlus = this.findBlockByName(sensorPropsBlk, "matchTargetsOfInterest")
    let hasTwsEsa = this.findBlockByName(sensorPropsBlk, "addTargetTrack")
    let hasRam = this.findBlockByName(sensorPropsBlk, "ram")
    let isTrackRadar = this.findBlockByName(sensorPropsBlk, "updateActiveTargetOfInterest")
    let hasSARH = this.findBlockByName(sensorPropsBlk, "setIllumination")
    let hasMG = this.findBlockByName(sensorPropsBlk, "setWeaponRcTransmissionTimeOut")
    let datalinkChannelsNum = sensorPropsBlk.getInt("weaponTargetsMax", 0)

    local radarType = ""
    if (isRadar)
      radarType = "radar"
    if (isIrst) {
      if (radarType != "")
        radarType =$"{radarType}_"
      radarType =$"{radarType}irst"
    }
    if (isTv) {
      if (radarType != "")
        radarType =$"{radarType}_"
      radarType =$"{radarType}tv"
    }
    if (isSearchRadar && isTrackRadar)
      radarType = $"{radarType}"
    else if (isSearchRadar)
      radarType = $"search_{radarType}"
    else if (isTrackRadar) {
      if (anglesFinder)
        radarType = $"track_{radarType}"
      else
        radarType =$"{radarType}_range_finder"
    }
    desc.append("".concat(indent, loc("plane_engine_type"), loc("ui/colon"), loc(radarType)))
    if (isRadar)
      desc.append("".concat(indent, loc("radar_freq_band"), loc("ui/colon"), loc(format("radar_freq_band_%d", radarFreqBand))))
    desc.append("".concat(indent, loc("radar_range_max"), loc("ui/colon"), distanceToStr(rangeMax)))

    let scanPatternsBlk = sensorPropsBlk.getBlockByName("scanPatterns")
    for (local p = 0; p < (scanPatternsBlk?.blockCount() ?? 0); p++) {
      let scanPatternBlk = scanPatternsBlk.getBlock(p)
      let scanPatternType = scanPatternBlk.getStr("type", "")
      local major = 0.0
      local minor = 0.0
      local rowMajor = true
      if (scanPatternType == "cylinder") {
        major = 360.0
        minor = scanPatternBlk.getReal("barHeight", 0.0) * scanPatternBlk.getInt("barsCount", 0)
        rowMajor = scanPatternBlk.getBool("rowMajor", true)
      }
      else if (scanPatternType == "pyramide") {
        major = 2.0 * scanPatternBlk.getReal("width", 0.0)
        minor = scanPatternBlk.getReal("barHeight", 0.0) * scanPatternBlk.getInt("barsCount", 0)
        rowMajor = scanPatternBlk.getBool("rowMajor", true)
      }
      else if (scanPatternType == "cone") {
        major = 2.0 * scanPatternBlk.getReal("width", 0.0)
        minor = major
      }
      if (major * minor > searchZoneAzimuthWidth * searchZoneElevationWidth) {
        if (rowMajor) {
          searchZoneAzimuthWidth = major
          searchZoneElevationWidth = minor
        }
        else {
          searchZoneAzimuthWidth = minor
          searchZoneElevationWidth = major
        }
      }
    }

    if (isSearchRadar)
      desc.append("".concat(indent, loc("radar_search_zone_max"), loc("ui/colon"),
        round(searchZoneAzimuthWidth), loc("measureUnits/deg"), loc("ui/multiply"),
        round(searchZoneElevationWidth), loc("measureUnits/deg")))

    if (this.unit != null && (this.unit.isTank() || this.unit.isShipOrBoat())) {
      if (lookDownAllAspects)
        desc.append("".concat(indent, loc("radar_ld")))
    }
    else if (lookDownHeadOn || lookDownHeadOnVelocity || lookDownAllAspects) {
      desc.append("".concat(indent, loc("radar_ld"), loc("ui/colon")))
      if (lookDownHeadOn)
        desc.append("".concat(indent, "  ", loc("radar_ld_head_on")))
      if (lookDownHeadOnVelocity)
        desc.append("".concat(indent, "  ", loc("radar_ld_head_on_velocity")))
      if (lookDownAllAspects)
        desc.append("".concat(indent, "  ", loc("radar_ld_all_aspects")))
      if ((lookDownHeadOn || lookDownHeadOnVelocity || lookDownAllAspects) && lookUp)
        desc.append("".concat(indent, loc("radar_lu")))
    }

    if (iff)
      desc.append("".concat(indent, loc("radar_iff")))
    if (isSearchRadar && hasTws)
      desc.append("".concat(indent, loc("radar_tws")))
    if (isSearchRadar && hasTwsPlus)
      desc.append("".concat(indent, loc("radar_tws_plus")))
    if (isSearchRadar && hasTwsEsa)
      desc.append("".concat(indent, loc("radar_tws_esa")))
    if (isSearchRadar && hasRam)
      desc.append("".concat(indent, loc("radar_ram")))
    if (isTrackRadar) {
      let hasBVR = this.findBlockByNameWithParamValue(sensorPropsBlk, "setDistGatePos", "source", "targetDesignation")
      if (hasBVR)
        desc.append("".concat(indent, loc("radar_bvr_mode")))
      let hasACM = this.findBlockByNameWithParamValue(sensorPropsBlk, "setDistGatePos", "source", "constRange")
      if (hasACM)
        desc.append("".concat(indent, loc("radar_acm_mode")))
      let hasHMD = this.findBlockByName(sensorPropsBlk, "designateHelmetTarget")
      if (hasHMD)
        desc.append("".concat(indent, loc("radar_hms_mode")))
      if (hasSARH)
        desc.append("".concat(indent, loc("radar_sarh")))
      if (hasMG)
        desc.append("".concat(indent, loc("radar_mg")))
      if (datalinkChannelsNum > 0)
        desc.append("".concat(indent, loc("radar_dl_channels"), loc("ui/colon"), format("%d", datalinkChannelsNum)))
    }
  }

  function getDescriptionInXrayMode(params) {
    if (!this.unit || !this.unitBlk)
      return ""

    if (!hasFeature("XRayDescription") || !params?.name)
      return ""

    let partId = params?.nameId ?? ""
    let partName = params.name
    local weaponPartName = null
    let desc = []

    if (this.simUnitType == S_TANK && (partId in tankCrewMemberToRole)) {
      if (partId == "gunner")
        params.partLocId <- "gunner_tank"

      let memberBlk = this.getCrewMemberBlkByDMPart(this.unitBlk.tank_crew, partName)
      if (memberBlk != null) {
        let memberRole = tankCrewMemberToRole[partId]
        let duplicateRoles = (memberBlk % "role")
          .filter(@(r) r != memberRole)
          .map(@(r) loc($"duplicate_role/{r}", ""))
          .filter(@(n) n != "")
        desc.extend(duplicateRoles)
      }
    }
    else if (partId == "engine") { // Engines
      if (this.simUnitType == S_TANK) {
        let infoBlk = this.findAnyModEffectValue("engine") ?? this.unitBlk?.VehiclePhys.engine
        if (infoBlk) {
          let engineModelName = this.getEngineModelName(infoBlk)
          desc.append(engineModelName)

          let engineConfig = []
          let engineType = infoBlk?.type ?? (engineModelName != "" ? "diesel" : "")
          if (engineType != "")
            engineConfig.append(loc($"engine_type/{engineType}"))
          if (infoBlk?.configuration)
            engineConfig.append(loc($"engine_configuration/{infoBlk.configuration}"))
          let typeText = loc("ui/comma").join(engineConfig, true)
          if (typeText != "")
            desc.append("".concat(loc("plane_engine_type"), loc("ui/colon"), typeText))

          if (infoBlk?.displacement)
            desc.append("".concat(loc("engine_displacement"), loc("ui/colon"),
              loc("measureUnits/displacement", { num = infoBlk.displacement.tointeger() })))
        }

        if (! this.isSecondaryModsValid)
          this.updateSecondaryMods()

        let currentParams = this.unit?.modificators[this.difficulty.crewSkillName]
        if (this.isSecondaryModsValid && currentParams && currentParams.horsePowers && currentParams.maxHorsePowersRPM) {
          desc.append(format("%s %s (%s %d %s)", "".concat(loc("engine_power"), loc("ui/colon")),
            measureType.HORSEPOWERS.getMeasureUnitsText(currentParams.horsePowers),
            loc("shop/unitValidCondition"), currentParams.maxHorsePowersRPM.tointeger(), loc("measureUnits/rpm")))
        }
        if (infoBlk)
          desc.append(this.getMassInfo(infoBlk))
      }
      else if (this.simUnitType == S_AIRCRAFT || this.simUnitType == S_HELICOPTER) {
        local partIndex = to_integer_safe(this.trimBetween(partName, "engine", "_"), -1, false)
        if (partIndex > 0) {
          let fmBlk = ::get_fm_file(this.unit.name, this.unitBlk)
          if (fmBlk != null) {
            partIndex-- //engine1_dm -> Engine0

            let infoBlk = this.getInfoBlk(partName)
            desc.append(this.getEngineModelName(infoBlk))

            let enginePartId = infoBlk?.part_id ?? ($"Engine{partIndex}")
            let engineTypeId = "".concat("EngineType", (fmBlk?[enginePartId].Type ?? -1).tostring())
            local engineBlk = fmBlk?[engineTypeId] ?? fmBlk?[enginePartId]
            if (!engineBlk) { // try to find booster
              local numEngines = 0
              while (($"Engine{numEngines}") in fmBlk)
                numEngines ++
              let boosterPartIndex = partIndex - numEngines //engine3_dm -> Booster0
              engineBlk = fmBlk?[$"Booster{boosterPartIndex}"]
            }
            let engineMainBlk = engineBlk?.Main

            if (engineMainBlk != null) {
              let engineInfo = []
              local engineType = this.getFirstFound([infoBlk, engineMainBlk], @(b) b?.Type ?? b?.type, "").tolower()
              if (this.simUnitType == S_HELICOPTER && engineType == "turboprop")
                engineType = "turboshaft"
              if (engineType != "")
                engineInfo.append(loc($"plane_engine_type/{engineType}"))
              if (engineType == "inline" || engineType == "radial") {
                let cylinders = this.getFirstFound([infoBlk, engineMainBlk], @(b) b?.Cylinders ?? b?.cylinders, 0)
                if (cylinders > 0)
                  engineInfo.append("".concat(cylinders, loc("engine_cylinders_postfix")))
              }
              let typeText = loc("ui/comma").join(engineInfo, true)
              if (typeText != "")
                desc.append("".concat(loc("plane_engine_type"), loc("ui/colon"), typeText))

              // display cooling type only for Inline and Radial engines
              if ((engineType == "inline" || engineType == "radial")
                  && "IsWaterCooled" in engineMainBlk) {           // Plane : Engine : Cooling
                let coolingKey = engineMainBlk?.IsWaterCooled ? "water" : "air"
                desc.append("".concat(loc("plane_engine_cooling_type"), loc("ui/colon"),
                  loc($"plane_engine_cooling_type_{coolingKey}")))
              }

              if (!this.isSecondaryModsValid) {
                this.updateSecondaryMods()
              }
              else {
                // calculating power values
                local powerMax = 0
                local powerTakeoff = 0
                local thrustMax = 0
                local thrustTakeoff = 0
                local thrustMaxCoef = 1
                local afterburneThrustMaxCoef = 1
                let engineThrustMaxBlk = engineMainBlk?.ThrustMax

                if (engineThrustMaxBlk) {
                  thrustMaxCoef = engineThrustMaxBlk?.ThrustMaxCoeff_0_0 ?? 1
                  afterburneThrustMaxCoef = engineThrustMaxBlk?.ThrAftMaxCoeff_0_0 ?? 1
                }

                let horsePowerValue = this.getFirstFound([infoBlk, engineMainBlk],
                  @(b) b?.ThrustMax?.PowerMax0 ?? b?.HorsePowers ?? b?.Power, 0)
                let thrustValue = this.getFirstFound([infoBlk, engineMainBlk], @(b) b?.ThrustMax?.ThrustMax0, 0)

                local thrustMult = 1.0
                local thrustTakeoffMult = 1.0
                local modeIdx = 0
                while (true) {
                  let modeBlk = engineMainBlk?[$"Mode{++modeIdx}"]
                  if (modeBlk?.ThrustMult == null)
                    break
                  if (modeBlk?.Throttle != null && modeBlk.Throttle <= 1.0)
                    thrustMult = modeBlk.ThrustMult
                  thrustTakeoffMult = modeBlk.ThrustMult
                }

                let throttleBoost = this.getFirstFound([infoBlk, engineMainBlk], @(b) b?.ThrottleBoost, 0)
                let afterburnerBoost = this.getFirstFound([infoBlk, engineMainBlk], @(b) b?.AfterburnerBoost, 0)
                // for planes modifications have delta values
                let thrustModDelta = (this.unit?.modificators[this.difficulty.crewSkillName].thrust ?? 0) / KGF_TO_NEWTON
                let horsepowerModDelta = this.unit?.modificators[this.difficulty.crewSkillName].horsePowers ?? 0
                if (engineType == "inline" || engineType == "radial") {
                  if (throttleBoost > 1) {
                    powerMax = horsePowerValue
                    powerTakeoff = horsePowerValue * throttleBoost * afterburnerBoost
                  }
                  else
                    powerTakeoff = horsePowerValue
                }
                else if (engineType == "rocket") {
                  let sources = [infoBlk, engineMainBlk]
                  let boosterMainBlk = fmBlk?[$"Booster{partIndex}"].Main
                  if (boosterMainBlk)
                    sources.insert(1, boosterMainBlk)
                  thrustTakeoff = this.getFirstFound(sources, @(b) b?.Thrust ?? b?.thrust, 0)
                }
                else if (engineType == "turboprop" || engineType == "turboshaft") {
                  powerMax = horsePowerValue
                  thrustMax = thrustValue * thrustMult
                }
                else {
                  if (throttleBoost > 1 && afterburnerBoost > 1) {
                    thrustTakeoff = thrustValue * thrustTakeoffMult * afterburnerBoost
                    thrustMax = thrustValue * thrustMult
                  }
                  else
                    thrustTakeoff = thrustValue * thrustTakeoffMult
                }

                // final values can be overriden in info block
                powerMax = getTblValue("power_max", infoBlk, powerMax)
                powerTakeoff = getTblValue("power_takeoff", infoBlk, powerTakeoff)
                thrustMax = getTblValue("thrust_max", infoBlk, thrustMax)
                thrustTakeoff = getTblValue("thrust_takeoff", infoBlk, thrustTakeoff)

                // display power values
                if (powerMax > 0) {
                  powerMax += horsepowerModDelta
                  desc.append("".concat(loc("engine_power_max"), loc("ui/colon"),
                    measureType.HORSEPOWERS.getMeasureUnitsText(powerMax)))
                }
                if (powerTakeoff > 0) {
                  powerTakeoff += horsepowerModDelta
                  desc.append("".concat(loc("engine_power_takeoff"), loc("ui/colon"),
                    measureType.HORSEPOWERS.getMeasureUnitsText(powerTakeoff)))
                }
                if (thrustMax > 0) {
                  thrustMax += thrustModDelta
                  thrustMax *= thrustMaxCoef
                  desc.append("".concat(loc("engine_thrust_max"), loc("ui/colon"),
                    measureType.THRUST_KGF.getMeasureUnitsText(thrustMax)))
                }
                if (thrustTakeoff > 0) {
                  let afterburnerBlk = engineBlk?.Afterburner
                  let thrustTakeoffLocId = (afterburnerBlk?.Type == AFTERBURNER_CHAMBER &&
                    (afterburnerBlk?.IsControllable ?? false))
                      ? "engine_thrust_afterburner"
                      : "engine_thrust_takeoff"

                  thrustTakeoff += thrustModDelta
                  thrustTakeoff *= thrustMaxCoef * afterburneThrustMaxCoef
                  desc.append("".concat(loc(thrustTakeoffLocId), loc("ui/colon"),
                    measureType.THRUST_KGF.getMeasureUnitsText(thrustTakeoff)))
                }

                // mass
                desc.append(this.getMassInfo(infoBlk))
              }
            }
          }
        }
      }
    }
    else if (partId == "transmission") {
      let info = this.unitBlk?.VehiclePhys?.mechanics
      if (info) {
        let manufacturer = info?.manufacturer
          ? loc($"transmission_manufacturer/{info.manufacturer}",
            loc($"engine_manufacturer/{info.manufacturer}", ""))
          : ""
        let model = info?.model ? loc($"transmission_model/{info.model}", "") : ""
        let props = info?.type ? utf8ToLower(loc($"transmission_type/{info.type}", "")) : ""
        desc.append("".concat(" ".join([ manufacturer, model ], true),
          props == "" ? "" : loc("ui/parentheses/space", { text = props })))

        let maxSpeed = this.unit?.modificators?[this.difficulty.crewSkillName]?.maxSpeed ?? 0
        if (maxSpeed && info?.gearRatios) {
          local gearsF = 0
          local gearsB = 0
          local ratioF = 0
          local ratioB = 0
          foreach (gear in (info.gearRatios % "ratio")) {
            if (gear > 0) {
              gearsF++
              ratioF = ratioF ? min(ratioF, gear) : gear
            }
            else if (gear < 0) {
              gearsB++
              ratioB = ratioB ? min(ratioB, -gear) : -gear
            }
          }
          let maxSpeedF = maxSpeed
          let maxSpeedB = ratioB ? (maxSpeed * ratioF / ratioB) : 0
          if (maxSpeedF && gearsF)
            desc.append("".concat(loc("xray/transmission/maxSpeed/forward"), loc("ui/colon"),
              countMeasure(0, maxSpeedF), loc("ui/comma"), loc("xray/transmission/gears")
              loc("ui/colon"), gearsF))
          if (maxSpeedB && gearsB)
            desc.append("".concat(loc("xray/transmission/maxSpeed/backward"), loc("ui/colon"),
              countMeasure(0, maxSpeedB), loc("ui/comma"), loc("xray/transmission/gears"),
              loc("ui/colon"), gearsB))
        }
      }
    }
    else if (partId in shipAmmunitionPartsIds) {
      let isShipOrBoat = this.unit.isShipOrBoat()
      let ammoSlotInfo = this.getAmmoStowageSlotInfo(partName)
      if (isShipOrBoat) {
        if (ammoSlotInfo.count > 1)
          desc.append("".concat(loc("shop/ammo"), loc("ui/colon"), ammoSlotInfo.count))
      }
      let stowageInfo = this.getAmmoStowageInfo(null, partName, isShipOrBoat)
      if (stowageInfo.isCharges)
        params.partLocId <- isShipOrBoat ? "ship_charges_storage" : "ammo_charges"
      if (stowageInfo.firstStageCount) {
        local txt = loc(isShipOrBoat ? "xray/ammo/first_stage_ship" : "xray/ammo/first_stage")
        if (this.unit.isTank())
          txt = "".concat(txt, loc("ui/comma"), stowageInfo.firstStageCount, " ", loc("measureUnits/pcs"))
        desc.append(txt)
      }
      if (stowageInfo.isAutoLoad)
        desc.append(loc("xray/ammo/mechanized_ammo_rack"))
      if (ammoSlotInfo.isConstrainedInert)
        desc.append(loc("xray/ammo/constrained_inert"))
    }
    else if (partId == "drive_turret_h" || partId == "drive_turret_v") {
      weaponPartName = partName.replace(partId, "gun_barrel")
      let weaponInfoBlk = this.getWeaponByXrayPartName(weaponPartName, partName)
      if (weaponInfoBlk != null) {
        let isHorizontal = partId == "drive_turret_h"
        desc.extend(this.getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, isHorizontal, !isHorizontal))
      }
    }
    else if (partId == "gunner" && this.simUnitType == S_AIRCRAFT) {
      params.partLocId <- "gunner_aircraft"
    }
    else if (partId == "pilot" || (partId == "gunner" && this.simUnitType == S_HELICOPTER)) {
      foreach (cfg in [
        { label = "avionics_sight_turret", ccipKey = "haveCCIPForTurret", autoKey = "haveCCRPForTurret"  }
        { label = "avionics_sight_cannon", ccipKey = "haveCCIPForGun",    autoKey = "haveCCRPForGun"     }
        { label = "avionics_sight_rocket", ccipKey = "haveCCIPForRocket", autoKey = "haveCCRPForRocket"  }
        { label = "avionics_sight_bomb",   ccipKey = "haveCCIPForBombs",  ccrpKey = "haveCCRPForBombs"   }
      ]) {
        let haveCcip = this.unitBlk?[cfg.ccipKey] ?? false
        let haveAuto = this.unitBlk?[cfg?.autoKey] ?? false
        let haveCcrp = this.unitBlk?[cfg?.ccrpKey] ?? false
        if (haveCcip || haveAuto || haveCcrp)
          desc.append("".concat(loc(cfg.label), loc("ui/colon"),
            loc("ui/comma").join([ haveCcip ? loc("CCIP") : "",
            haveAuto ? loc("sight_AUTO") : "" , haveCcrp ? loc("CCRP") : "" ], true)))
      }

      let nightVisionBlk = this.findAnyModEffectValue("nightVision")
      if (partId == "pilot") {
        if (nightVisionBlk?.pilotIr != null)
          desc.append(loc("modification/night_vision_system"))
      }
      else {
        if (nightVisionBlk?.gunnerIr != null)
          desc.append(loc("modification/night_vision_system"))
      }

      if ((this.unitBlk?.haveOpticTurret || this.simUnitType == S_HELICOPTER) && this.unitBlk?.gunnerOpticFps != null)
        if (this.unitBlk?.cockpit.sightOutFov != null || this.unitBlk?.cockpit.sightInFov != null) {
          let optics = this.getOpticsParams(this.unitBlk?.cockpit.sightOutFov ?? 0, this.unitBlk?.cockpit.sightInFov ?? 0)
          if (optics.zoom != "") {
            let visionModes = loc("ui/comma").join([
              { mode = "tv",   have = nightVisionBlk?.sightIr != null || nightVisionBlk?.sightThermal != null }
              { mode = "lltv", have = nightVisionBlk?.sightIr != null }
              { mode = "flir", have = nightVisionBlk?.sightThermal != null }
            ].map(@(v) v.have ? loc($"avionics_sight_vision/{v.mode}") : ""), true)
            desc.append("".concat(loc("armor_class/optic"), loc("ui/colon"), optics.zoom,
              visionModes != "" ? loc("ui/parentheses/space", { text = visionModes }) : ""))
          }
        }

      foreach (sensorBlk in this.getUnitSensorsList()) {
        let sensorFilePath = sensorBlk.getStr("blk", "")
        if (sensorFilePath == "")
          continue
        let sensorPropsBlk = DataBlock()
        sensorPropsBlk.load(sensorFilePath)
        local sensorType = sensorPropsBlk.getStr("type", "")
        if (sensorType == "radar")
          sensorType = getRadarSensorType(sensorPropsBlk)
        else if (sensorType == "lds")
          continue
        desc.append("".concat(loc($"avionics_sensor_{sensorType}"), loc("ui/colon"),
          this.getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))
        if (sensorType == "rwr")
          this.addRwrDescription(sensorPropsBlk, "  ", desc)
      }

      if (this.unitBlk.getBool("hasHelmetDesignator", false))
        desc.append(loc("avionics_hmd"))
      if (this.unitBlk.getBool("havePointOfInterestDesignator", false) || this.simUnitType == S_HELICOPTER)
        desc.append(loc("avionics_aim_spi"))
      if (this.unitBlk.getBool("laserDesignator", false))
        desc.append(loc("avionics_aim_laser_designator"))

      let slots = this.unitBlk?.WeaponSlots
      if (slots) {
        let commonSlot = (slots % "WeaponSlot")?[0]
        if (commonSlot) {
          let counterMeasures = (commonSlot % "WeaponPreset").findvalue(
            @(v) v?.counterMeasures)?.counterMeasures

          for (local b = 0; b < (counterMeasures?.blockCount() ?? 0); b++) {
            let counterMeasureBlk = counterMeasures.getBlock(b)
            let counterMeasureFilePath = counterMeasureBlk?.blk ?? ""
            if (counterMeasureFilePath == "")
              continue

            let counterMeasurePropsBlk = blkOptFromPath(counterMeasureFilePath)
            let counterMeasureType = counterMeasurePropsBlk?.type ?? ""
            desc.append("".concat(loc($"avionics_countermeasure_{counterMeasureType}"),
              loc("ui/colon"),
              this.getPartLocNameByBlkFile("counterMeasures", counterMeasureFilePath,
                counterMeasurePropsBlk)))
          }
        }
      }
    }
    else if (partId in sensorsPartsIds) {
      foreach (sensorBlk in this.getUnitSensorsList()) {
        if ((sensorBlk % "dmPart").findindex(@(v) v == partName) == null)
          continue

        let sensorFilePath = sensorBlk.getStr("blk", "")
        if (sensorFilePath == "")
          continue
        let sensorPropsBlk = DataBlock()
        sensorPropsBlk.load(sensorFilePath)
        let sensorType = sensorPropsBlk.getStr("type", "")
        if (sensorType == "radar") {
          desc.append("".concat(loc("xray/model"), loc("ui/colon"),
            this.getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))
          // naval params are temporary disabled as they do not match to historical ones
          if (this.unit.isShipOrBoat())
            continue
          this.addRadarDescription(sensorPropsBlk, "", desc)
        }
      }

      if (partId == "optic_gun" && !this.unit.isShipOrBoat()) {
        let info = this.unitBlk?.cockpit
        let cockpitMod = this.findAnyModEffectValue("cockpit");
        if (info?.sightName || cockpitMod?.sightName)
          desc.extend(this.getOpticsDesc(info, cockpitMod))
      }
    }
    else if (partId == "countermeasure") {
      let counterMeasuresBlk = this.unitBlk?.counterMeasures
      if (counterMeasuresBlk) {
        for (local i = 0; i < counterMeasuresBlk.blockCount(); i++) {
          let cmBlk = counterMeasuresBlk.getBlock(i)
          if (cmBlk?.dmPart != partName || (cmBlk?.blk ?? "") == "")
            continue
          let info = DataBlock()
          info.load(cmBlk.blk)

          desc.append("".concat(loc("xray/model"), loc("ui/colon"),
            this.getPartLocNameByBlkFile("counterMeasures", cmBlk.blk, info)))

          foreach (cfg in [
            { label = "xray/ircm_protected_sector/hor",  sectorKey = "azimuthSector",   directionKey = "azimuth"   }
            { label = "xray/ircm_protected_sector/vert", sectorKey = "elevationSector", directionKey = "elevation" }
          ]) {
            let sector = round(info?[cfg.sectorKey] ?? 0.0)
            local direction = round((info?[cfg.directionKey] ?? 0.0) * 2.0) / 2
            if (sector == 0)
              continue
            let deg = loc("measureUnits/deg")
            local comment = ""
            if (direction != 0 && sector < 360) {
              direction %= 360
              if (direction < 0)
                direction += 360
              local angles = [
                direction - sector / 2
                direction + sector / 2
              ].map(function(a) {
                a %= 360
                if (a >= 180)
                  a -= 360
                return "".concat(a >= 0 ? "+" : "", a, deg)
              })
              comment = loc("ui/parentheses/space", { text = "/".join(angles) })
            }
            desc.append("".concat(loc(cfg.label), loc("ui/colon"), sector, deg, comment))
          }
          break
        }
      }
    }
    else if (partId == "aps_sensor") {
      let activeProtectionSystemBlk = this.unitBlk?.ActiveProtectionSystem
      if (activeProtectionSystemBlk)
        desc.extend(this.getAPSDesc(activeProtectionSystemBlk))
    }
    else if (partId == "ex_aps_launcher" || partId == "aps_launcher") {
      let activeProtectionSystemBlk = this.unitBlk?.ActiveProtectionSystem
      if (activeProtectionSystemBlk) {
        for (local i = 0; i < activeProtectionSystemBlk.blockCount(); i++) {
          let moduleBlk = activeProtectionSystemBlk.getBlock(i)
          if (moduleBlk?.launcherDmPart == partName) {
            desc.extend(this.getAPSDesc(moduleBlk))
            break
          }
        }
      }
    }
    else if (partId in weaponPartsIds) {
      let turretWeaponsNames = {}// { 406mm_45_bl_mk1_r1_naval_user_cannon = 2, ... }
      if (partId == "main_caliber_turret" || partId == "auxiliary_caliber_turret" || partId == "aa_turret") {
        weaponPartName = partName.replace("turret", "gun")
        foreach (weapon in this.getUnitWeaponList())
          if (weapon?.turret.gunnerDm == partName && weapon?.breechDP) {
            weaponPartName = weapon.breechDP

            let weaponName = getWeaponNameByBlkPath(weapon?.blk ?? "")
            if (weaponName == "")
              continue
            if (!turretWeaponsNames?[weaponName])
              turretWeaponsNames[weaponName] <- 0
            turretWeaponsNames[weaponName] += 1
          }

        if (turretWeaponsNames.len() > 0) {
          foreach(weaponName, weaponsCount in turretWeaponsNames)
            desc.append("".concat(loc($"weapons/{weaponName}"), format(loc("weapons/counter"), weaponsCount)))
        }
      }
      local weaponInfoBlk = null
      let weaponTrigger = getTblValue("weapon_trigger", params)
      let triggerParam = "trigger"
      if (weaponTrigger) {
        let weaponList = this.getUnitWeaponList()
        foreach (weapon in weaponList) {
          if (triggerParam not in weapon || weapon[triggerParam] != weaponTrigger)
            continue
          if (weapon?.turret.gunnerDm == params.name) {
            weaponInfoBlk = weapon
            break
          }
        }
      }

      if (!weaponInfoBlk) {
        weaponPartName = weaponPartName || partName
        weaponInfoBlk = this.getWeaponByXrayPartName(weaponPartName)
      }

      if (weaponInfoBlk != null) {
        let isSpecialBullet = isInArray(partId, [ "torpedo", "depth_charge", "mine" ])
        let isSpecialBulletEmitter = isInArray(partId, [ "tt" ])

        let weaponBlkLink = weaponInfoBlk?.blk ?? ""
        let weaponName = getWeaponNameByBlkPath(weaponBlkLink)
        let ammo = isSpecialBullet ? 1 : this.getWeaponTotalBulletCount(partId, weaponInfoBlk)
        let shouldShowAmmoInTitle = isSpecialBulletEmitter
        let ammoTxt = ammo > 1 && shouldShowAmmoInTitle ? format(loc("weapons/counter"), ammo) : ""

        if (weaponName != "" && turretWeaponsNames.len() == 0)
          desc.append("".concat(loc($"weapons/{weaponName}"), ammoTxt))
        if (weaponInfoBlk && ammo > 1 && !shouldShowAmmoInTitle)
          desc.append("".concat(loc("shop/ammo"), loc("ui/colon"), ammo))

        if (isSpecialBullet || isSpecialBulletEmitter)
          desc[desc.len() - 1] = "".concat(desc.top(),
            getWeaponXrayDescText(weaponInfoBlk, this.unit, getCurrentGameModeEdiff()))
        else {
          let status = this.getWeaponStatus(weaponPartName, weaponInfoBlk)
          desc.extend(this.getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status))
          desc.append(this.getMassInfo(blkOptFromPath(weaponBlkLink)))
          if (status?.isPrimary || status?.isSecondary) {
            if (weaponInfoBlk?.autoLoader)
              desc.append(loc("xray/ammo/auto_load"))
            let firstStageCount = this.getAmmoStowageInfo(weaponInfoBlk?.trigger).firstStageCount
            if (firstStageCount)
              desc.append("".concat(loc(this.unit.isShipOrBoat() ? "xray/ammo/first_stage_ship" : "xray/ammo/first_stage"),
                loc("ui/colon"), firstStageCount))
          }
          desc.extend(this.getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, true, true))
        }

        this.checkPartLocId(partId, partName, weaponInfoBlk, params)
      }
    }
    else if (partId == "tank") { // aircraft fuel tank (tank's fuel tank is 'fuel_tank')
      local tankInfoTable = this.unit?.info?[params.name]
      if (!tankInfoTable)
        tankInfoTable = this.unit?.info?.tanks_params
      if (tankInfoTable != null) {
        if (tankInfoTable?.manufacturer)
          params.partLocId <- tankInfoTable.manufacturer

        let tankInfo = []
        if ("protected" in tankInfoTable) {
          tankInfo.append(tankInfoTable.protected ?
          loc("fuelTank/selfsealing") :
          loc("fuelTank/not_selfsealing"))
        }
        if ("protected_boost" in tankInfoTable)
          tankInfo.append(loc("fuelTank/neutralGasSystem"))
        if ("filling_polyurethane" in tankInfoTable)
          tankInfo.append(loc("fuelTank/fillingPolyurethane"))
        if (tankInfo.len())
          desc.append(", ".join(tankInfo, true))
      }
    }
    else if (partId in armorPartsIds) {
      let info = this.getModernArmorParamsByDmPartName(partName)

      let strUnits = $"{nbsp}{loc("measureUnits/mm")}"
      let strBullet = loc("ui/bullet")
      let strColon  = loc("ui/colon")

      if (info.titleLoc != "")
        params.partLocId <- info.titleLoc

      foreach (data in info.referenceProtectionArray) {
        if (u.isPoint2(data.angles))
          desc.append(loc("shop/armorThicknessEquivalent/angles",
            { angle1 = abs(data.angles.y), angle2 = abs(data.angles.x) }))
        else
          desc.append(loc("shop/armorThicknessEquivalent"))

        if (data.kineticProtectionEquivalent)
          desc.append("".concat(strBullet, loc("shop/armorThicknessEquivalent/kinetic"), strColon,
            round(data.kineticProtectionEquivalent), strUnits))
        if (data.cumulativeProtectionEquivalent)
          desc.append("".concat(strBullet, loc("shop/armorThicknessEquivalent/cumulative"), strColon,
            round(data.cumulativeProtectionEquivalent), strUnits))
      }

      let blockSep = desc.len() ? "\n" : ""

      if (info.isComposite && !u.isEmpty(info.layersArray)) { // composite armor
        let texts = []
        foreach (layer in info.layersArray) {
          local thicknessText = ""
          if (u.isFloat(layer?.armorThickness) && layer.armorThickness > 0)
            thicknessText = round(layer.armorThickness).tostring()
          else if (u.isPoint2(layer?.armorThickness) && layer.armorThickness.x > 0 && layer.armorThickness.y > 0)
            thicknessText = "".concat(round(layer.armorThickness.x), loc("ui/mdash"),
              round(layer.armorThickness.y))
          if (thicknessText != "")
            thicknessText = loc("ui/parentheses/space", { text = $"{thicknessText}{strUnits}" })
          texts.append("".concat(strBullet, getPartNameLocText(layer?.armorClass, this.simUnitType), thicknessText))
        }
        desc.append("".concat(blockSep, loc("xray/armor_composition"), loc("ui/colon"), "\n", "\n".join(texts, true)))
      }
      else if (!info.isComposite && !u.isEmpty(info.armorClass)) // reactive armor
        desc.append("".concat(blockSep, loc("plane_engine_type"), loc("ui/colon"), getPartNameLocText(info.armorClass, this.simUnitType)))
    }
    else if (partId == "coal_bunker") {
      let coalToSteelMul = this.armorClassToSteel?["ships_coal_bunker"] ?? 0
      if (coalToSteelMul != 0)
        desc.append(loc("shop/armorThicknessEquivalent/coal_bunker",
          { thickness = "".concat(round(coalToSteelMul * 1000).tostring(), " ", loc("measureUnits/mm")) }))
    }
    else if (partId == "commander_panoramic_sight") {
      if (this.unitBlk?.commanderView)
        desc.extend(this.getOpticsDesc(this.unitBlk.commanderView))
   }
   else if (partId == "rangefinder" || partId == "fire_director") {
      // "partName" node may belong to only one system
      let fcBlk = this.getFireControlSystems("dmPart", partName)?[0]
      if (fcBlk != null) {
        // 1. Gives fire solution for
        let weaponNames = this.getFireControlWeaponNames(fcBlk)
        if (weaponNames.len() != 0) {
          desc.append(loc("xray/fire_control/weapons"))
          desc.extend(weaponNames
            .map(@(n) loc($"weapons/{n}"))
            .map(@(n) $"{loc("ui/bullet")}{n}"))

          // 2. Measure accuracy
          let accuracy = this.getFireControlAccuracy(fcBlk)
          if (accuracy != -1)
            desc.append(format("%s %d%s", loc("xray/fire_control/accuracy"),
              accuracy, loc("measureUnits/percent")))

          // 3. Fire solution calculation time
          let lockTime = fcBlk?.targetLockTime
          if (lockTime)
            desc.append(format("%s %d%s", loc("xray/fire_control/lock_time"),
              lockTime, loc("measureUnits/seconds")))

          // 4. Fire solution update time
          let calcTime = fcBlk?.calcTime
          if (calcTime)
            desc.append(format("%s %d%s", loc("xray/fire_control/calc_time"),
              calcTime, loc("measureUnits/seconds")))
        }
      }
    }
    else if (partId == "fire_control_room" || partId == "bridge") {
      let numRangefinders = this.getNumFireControlNodes(partName, "rangefinder")
      let numFireDirectors = this.getNumFireControlNodes(partName, "fire_director")
      if (numRangefinders != 0 || numFireDirectors != 0) {
        desc.append(loc("xray/fire_control/devices"))
        if (numRangefinders > 0)
          desc.append($"{loc("ui/bullet")}{loc("xray/fire_control/num_rangefinders", {n = numRangefinders})}")
        if (numFireDirectors > 0)
          desc.append($"{loc("ui/bullet")}{loc("xray/fire_control/num_fire_directors", {n = numFireDirectors})}")
      }
    }
    else if (partId == "autoloader" || partId == "driver_controls")
      desc.append(loc($"armor_class/desc/{partId}"))
    else if (partId == "power_system") {
      let partsList = [loc("armor_class/fire_control_system"), loc("armor_class/gun_stabilizer"),
        loc("armor_class/radar")]
      desc.append(loc($"armor_class/desc/{partId}", { partsList = "\n".join(partsList, true) }))
    }
    else if (partId == "fire_control_system") {
      let partsList = []
      foreach (weapon in this.getUnitWeaponList()) {
        if (weapon?.stabilizerDmPart == partName) {
          u.appendOnce(loc("armor_class/gun_stabilizer"), partsList)
          continue
        }
        if (weapon?.guidedWeaponControlsDmPart == partName)
          u.appendOnce(loc("armor_class/guided_weapon_controls"), partsList)

        let turretBlk = weapon?.turret
        if (turretBlk == null)
          continue

        eachParam(turretBlk, function(val,key) {
          if (key == "verDriveDm" && val == partName)
            u.appendOnce(loc("armor_class/drive_turret_v"), partsList)
          if (key == "horDriveDm" && val == partName)
            u.appendOnce(loc("armor_class/drive_turret_h"), partsList)
          if (key == "shootingDmPart" && val == partName)
            u.appendOnce(loc("xray/firing"), partsList)
        })
      }

      let rangefinderDmPart = this.findAnyModEffectValue("rangefinderDmPart")
      if (rangefinderDmPart == partName)
        partsList.append(loc("modification/laser_rangefinder_lws"))

      let nightVisionBlk = this.findAnyModEffectValue("nightVision")
      if (nightVisionBlk?.nightVisionDmPart == partName)
        partsList.append(loc("modification/night_vision_system"))

      desc.append(loc($"armor_class/desc/{partId}", { partsList = "\n".join(partsList, true) }))
    }
    else if (partId == "electronic_equipment") {
      let partsList = []
      foreach (sensorBlk in this.getUnitSensorsList()) {
        if ((sensorBlk % "dmPart").findindex(@(v) v == partName) == null)
          continue

        let sensorFilePath = sensorBlk.getStr("blk", "")
        if (sensorFilePath == "")
          continue
        let sensorPropsBlk = DataBlock()
        sensorPropsBlk.load(sensorFilePath)
        local sensorType = sensorPropsBlk.getStr("type", "")
        if (sensorType == "radar")
          sensorType = getRadarSensorType(sensorPropsBlk)
        else if (sensorType == "lds")
          continue
        partsList.append("".concat(loc($"avionics_sensor_{sensorType}"), loc("ui/colon"),
          this.getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))
      }
      desc.append(loc($"armor_class/desc/{partId}", { partsList = "\n".join(partsList, true) }))
    }
    else if (partId in avionicsPartsIds) {
      desc.append(loc($"armor_class/desc/{partId}"))
      let damagePartsToAvionicsPartsMap = this.unitBlk?.damagePartsToAvionicsPartsMap
      let avionicsParts = damagePartsToAvionicsPartsMap == null ? [] : (damagePartsToAvionicsPartsMap % "avionics")
      let parts = []
      foreach (part in avionicsParts)
        if (part.health.dm == partName)
          parts.append(loc($"xray/{part.avionics}"))

      desc.append("\n".join(parts, true))
    }

    if (this.isDebugMode)
      desc.append("".concat("\n", colorize("badTextColor", partName)))

    let rawPartName = getTblValue("raw_name", params)
    if (rawPartName)
      desc.append(rawPartName)

    return desc
  }

  function getEngineModelName(infoBlk) {
    return " ".join([
      infoBlk?.manufacturer ? loc($"engine_manufacturer/{infoBlk.manufacturer}") : ""
      infoBlk?.model ? loc($"engine_model/{infoBlk.model}") : ""
    ], true)
  }

  function getFireControlSystems(key, node) {
    return this.getUnitSensorsList()
      .filter(@(blk) blk.getBlockName() == "fireDirecting" && (blk % key).findvalue(@(v) v == node) != null)
  }

  function getNumFireControlNodes(mainNode, nodeId) {
    return this.getFireControlSystems("dmPartMain", mainNode)
      .map(@(fcBlk) fcBlk % "dmPart")
      .map(@(nodes) nodes.filter(@(node) node.indexof(nodeId) == 0).len())
      .reduce(@(sum, num) sum + num, 0)
  }

  function getFireControlTriggerGroups(fcBlk) {
    let groupsBlk = fcBlk?.triggerGroupUse
    if (!groupsBlk)
      return []

    let res = []
    for (local i = 0; i < groupsBlk.paramCount(); ++i)
      if (groupsBlk.getParamValue(i))
        res.append(groupsBlk.getParamName(i))

    return res
  }

  function getFireControlWeaponNames(fcBlk) {
    let triggerGroups = this.getFireControlTriggerGroups(fcBlk)
    let weapons = this.getUnitWeaponList().filter(@(w) triggerGroups.contains(w?.triggerGroup) && w?.blk)
    return unique(weapons, @(w) w.blk).map(@(w) getWeaponNameByBlkPath(w.blk))
  }

  function getFireControlAccuracy(fcBlk) {
    let accuracy = fcBlk?.measureAccuracy
    if (!accuracy)
      return -1

    return round(accuracy / this.getModEffect("ship_rangefinder", "shipDistancePrecisionErrorMult") * 100)
  }

  function getModEffect(modId, effectId) {
    if (shopIsModificationEnabled(this.unit.name, modId))
      return 1.0

    return get_modifications_blk()?.modifications[modId].effects[effectId] ?? 1.0
  }

  function findAnyModEffectValue(effectId) {
    for (local b = 0; b < (this.unitBlk?.modifications.blockCount() ?? 0); b++) {
      let modBlk = this.unitBlk.modifications.getBlock(b)
      let value = modBlk?.effects[effectId]
      if (value != null
        && (this.isDebugBatchExportProcess || shopIsModificationEnabled(this.unit.name, modBlk.getBlockName())))
          return value
    }
    return null
  }

  function getOpticsParams(zoomOutFov, zoomInFov) {
    let fovToZoom = @(fov) sin(80 / 2 * PI / 180) / sin(fov / 2 * PI / 180)
    let fovOutIn = [zoomOutFov, zoomInFov].filter(@(fov) fov > 0)
    let zoom = fovOutIn.map(@(fov) fovToZoom(fov))
    if (zoom.len() == 2 && abs(zoom[0] - zoom[1]) < 0.1) {
      zoom.remove(0)
      fovOutIn.remove(0)
    }
    let zoomTexts = zoom.map(@(v) format("%.1fx", v))
    let fovTexts = fovOutIn.map(@(fov) "".concat(round(fov), loc("measureUnits/deg")))
    return {
      zoom = loc("ui/mdash").join(zoomTexts, true)
      fov  = loc("ui/mdash").join(fovTexts,  true)
    }
  }

  function getOpticsDesc(info, mod = null) {
    let desc = []
    let sightName = mod && mod?.sightName
      ? mod?.sightName
      : info?.sightName
    if (sightName)
      desc.append(loc($"sight_model/{sightName}", ""))
    let zoomOutFov = mod?.zoomOutFov ?? (info?.zoomOutFov ?? 0)
    let zoomInFov = mod?.zoomInFov ?? (info?.zoomInFov ?? 0)
    let optics = this.getOpticsParams(zoomOutFov, zoomInFov)
    if (optics.zoom != "")
      desc.append("".concat(loc("optic/zoom"), loc("ui/colon"), optics.zoom))
    if (optics.fov != "")
      desc.append("".concat(loc("optic/fov"), loc("ui/colon"), optics.fov))
    return desc
  }

  function getAPSDesc(info) {
    let desc = []

    let deg = loc("measureUnits/deg")
    let {
      model = null, reactionTime = null,
      reloadTime = null, targetSpeed = null,
      shotCount = null, horAngles = null,
      verAngles = null
    } = info

    if (model)
      desc.append("".concat(loc("xray/model"), loc("ui/colon"), loc($"aps/{model}")))
    if (horAngles)
      desc.append("".concat(loc("xray/aps/protected_sector/hor"), loc("ui/colon"),
        (horAngles.x + horAngles.y == 0
          ? format("±%d%s", abs(horAngles.y), deg)
          : format("%+d%s/%+d%s", horAngles.x, deg, horAngles.y, deg))))
    if (verAngles)
      desc.append("".concat(loc("xray/aps/protected_sector/vert"), loc("ui/colon"),
        (verAngles.x + verAngles.y == 0
          ? format("±%d%s", abs(verAngles.y), deg)
          : format("%+d%s/%+d%s", verAngles.x, deg, verAngles.y, deg))))
    if (reloadTime)
      desc.append("".concat(loc("xray/aps/reloadTime"), loc("ui/colon"),
        reloadTime, " ", loc("measureUnits/seconds")))
    if (reactionTime)
      desc.append("".concat(loc("xray/aps/reactionTime"), loc("ui/colon"),
        reactionTime * 1000, " ", loc("measureUnits/milliseconds")))
    if (targetSpeed)
      desc.append("".concat(loc("xray/aps/targetSpeed"), loc("ui/colon"),
        $"{targetSpeed.x}-{targetSpeed.y}", " ", loc("measureUnits/metersPerSecond_climbSpeed")))
    if (shotCount)
      desc.append("".concat(loc("xray/aps/shotCount"), loc("ui/colon"),
        shotCount, " ",  loc("measureUnits/pcs")))
    return desc
  }

  function getWeaponTotalBulletCount(partId, weaponInfoBlk) {
    if (partId == "cannon_breech") {
      local result = 0
      let currentBreechDp = weaponInfoBlk?.breechDP
      if (!currentBreechDp)
        return result
      foreach (weapon in this.getUnitWeaponList()) {
        if (weapon?.breechDP == currentBreechDp)
          result += getTblValue("bullets", weapon, 0)
      }
      return result
    }
    else if (partId == "gun" && weaponInfoBlk?.turret)
      return this.getUnitWeaponList()
        .filter(@(weapon) weapon?.turret?.head && weapon?.turret?.head == weaponInfoBlk?.turret?.head)
        .reduce(@(bulletCount, weapon) bulletCount + getTblValue("bullets", weapon, 0), 0)
    else
      return getTblValue("bullets", weaponInfoBlk, 0)
  }

  function getInfoBlk(partName = null) {
    let sources = [this.unitBlk]
    let unitTags = getTblValue(this.unit.name, get_unittags_blk(), null)
    if (unitTags != null)
      sources.insert(0, unitTags)
    local infoBlk = this.getFirstFound(sources, @(b) partName ? b?.info?[partName] : b?.info)
    if (infoBlk && partName != null && "alias" in infoBlk)
      infoBlk = this.getInfoBlk(infoBlk.alias)
    return infoBlk
  }

  function getXrayViewerDataByDmPartName(partName) {
    let dataBlk = this.unitBlk && this.unitBlk?.xray_viewer_data
    local partIdx = null
    if (dataBlk)
      for (local b = 0; b < dataBlk.blockCount(); b++) {
        let blk = dataBlk.getBlock(b)
        if (blk?.xrayDmPart == partName)
          return blk
        if (blk?.xrayDmPartFmt != null) {
          partIdx = partIdx ?? this.extractIndexFromDmPartName(partName)
          if (partIdx != -1
              && partIdx >= (blk?.xrayDmPartRange.x ?? -1) && partIdx <= (blk?.xrayDmPartRange.y ?? -1)
              && format(blk.xrayDmPartFmt, partIdx) == partName)
            return blk
        }
      }
    return null
  }

  function getAmmoStowageSlotInfo(partName) {
    let res = {
      count = 0,
      isConstrainedInert = false
    }
    let ammoStowages = this.unitBlk?.ammoStowages
    if (ammoStowages)
      for (local i = 0; i < ammoStowages.blockCount(); i++) {
        let blk = ammoStowages.getBlock(i)
        foreach (blockName in [ "shells", "charges" ])
          foreach (shells in blk % blockName) {
            let slotBlk = shells?[partName]
            if (slotBlk) {
              res.count = slotBlk.count
              res.isConstrainedInert = slotBlk?.type == "inert";
              return res
            }
          }
      }
    return res
  }

  function getWeaponByXrayPartName(weaponPartName, linkedPartName = null) {
    let turretLinkedParts = [ "horDriveDm", "verDriveDm" ]
    let partLinkSources = [ "dm", "barrelDP", "breechDP", "maskDP", "gunDm", "ammoDP", "emitter" ]
    let partLinkSourcesGenFmt = [ "emitterGenFmt", "ammoDpGenFmt" ]
    let weaponList = this.getUnitWeaponList()
    foreach (weapon in weaponList) {
      if (linkedPartName != null && weapon?.turret != null)
        foreach (partKey in turretLinkedParts)
          if (weapon.turret?[partKey] == linkedPartName)
            return weapon
      foreach (linkKey in partLinkSources)
        if (linkKey in weapon && weapon[linkKey] == weaponPartName)
          return weapon
      if (u.isPoint2(weapon?.emitterGenRange)) {
        let rangeMin = min(weapon.emitterGenRange.x, weapon.emitterGenRange.y)
        let rangeMax = max(weapon.emitterGenRange.x, weapon.emitterGenRange.y)
        foreach (linkKeyFmt in partLinkSourcesGenFmt)
          if (weapon?[linkKeyFmt]) {
            if (weapon[linkKeyFmt].indexof("%02d") == null) {
              assert(false, $"Bad weapon param {linkKeyFmt}='{weapon[linkKeyFmt]}' on {this.unit.name}")
              continue
            }
            for (local i = rangeMin; i <= rangeMax; i++)
              if (format(weapon[linkKeyFmt], i) == weaponPartName)
                return weapon
          }
      }
      if ("partsDP" in weapon && weapon["partsDP"].indexof(weaponPartName) != null)
        return weapon
    }
    return null
  }

  function getWeaponStatus(weaponPartName, weaponInfoBlk) {
    if (this.simUnitType == S_TANK) {
      let blkPath = weaponInfoBlk?.blk ?? ""
      let blk = blkOptFromPath(blkPath)
      let isRocketGun = blk?.rocketGun
      let isMachinegun = !!blk?.bullet?.caliber && !isCaliberCannon(1000 * blk.bullet.caliber)
      local isPrimary = !isRocketGun && !isMachinegun
      if (!isPrimary)
        foreach (weapon in getCommonWeapons(dmViewer.unitBlk, "")) {
          if (!weapon?.blk || weapon?.dummy)
            continue
          isPrimary = weapon.blk == blkPath
          break
        }

      let isSecondary = !isPrimary && !isMachinegun
      return { isPrimary = isPrimary, isSecondary = isSecondary, isMachinegun = isMachinegun }
    }
    if (this.simUnitType == S_BOAT || this.simUnitType == S_SHIP) {
      let isPrimaryName       = startsWith(weaponPartName, "main")
      let isSecondaryName     = startsWith(weaponPartName, "auxiliary")
      let isPrimaryTrigger    = weaponInfoBlk?.triggerGroup == "primary"
      let isSecondaryTrigger  = weaponInfoBlk?.triggerGroup == "secondary"
      let isMachinegun  = weaponInfoBlk?.triggerGroup == "machinegun"
      return {
        isPrimary     = isPrimaryTrigger   || (isPrimaryName   && !isSecondaryTrigger && !isMachinegun)
        isSecondary   = isSecondaryTrigger || (isSecondaryName && !isPrimaryTrigger && !isMachinegun)
        isMachinegun  = isMachinegun
      }
    }

    if (this.simUnitType == S_AIRCRAFT || this.simUnitType == S_HELICOPTER)
      return { isPrimary = true, isSecondary = false, isMachinegun = false }

    return { isPrimary = true, isSecondary = false, isMachinegun = false }
  }

  getSign = @(n) n < 0 ? -1 : 1

  function getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, needAxisX, needAxisY) {
    let desc = []
    let needSingleAxis = !needAxisX || !needAxisY
    let status = this.getWeaponStatus(weaponPartName, weaponInfoBlk)
    if (!needSingleAxis && this.unit?.isTank() && !status.isPrimary && !status.isSecondary)
      return desc

    let deg = loc("measureUnits/deg")
    let isInverted = weaponInfoBlk?.invertedLimitsInViewer ?? false
    let isSwaped = weaponInfoBlk?.swapLimitsInViewer ?? false
    let verticalLabel = "shop/angleVerticalGuidance"
    let horizontalLabel = "shop/angleHorizontalGuidance"

    foreach (g in [
      { need = needAxisX, angles = weaponInfoBlk?.limits.yaw,   label = isInverted ? verticalLabel   : horizontalLabel, canSwap = true  }
      { need = needAxisY, angles = weaponInfoBlk?.limits.pitch, label = isInverted ? horizontalLabel : verticalLabel,   canSwap = false }
    ]) {
      if (!g.need || (!g.angles?.x && !g.angles?.y))
        continue

      let { x, y } = g.angles
      let anglesText = (x + y == 0) ? format("±%d%s", abs(y), deg)
        : (isSwaped && g.canSwap) ? format("%+d%s/%+d%s", abs(y) * this.getSign(x), deg, abs(x) * this.getSign(y), deg)
        : format("%+d%s/%+d%s", x, deg, y, deg)

      desc.append(" ".concat(loc(g.label), anglesText))
    }

    if (needSingleAxis || status.isPrimary || this.unit?.isShipOrBoat()) {
      let unitModificators = this.unit?.modificators?[this.difficulty.crewSkillName]
      foreach (a in [
        { need = needAxisX, modifName = "turnTurretSpeed", blkName = "speedYaw",
          shipFxName = [ "mainSpeedYawK", "auxSpeedYawK", "aaSpeedYawK" ],
          crewMemberTopSkill = { crewMember = "tank_gunner", skill = "tracking" },
          guidanceMultId = "arcadeTurretBoostHorz"
        },
        { need = needAxisY, modifName = "turnTurretSpeedPitch", blkName = "speedPitch",
          shipFxName = [ "mainSpeedPitchK", "auxSpeedPitchK", "aaSpeedPitchK" ],
          crewMemberTopSkill = { crewMember = "tank_gunner", skill = "tracking" },
          guidanceMultId = "arcadeTurretBoostVert"
        },
      ]) {
        if (!a.need)
          continue

        local speed = 0
        local speedMul = 1
        if (this.simUnitType == S_TANK) {
          let mainTurretSpeed = unitModificators?[a.modifName] ?? 0
          let value = weaponInfoBlk?[a.blkName] ?? 0
          let weapons = this.getUnitWeaponList()
          let mainTurretValue = weapons[0]?[a.blkName] ?? 0
          if (mainTurretValue != 0)
            speedMul = value / mainTurretValue
          speed = mainTurretSpeed * speedMul
        }
        else if (this.simUnitType == S_BOAT || this.simUnitType == S_SHIP) {
          let modId   = status.isPrimary    ? "new_main_caliber_turrets"
                        : status.isSecondary  ? "new_aux_caliber_turrets"
                        : status.isMachinegun ? "new_aa_caliber_turrets"
                        : ""
          let effectId = status.isPrimary    ? a.shipFxName[0]
                         : status.isSecondary  ? a.shipFxName[1]
                         : status.isMachinegun ? a.shipFxName[2]
                         : ""
          let baseSpeed = weaponInfoBlk?[a.blkName] ?? 0
          let modMul =  this.getModEffect(modId, effectId)
          let gameModeGuidanceSpeedMult = getTurretGuidanceSpeedMultByDiff(getCurrentGameModeEdiff())?[a.guidanceMultId] ?? 1
          speed = baseSpeed * modMul * gameModeGuidanceSpeedMult
        }

        if (speed) {
          let speedTxt = speed < 10 ? format("%.1f", speed) : format("%d", round(speed))
          let res = { value = "".concat(loc($"crewSkillParameter/{a.modifName}"), loc("ui/colon"), speedTxt, loc("measureUnits/deg_per_sec")) }
          local topValue = this.maxValuesParams?[this.difficulty.crewSkillName][a.crewMemberTopSkill.crewMember][a.crewMemberTopSkill.skill][a.modifName]
          topValue = topValue ? topValue * speedMul : topValue
          if (topValue != null && topValue > speed) {
            let topValueTxt = topValue < 10 ? format("%.1f", topValue) : format("%d", round(topValue))
            res.topValue <- "".concat(topValueTxt, loc("measureUnits/deg_per_sec"))
          }
          desc.append(res)
        }
      }
    }

    if (this.unit?.isTank()) {
      let gunStabilizer = weaponInfoBlk?.gunStabilizer
      let isStabilizerX = needAxisX && gunStabilizer?.hasHorizontal
      let isStabilizerY = needAxisY && gunStabilizer?.hasVertical
      if (isStabilizerX || isStabilizerY) {
        let valueLoc = needSingleAxis ? "options/yes"
          : (isStabilizerX ? "shop/gunStabilizer/twoPlane" : "shop/gunStabilizer/vertical")
        desc.append(" ".concat(loc("shop/gunStabilizer"), loc(valueLoc)))
      }
    }

    return desc
  }

  function getGunReloadTimeMax(weaponInfoBlk) {
    let weaponInfo = blkOptFromPath(weaponInfoBlk?.blk)
    let reloadTime = weaponInfoBlk?.reloadTime ?? weaponInfo?.reloadTime
    if (reloadTime)
      return reloadTime

    let shotFreq = weaponInfoBlk?.shotFreq ?? weaponInfo?.shotFreq
    if (shotFreq)
      return 1 / shotFreq

    return null
  }

  function getShipArtilleryReloadTime(weaponName) {
    let crewSkillParams = getParametersByCrewId(this.crew.id, this.unit.name)
    let crewSkill = crewSkillParams?[this.difficulty.crewSkillName]?.ship_artillery
    foreach (c in [ "main_caliber_loading_time", "aux_caliber_loading_time", "antiair_caliber_loading_time" ]) {
      let reloadTime = (crewSkill?[c]?[$"weapons/{weaponName}"]) ?? 0.0
      if (reloadTime) {
        let reloadTimeTop = this.maxValuesParams?[this.difficulty.crewSkillName]["ship_artillery"][c][$"weapons/{weaponName}"]
        return { reloadTime, reloadTimeTop }
      }
    }
    return { reloadTime = 0, reloadTimeTop = 0 }
  }

  function getShipArtilleryReloadTimeBase(weaponName) {
    let baseValuesParams = skillParametersRequestType.BASE_VALUES.getParameters(-1, this.unit)
    foreach (c in [ "main_caliber_loading_time", "aux_caliber_loading_time", "antiair_caliber_loading_time" ]) {
      let reloadTimeBase = baseValuesParams?[this.difficulty.crewSkillName]["ship_artillery"][c][$"weapons/{weaponName}"]
      if (reloadTimeBase)
        return reloadTimeBase
    }
    return 0
  }

  function getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status) {
    local shotFreqRPM = 0.0 // rounds/min
    local reloadTimeS = 0 // sec
    local firstStageShotFreq = 0.0
    local topValue = 0.0
    local firstStageShotFreqTop = 0.0
    local shotFreqRPMTop = 0.0

    let weaponBlk = blkOptFromPath(weaponInfoBlk?.blk)
    let isCartridge = weaponBlk?.reloadTime != null
    local cyclicShotFreqS  = weaponBlk?.shotFreq ?? 0.0 // rounds/sec

    if (this.simUnitType == S_AIRCRAFT || this.simUnitType == S_HELICOPTER) {
      shotFreqRPM = cyclicShotFreqS * 60
    }
    else if (this.simUnitType == S_TANK) {
      if (status.isPrimary) {
        let mainWeaponInfoBlk = this.getUnitWeaponList()?[0]
        if (mainWeaponInfoBlk != null) {
          let crewSkillParams = skillParametersRequestType.CURRENT_VALUES.getParameters(this.crew?.id ?? -1, this.unit)
          let mainGunReloadTime = crewSkillParams[this.difficulty.crewSkillName]["loader"]["loading_time_mult"]["tankLoderReloadingTime"]

          if (weaponInfoBlk.blk == mainWeaponInfoBlk.blk) {
            reloadTimeS = mainGunReloadTime
          }
          else {
            let thisGunReloadTimeMax = this.getGunReloadTimeMax(weaponInfoBlk)
            if (thisGunReloadTimeMax) {
              if (weaponInfoBlk?.autoLoader) {
                reloadTimeS = thisGunReloadTimeMax
              }
              else {
                let mainGunReloadTimeMax = this.getGunReloadTimeMax(mainWeaponInfoBlk)
                if (mainGunReloadTimeMax)
                  reloadTimeS = mainGunReloadTime * thisGunReloadTimeMax / mainGunReloadTimeMax
              }
              topValue = round_by_value(thisGunReloadTimeMax, 0.1)
            }
          }
          if(topValue == 0)
            topValue = this.maxValuesParams?[this.difficulty.crewSkillName]["loader"]["loading_time_mult"]["tankLoderReloadingTime"]
        }
      }
    }
    else if (this.simUnitType == S_BOAT || this.simUnitType == S_SHIP) {
      if (isCartridge) {
        if (this.crew) {
          let { reloadTime, reloadTimeTop } = this.getShipArtilleryReloadTime(weaponName)
          reloadTimeS = reloadTime
          topValue = reloadTimeTop
        }
        else {
          let wpcostUnit = get_wpcost_blk()?[this.unit.name]
          foreach (c in [ "shipMainCaliberReloadTime", "shipAuxCaliberReloadTime", "shipAntiAirCaliberReloadTime" ]) {
            reloadTimeS = wpcostUnit?[$"{c}_{weaponName}"] ?? 0.0
            if (reloadTimeS) {
              let reloadTimeBase = this.getShipArtilleryReloadTimeBase(weaponName)
              if(reloadTimeBase != 0) {
                topValue = reloadTimeS
                reloadTimeS = reloadTimeBase
              }
              break
            }
          }
        }
      }

      if (!reloadTimeS) {
        cyclicShotFreqS = u.search(getCommonWeapons(dmViewer.unitBlk, ""),
          @(inst) inst.trigger  == weaponInfoBlk.trigger)?.shotFreq ?? cyclicShotFreqS
        shotFreqRPM = cyclicShotFreqS * 60

        if (this.haveFirstStageShells(weaponInfoBlk?.trigger)) {
          firstStageShotFreq = shotFreqRPM
          shotFreqRPM *= 1 / this.getAmmoStowageReloadTimeMult(weaponInfoBlk?.trigger)
        }

        if (this.crew) {
          let { reloadTime, reloadTimeTop } = this.getShipArtilleryReloadTime(weaponName)
          if (reloadTime != 0 && reloadTimeTop != 0) {
            let coeff = reloadTimeTop / reloadTime
            firstStageShotFreqTop = firstStageShotFreq
            shotFreqRPMTop = shotFreqRPM
            firstStageShotFreq *= coeff
            shotFreqRPM *= coeff
          }
        }
        else {
          let reloadTimeBase = this.getShipArtilleryReloadTimeBase(weaponName)
          if (reloadTimeBase) {
            if (firstStageShotFreq) {
              firstStageShotFreqTop = firstStageShotFreq
              shotFreqRPMTop = shotFreqRPM
              firstStageShotFreq = 60 / reloadTimeBase
              shotFreqRPM = firstStageShotFreq * shotFreqRPMTop / firstStageShotFreqTop
            }
            else {
              shotFreqRPMTop = shotFreqRPM
              shotFreqRPM = 60 / reloadTimeBase
            }
          }
        }
      }
    }

    let desc = []
    if (firstStageShotFreq) {
      let res = { value = " ".concat(loc("shop/shotFreq/firstStage"), round(firstStageShotFreq), loc("measureUnits/rounds_per_min")) }
      if (firstStageShotFreq < firstStageShotFreqTop)
        res.topValue <- " ".concat(round(firstStageShotFreqTop), loc("measureUnits/rounds_per_min"))
      desc.append(res)
    }

    if (shotFreqRPM) {
      shotFreqRPM = round_by_value(shotFreqRPM, shotFreqRPM > 600 ? 10
        : shotFreqRPM < 10 ? 0.1
        : 1)
      shotFreqRPMTop = round_by_value(shotFreqRPMTop, shotFreqRPMTop > 600 ? 10
        : shotFreqRPMTop < 10 ? 0.1
        : 1)
      let res = { value = " ".concat(loc("shop/shotFreq"), shotFreqRPM, loc("measureUnits/rounds_per_min")) }
      if (shotFreqRPM < shotFreqRPMTop)
        res.topValue <- " ".concat(shotFreqRPMTop, loc("measureUnits/rounds_per_min"))
      desc.append(res)
    }
    if (reloadTimeS) {
      reloadTimeS = round_by_value(reloadTimeS, 0.1)
      topValue = round_by_value(topValue, 0.1)
      reloadTimeS = (reloadTimeS % 1) ? format("%.1f", reloadTimeS) : format("%d", reloadTimeS)
      let res = { value = " ".concat(loc("shop/reloadTime"), reloadTimeS, loc("measureUnits/seconds")) }
      if (topValue != 0 && topValue < to_float_safe(reloadTimeS, 0))
        res.topValue <- " ".concat(topValue, loc("measureUnits/seconds"))
      desc.append(res)
    }
    return desc
  }

  function getAmmoStowageBlockByParam(trigger, paramName) {
    if (!this.unitBlk?.ammoStowages || !trigger)
      return null

    let ammoCount = this.unitBlk.ammoStowages.blockCount()
    for (local i = 0; i < ammoCount; i++) {
      let ammo = this.unitBlk.ammoStowages.getBlock(i)
      if ((ammo % "weaponTrigger").findvalue(@(inst) inst == trigger))
        return (ammo % "shells").findvalue(@(inst) inst?[paramName])
    }
    return null
  }

  getAmmoStowageReloadTimeMult = @(trigger) this.getAmmoStowageBlockByParam(trigger, "reloadTimeMult")?.reloadTimeMult ?? 1

  haveFirstStageShells = @(trigger) this.getAmmoStowageBlockByParam(trigger, "firstStage") ?? false

  // Gets info either by weaponTrigger (for guns and turrets)
  // or by ammoStowageId (for tank stowage or ship ammo storage)
  function getAmmoStowageInfo(weaponTrigger, ammoStowageId = null, collectOnlyThisStowage = false) {
    let res = { firstStageCount = 0, isAutoLoad = false, isCharges = false }
    for (local ammoNum = 1; ammoNum <= 20; ammoNum++) { // tanks use 1, ships use 1 - ~10.
      let ammoId = $"ammo{ammoNum}"
      let stowage = this.unitBlk?.ammoStowages?[ammoId]
      if (!stowage)
        break
      if (weaponTrigger && stowage.weaponTrigger != weaponTrigger)
        continue
      if ((this.unitBlk.ammoStowages % ammoId).len() > 1) {
        let unitName = this.unit?.name // warning disable: -declared-never-used
        script_net_assert_once("ammoStowages_contains_non-unique_ammo", "ammoStowages contains non-unique ammo")
      }
      foreach (blockName in [ "shells", "charges" ]) {
        foreach (block in (stowage % blockName)) {
          if (ammoStowageId && !block?[ammoStowageId])
            continue
          res.isCharges = blockName == "charges"
          if (block?.autoLoad)
            res.isAutoLoad = true
          if (block?.firstStage || block?.autoLoad) {
            if (ammoStowageId && collectOnlyThisStowage)
              res.firstStageCount += block?[ammoStowageId]?.count ?? 0
            else
              for (local i = 0; i < block.blockCount(); i++)
                res.firstStageCount += block.getBlock(i)?.count ?? 0
          }
          return res
        }
      }
    }
    return res
  }

  function getModernArmorParamsByDmPartName(partName) {
    local res = {
      isComposite = startsWith(partName, "composite_armor") || startsWith(partName, "firewall_armor")
      titleLoc = ""
      armorClass = ""
      referenceProtectionArray = []
      layersArray = []
    }

    let blk = this.getXrayViewerDataByDmPartName(partName)
    if (blk) {
      res.titleLoc = blk?.titleLoc ?? ""

      let referenceProtectionBlocks = blk?.referenceProtectionTable ? (blk.referenceProtectionTable % "i")
        : (blk?.kineticProtectionEquivalent || blk?.cumulativeProtectionEquivalent) ? [ blk ]
        : []
      res.referenceProtectionArray = referenceProtectionBlocks.map(@(b) {
        angles = b?.angles
        kineticProtectionEquivalent    = b?.kineticProtectionEquivalent    ?? 0
        cumulativeProtectionEquivalent = b?.cumulativeProtectionEquivalent ?? 0
      })

      let armorParams = { armorClass = "", armorThickness = 0.0 }
      let armorLayersArray = (blk?.armorArrayText ?? DataBlock()) % "layer"

      foreach (layer in armorLayersArray) {
        let info = this.getDamagePartParamsByDmPartName(layer?.dmPart, armorParams)
        if (layer?.xrayTextThickness != null)
          info.armorThickness = layer.xrayTextThickness
        if (layer?.xrayArmorClass != null)
          info.armorClass = layer.xrayArmorClass
        res.layersArray.append(info)
      }
    }
    else {
      let armorParams = { armorClass = "", kineticProtectionEquivalent = 0, cumulativeProtectionEquivalent = 0 }
      let info = this.getDamagePartParamsByDmPartName(partName, armorParams)
      res.referenceProtectionArray = [{
        angles = null
        kineticProtectionEquivalent    = info.kineticProtectionEquivalent
        cumulativeProtectionEquivalent = info.cumulativeProtectionEquivalent
      }]
      res = u.tablesCombine(res, info, @(a, b) b == null ? a : b, null, false)
    }

    return res
  }

  function getDamagePartParamsByDmPartName(partName, paramsTbl) {
    local res = clone paramsTbl
    if (!this.unitBlk?.DamageParts)
      return res
    let dmPartsBlk = this.unitBlk.DamageParts
    res = u.tablesCombine(res, dmPartsBlk, @(a, b) b == null ? a : b, null, false)
    for (local i = 0; i < dmPartsBlk.blockCount(); i++) {
      let groupBlk = dmPartsBlk.getBlock(i)
      if (!groupBlk || !groupBlk?[partName])
        continue
      res = u.tablesCombine(res, groupBlk, @(a, b) b == null ? a : b, null, false)
      res = u.tablesCombine(res, groupBlk[partName], @(a, b) b == null ? a : b, null, false)
      break
    }
    return res
  }

  function extractIndexFromDmPartName(partName) {
    let strArr = partName.split("_")
    let l = strArr.len()
    return (l > 2 && strArr[l - 1] == "dm") ? to_integer_safe(strArr[l - 2], -1, false) : -1
  }

  function checkPartLocId(partId, partName, weaponInfoBlk, params) {
    if (this.simUnitType == S_TANK) {
      if (partId == "gun_barrel" &&  weaponInfoBlk?.blk) {
        let status = this.getWeaponStatus(partName, weaponInfoBlk)
        params.partLocId <- status.isPrimary ? "weapon/primary"
          : status.isMachinegun ? "weapon/machinegun"
          : "weapon/secondary"
      }
    }
    else if (this.simUnitType == S_BOAT || this.simUnitType == S_SHIP) {
      if (startsWith(partId, "main") && weaponInfoBlk?.triggerGroup == "secondary")
        params.partLocId <- partId.replace("main", "auxiliary")
      if (startsWith(partId, "auxiliary") && weaponInfoBlk?.triggerGroup == "primary")
        params.partLocId <- partId.replace("auxiliary", "main")
    }
    else if (this.simUnitType == S_HELICOPTER) {
      if (isInArray(partId, [ "gun", "cannon" ]))
        params.partLocId <- startsWith(weaponInfoBlk?.trigger, "gunner") ? "turret" : "cannon"
    }
  }

  function trimBetween(source, from, to, strict = true) {
    local beginIndex = source.indexof(from) ?? -1
    let endIndex = source.indexof(to) ?? -1
    if (strict && (beginIndex == -1 || endIndex == -1 || beginIndex >= endIndex))
      return null
    if (beginIndex == -1)
      beginIndex = 0
    beginIndex += from.len()
    if (endIndex == -1)
      beginIndex = source.len()
    return source.slice(beginIndex, endIndex)
  }

  function getMassInfo(data) {
    let massPatterns = [
      { variants = ["mass", "Mass"], langKey = "mass/kg" },
      { variants = ["mass_lbs", "Mass_lbs"], langKey = "mass/lbs" }
    ]
    foreach (pattern in massPatterns)
      foreach (nameVariant in pattern.variants)
        if (nameVariant in data)
          return format(" ".concat(loc("shop/tank_mass"), loc(pattern.langKey)), data[nameVariant])
    return "";
  }

  function showExternalPartsArmor(isShow) {
    this.isVisibleExternalPartsArmor = isShow
    hangar_show_external_dm_parts_change(isShow)
  }

  function onEventActiveHandlersChanged(_p) {
    this.update()
  }

  function onEventHangarModelLoading(_p) {
    this.reinit()
  }

  function onEventHangarModelLoaded(_p) {
    this.reinit()
  }

  function onEventUnitModsRecount(p) {
    if (p?.unit != this.unit)
      return
    this.clearCachedUnitBlkNodes()
    this.resetXrayCache()
  }

  function onEventUnitWeaponChanged(p) {
    if (!this.unit || p?.unitName != this.unit.name)
      return
    this.clearCachedUnitBlkNodes()
    this.resetXrayCache()
  }

  function onEventCurrentGameModeIdChanged(_p) {
    this.difficulty = get_difficulty_by_ediff(getCurrentGameModeEdiff())
    this.resetXrayCache()
  }

  function onEventGameLocalizationChanged(_p) {
    this.resetXrayCache()
  }

  onEventModificationChanged = @(_p) this.maxValuesParams = skillParametersRequestType.MAX_VALUES.getParameters(-1, this.unit)
}

registerPersistentData("dmViewer", dmViewer, [ "active", "view_mode", "_currentViewMode", "isDebugMode",
    "isVisibleExternalPartsArmor" ])
subscribe_handler(dmViewer, g_listener_priority.DEFAULT_HANDLER)

eventbus_subscribe("on_hangar_damage_part_pick", @(p) dmViewer.updateHint(p))

::dmViewer <- dmViewer