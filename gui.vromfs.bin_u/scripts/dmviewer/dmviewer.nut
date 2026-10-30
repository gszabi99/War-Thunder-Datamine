import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%scripts/tutorials/tutorialActions.nut" as tutorAction
import "DataBlock" as DataBlock
from "%scripts/controls/rawShortcuts.nut" import GAMEPAD_ENTER_SHORTCUT
from "%scripts/difficulty.nut" import get_difficulty_by_ediff
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/mainmenu/topMenuStates.nut" import topMenuHandler
from "%scripts/hangarModelLoadManager.nut" import hasLoadedModel
from "%scripts/time.nut" import TIME_DAY_IN_SECONDS
from "%scripts/unit/unitChecks.nut" import checkUnitModsUpdate, checkSecondaryWeaponModsRecount
from "%scripts/unit/unitParams.nut" import getFullUnitBlk
from "%scripts/crew/crewInfo.nut" import getCrewByAir
from "%scripts/myStats.nut" import isStatsLoaded, isMeNewbieOnUnitType
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%scripts/options/optionsExt.nut" import get_option, set_option
from "%scripts/options/optionsExtNames.nut" import USEROPT_XRAY_FILTER_TANK, USEROPT_XRAY_FILTER_SHIP, USEROPT_XRAY_FILTER_AIR
from "%scripts/popups/popupFilterWidget.nut" import openPopupFilter, RESET_ID, SELECT_ALL_ID
from "%scripts/dmViewer/xrayAmmoLoadWidget.nut" import openXrayAmmoLoad
from "%scripts/sqDagui/framework/gui_handlers.nut" import is_gui_handler_instance
from "%scripts/weaponry/dmgModel.nut" import getTankXrayFilter
from "%scripts/weaponry/weaponryInfo.nut" import getCommonWeapons, getLastPrimaryWeapon, getLastWeapon
from "%scripts/weaponry/weaponryPresets.nut" import getPresetWeapons
from "%scripts/weaponry/modificationInfo.nut" import isModificationEnabled
from "%scripts/unit/unitBlkCache.nut" import blkOptFromPathCachedByUnit
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/guiTutorial.nut" import gui_modal_tutor
from "%scripts/dmViewer/modeXrayUtils.nut" import getSimpleUnitType, getDescriptionInXrayMode
from "%globalScripts/modeXrayLib.nut" import S_UNDEFINED, getPartType, getPartNameLocText, getPartNameDescLocText
from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler, broadcastEvent
from "%appGlobals/login/loginState.nut" import hasFullLoginState, isProfileReceived
from "console" import register_command
from "string" import format
from "math" import round
from "hangar" import hangar_get_current_unit_name, hangar_set_dm_viewer_mode, DM_VIEWER_NONE, DM_VIEWER_ARMOR, DM_VIEWER_XRAY, DM_VIEWER_CREW, hangar_get_dm_viewer_parts_count, set_xray_parts_filter, hangar_set_xray_ammo_counts
from "%sqstd/datablock.nut" import blkOptFromPath
from "%sqstd/string.nut" import cutPrefix
from "chard" import get_charserver_time_sec
from "blkGetters" import get_game_params_blk, get_unittags_blk
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import hangar_show_external_dm_parts_change
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { xrayCommonGetters } = require("%scripts/dmViewer/modeXrayUtils.nut")
let UnitBulletsManager = require("%scripts/weaponry/unitBulletsManager.nut")

let isWeaponrySelectModal = @(handler) is_gui_handler_instance(handler, "WeaponrySelectModal")










const XRAY_FILTER_OBJ_PREFIX = "xray_filter_"

const MAX_VIEW_MODE_TUTOR_SHOWS = 2

let armorHintParams = ["thickness", "effective_thickness", "angle", "normal_angle"]

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

function getXrayFilterOption() {
  let unitName = hangar_get_current_unit_name()
  let unit = getAircraftByName(unitName)
  if (unit == null)
    return null

  if (unit.isTank())
    return get_option(USEROPT_XRAY_FILTER_TANK, { unitName })

  if (unit.isShipOrBoat())
    return get_option(USEROPT_XRAY_FILTER_SHIP, { unitName })

  if ((unit.isAir() || unit.isHelicopter()) && hasFeature("DmViewerXrayFilterAircraft"))
    return get_option(USEROPT_XRAY_FILTER_AIR, { unitName })

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
  else if (objId == SELECT_ALL_ID) {
    let selectAllValue = xrayFilterOption.values.reduce(function(res, v) { return res + v }, 0)
    set_option(optionId, selectAllValue, xrayFilterOption)
    return
  }

  let idx = cutPrefix(objId, XRAY_FILTER_OBJ_PREFIX).tointeger()
  let optionValue = value ? (xrayFilterOption.value | xrayFilterOption.values[idx])
    : (xrayFilterOption.value & ~xrayFilterOption.values[idx])
  set_option(optionId, optionValue, xrayFilterOption)
}

function mkUnitXrayData(unit, unitBlk) {
  return {
    unit
    simUnitType = getSimpleUnitType(unit)
    unitBlk
    unitDataCache = {}
    xrayRemap = (unitBlk?.xray ?? {}).map(@(v) v)
  }
}

let dmViewerStorage = mkHardPersist("dmViewer.dmViewer")("dmViewerStorage", {
  view_mode = DM_VIEWER_NONE
  _currentViewMode = DM_VIEWER_NONE
  viewModeForRestore = null
  isVisibleExternalPartsArmor = true
  active = false
  isDebugMode = false
})

local dmViewer
dmViewer = {
  
  
  unit = null
  simUnitType = S_UNDEFINED
  crew = null
  unitBlk = null
  unitDataCache = {}
  xrayRemap = {}
  ediff = null
  difficulty = null
  filtersWidget = null
  ammoLoadWidgets = []

  modes = {
    [DM_VIEWER_NONE]  = "none",
    [DM_VIEWER_ARMOR] = "armor",
    [DM_VIEWER_XRAY]  = "xray",
    [DM_VIEWER_CREW]  = "xray"
  }

  modesValidForXray = [DM_VIEWER_XRAY, DM_VIEWER_CREW]
  prevHintParams = {}

  screen = [ 0, 0 ]
  unsafe = [ 0, 0 ]
  offset = [ 0, 0 ]

  absoluteArmorThreshold = 500
  relativeArmorThreshold = 5.0

  showStellEquivForArmorClassesList = []
  armorClassToSteel = null

  xrayDescriptionCache = {}
  dockedUnitsXrayData = {}
  isDebugBatchExportProcess = false
  bulletsManager = null
  loadedAmmo = null
  appliedXrayAmmo = null
  isXrayBreechShown = false
  isLoadedAmmoLoading = false
  isSecondaryModsValid = false

  function getCurrentViewMode() { return dmViewerStorage._currentViewMode }
  function setCurrentViewMode(value) {
    dmViewerStorage._currentViewMode = value
    hangar_set_dm_viewer_mode(value)
    this.updateNoPartsNotification()
  }

  function restoreSavedViewMode() {
    if (dmViewerStorage.viewModeForRestore == null)
      return
    this.toggle(dmViewerStorage.viewModeForRestore)
    dmViewerStorage.viewModeForRestore = null
  }

  saveViewModeForRestore = @() dmViewerStorage.viewModeForRestore = dmViewerStorage.view_mode

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
      timerObj.setUserData(handler) 
                                    

    this.update()
  }

  function updateSecondaryMods() {
    if (this.isDebugBatchExportProcess) {
      this.isSecondaryModsValid = true
      return
    }

    if (! this.unit)
      return
    this.isSecondaryModsValid = checkUnitModsUpdate(this.unit)
      && checkSecondaryWeaponModsRecount(this.unit)
  }

  function onEventSecondWeaponModsUpdated(params) {
    if (! this.unit || this.unit.name != params?.unit.name)
      return
    this.isSecondaryModsValid = true
    this.resetXrayCache()
    this.reinit()
  }

  function resetXrayCache() {
    this.xrayDescriptionCache.clear()
    this.unitDataCache.clear()
    this.dockedUnitsXrayData.clear()
    this.prevHintParams.clear()
  }

  function getUnitXrayData(unitName) {
    if (unitName == null || unitName == this.unit?.name)
      return this
    if (unitName not in this.dockedUnitsXrayData) {
      let unit = getAircraftByName(unitName)
      if (unit == null)
        return this
      this.dockedUnitsXrayData[unitName] <- mkUnitXrayData(unit, getFullUnitBlk(unitName))
    }
    return this.dockedUnitsXrayData[unitName]
  }

  function getHangarUnit() {
    return getAircraftByName(hangar_get_current_unit_name())
  }

  function canUse() {
    return hasFeature("DamageModelViewer") && this.getHangarUnit() != null
  }

  function hasDmViewer() {
    return hasFeature("DamageModelViewer")
      && !(this.getHangarUnit()?.unitType.isDmViewerHidden ?? false)
  }

  function reinit() {
    if (!hasFullLoginState.get())
      return

    this.updateUnitInfo()
    this.update()
  }

  function isDmModeValidForXrayView(viewMode = null) {
    let vMode = viewMode ?? this.getCurrentViewMode()
    return this.modesValidForXray.contains(vMode)
  }

  function updateUnitInfo(forcedUnitId = null) {
    let unitId = forcedUnitId ?? hangar_get_current_unit_name()
    if (this.unit && unitId == this.unit.name)
      return
    this.unit = getAircraftByName(unitId)
    this.loadedAmmo = null
    if (! this.unit)
      return
    this.ediff = getCurrentGameModeEdiff()
    this.difficulty = get_difficulty_by_ediff(this.ediff)
    this.crew = getCrewByAir(this.unit)
    this.loadUnitBlk()
    this.__update(mkUnitXrayData(this.unit, this.unitBlk))
    this.armorClassToSteel = this.collectArmorClassToSteelMuls()
    this.clearHint()
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
    
    this.resetXrayCache()
    this.unitBlk = getFullUnitBlk(this.unit.name)
  }

  function collectArmorClassToSteelMuls() {
    let res = {}
    let armorClassesBlk = blkOptFromPath("gamedata/damage_model/armor_classes.blk")
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
    if (state == dmViewerStorage.view_mode)
      return

    dmViewerStorage.view_mode =
      (state == null) ? ((dmViewerStorage.view_mode + 1) % this.modes.len()) :
      (state in this.modes) ? state :
      DM_VIEWER_NONE

    
    if (!this.update() && dmViewerStorage.active)
      this.show()
    if (!dmViewerStorage.active || dmViewerStorage.view_mode == DM_VIEWER_NONE)
      this.clearHint()
  }

  function show(vis = true) {
    dmViewerStorage.active = vis
    let viewMode = (dmViewerStorage.active && this.canUse()) ? dmViewerStorage.view_mode : DM_VIEWER_NONE
    this.setCurrentViewMode(viewMode)
    if (!dmViewerStorage.active)
      this.clearHint()
    this.repaint()
  }

  function update() {
    this.updateNoPartsNotification()

    local newActive = this.canUse() && !handlersManager.isAnyModalHandlerActive(isWeaponrySelectModal)
    if (!newActive && !dmViewerStorage.active) 
      return false

    let handler = handlersManager.getActiveBaseHandler()
    newActive = newActive && (handler?.canShowDmViewer() ?? false)
    if (topMenuHandler.get()?.isSceneActive() ?? false)
      newActive = newActive && topMenuHandler.get().canShowDmViewer()

    if (newActive == dmViewerStorage.active) {
      this.repaint()
      return false
    }

    this.show(newActive)
    return true
  }

  function needShowExtHints() {
    return loadLocalAccountSettings("dmViewer/needShowExtHints", true)
  }

  function needShowLoadedAmmo() {
    return loadLocalAccountSettings("dmViewer/showLoadedAmmo", false)
  }

  function canShowLoadedAmmo() {
    return hasFeature("DmViewerXrayLoadedAmmo") && (this.unit?.isTank() ?? false)
      && this.getStowagesBlk() != null
  }

  function getLoadedAmmo() {
    if (this.loadedAmmo != null)
      return this.loadedAmmo
    if (this.isLoadedAmmoLoading)
      return { weapons = [], counts = {}, mainGun = null, breechTriggers = [], hasRoundInGun = false }
    this.isLoadedAmmoLoading = true
    if (this.bulletsManager == null)
      this.bulletsManager = UnitBulletsManager(this.unit)
    else
      this.bulletsManager.setUnit(this.unit, true)
    let bulGroups = this.bulletsManager.getBulletsGroups()
    this.isLoadedAmmoLoading = false
    let countByGun = {}
    foreach (bulGroup in bulGroups) {
      let gunIdx = bulGroup.gunInfo?.gunIdx
      if (bulGroup.active && gunIdx != null)
        countByGun[gunIdx] <- (countByGun?[gunIdx] ?? 0) + max(0, bulGroup.bulletsCount) * bulGroup.cartridgesPerStep
    }
    let stowageByTrigger = this.getStowageByTrigger()
    let unitWeapons = this.getUnitWeapons()
    let triggerByBlk = {}
    foreach (weapon in unitWeapons)
      if (weapon.blk not in triggerByBlk)
        triggerByBlk[weapon.blk] <- weapon.trigger
    let weapons = []
    let counts = {}
    foreach (gunIdx, gunCount in countByGun) {
      let gunInfo = this.bulletsManager.gunsInfo?[gunIdx]
      let trigger = triggerByBlk?[gunInfo?.blk]
      if (trigger == null || trigger not in stowageByTrigger)
        continue
      let cartridge = gunInfo?.cartridge ?? 1
      let guns = gunInfo?.guns ?? 1
      counts[trigger] <- gunCount
      weapons.append({
        trigger
        count = gunCount
        loadedShells = cartridge * guns
        shells = gunCount * cartridge
        totalShells = (gunInfo?.total ?? 0) * (gunInfo?.cartridgesPerStep ?? guns) * cartridge
        isShellGun = !(gunInfo?.isBulletBelt ?? true)
      })
    }
    weapons.sort(@(a, b) a.trigger <=> b.trigger)
    let mainGun = weapons?[0]
    let breechTriggers = []
    foreach (weapon in unitWeapons) {
      let trigger = weapon.trigger
      let stowage = stowageByTrigger?[trigger]
      if (stowage != null && stowage.removeLoadedAmmo && !stowage.hasLoadedInGunCluster
          && !(blkOptFromPathCachedByUnit(weapon.blk, this.unit.name)?.isBulletBelt ?? true)
          && !breechTriggers.contains(trigger))
        breechTriggers.append(trigger)
    }
    this.loadedAmmo = {
      weapons
      counts
      mainGun
      breechTriggers
      hasRoundInGun = (mainGun?.isShellGun ?? false) && (stowageByTrigger?[mainGun?.trigger]?.removeLoadedAmmo ?? false)
        && (mainGun?.count ?? 0) > 0
    }
    return this.loadedAmmo
  }

  function getAmmoLoadWidget(nestObj) {
    this.ammoLoadWidgets = this.ammoLoadWidgets.filter(@(w) w?.isValid() ?? false)
    return this.ammoLoadWidgets.findvalue(@(w) w.scene.isEqual(nestObj))
  }

  function getUnitWeapons() {
    let unitName = this.unit.name
    let presetName = getLastWeapon(unitName)
    let preset = this.unit.getWeapons().findvalue(@(w) w.name == presetName)
    let weapons = []
    weapons.extend(getCommonWeapons(this.unitBlk, getLastPrimaryWeapon(this.unit), unitName))
    weapons.extend(getPresetWeapons(this.unitBlk, preset, unitName))
    return weapons.filter(@(w) w?.blk != null && w?.trigger != null && !(w?.dummy ?? false))
  }

  function getStowagesBlk() {
    let res = this.unitBlk?.ammoStowages
    let mods = this.unitBlk?.modifications
    if (mods == null)
      return res
    for (local i = 0; i < mods.blockCount(); i++) {
      let mod = mods.getBlock(i)
      let modStowages = mod?.effects.ammoStowages
      if (modStowages != null && isModificationEnabled(this.unit.name, mod.getBlockName()))
        return modStowages
    }
    return res
  }

  function getStowageByTrigger() {
    let res = {}
    let stowages = this.getStowagesBlk()
    if (stowages == null)
      return res
    for (local i = 0; i < stowages.blockCount(); i++) {
      let stowage = stowages.getBlock(i)
      local hasLoadedInGunCluster = false
      for (local j = 0; j < stowage.blockCount(); j++)
        if (stowage.getBlock(j)?.ammoLoadedInGun ?? false) {
          hasLoadedInGunCluster = true
          break
        }
      foreach (trigger in (stowage % "weaponTrigger"))
        res[trigger] <- { removeLoadedAmmo = stowage?.removeLoadedAmmo ?? true, hasLoadedInGunCluster }
    }
    return res
  }

  function isAmmoOnlyXrayFilter() {
    let option = getXrayFilterOption()
    let ammoBit = getTankXrayFilter(this.unit?.name).findvalue(@(f) f.name == "ammo")?.bit
    return option != null && ammoBit != null && option.value == ammoBit
  }

  function updateXrayAmmoCount() {
    let isXray = hasLoadedModel() && this.isDmModeValidForXrayView()
    let ammo = this.canShowLoadedAmmo() ? this.getLoadedAmmo() : null
    let isShow = isXray && ammo != null && this.needShowLoadedAmmo()
    let counts = (ammo?.counts ?? {}).map(@(count) isShow ? count : -1)
    let breechTriggers = !isXray || !this.isAmmoOnlyXrayFilter() ? []
      : (ammo?.breechTriggers ?? []).filter(@(t) !isShow || (counts?[t] ?? 1) > 0)
    let showBreech = breechTriggers.len() > 0
    let triggers = counts.keys()
    triggers.sort()
    let applied = "".concat(", ".join(triggers.map(@(t) $"{t}={counts[t]}")), "/", ",".join(breechTriggers))
    if (applied == this.appliedXrayAmmo)
      return
    this.appliedXrayAmmo = applied
    if (showBreech != this.isXrayBreechShown) {
      this.isXrayBreechShown = showBreech
      this.resetXrayCache()
    }
    hangar_set_xray_ammo_counts(counts, breechTriggers)
  }

  function checkShowViewModeTutor(modeId) {
    if (dmViewerStorage.view_mode == modeId)
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
    if (hasFullLoginState.get())
      this.updateUnitInfo()
    let handler = handlersManager.getActiveBaseHandler()
    if (!handler)
      return

    local obj = showObjById("air_info_dmviewer_listbox", this.hasDmViewer(), handler.scene)
    if (!checkObj(obj))
      return

    obj.setValue(dmViewerStorage.view_mode)

    
    if (hasFeature("DmViewerProtectionAnalysis")) {
      let isEnabled = dmViewerStorage.view_mode == DM_VIEWER_ARMOR
        && (this.unit?.unitType.canShowProtectionAnalysis() ?? false)
      showObjById("dmviewer_protection_analysis_btn", isEnabled, handler.scene)
    }

    let isTankOrShip = this.unit != null && (this.unit.isTank() || this.unit.isShipOrBoat())
    
    if (hasFeature("DmViewerExternalArmorHiding")) {
      obj = handler.scene.findObject("dmviewer_show_external_dm")
      if (checkObj(obj)) {
        let isShowOption = dmViewerStorage.view_mode == DM_VIEWER_ARMOR && isTankOrShip
        obj.show(isShowOption)
        if (isShowOption)
          obj.setValue(dmViewerStorage.isVisibleExternalPartsArmor)
      }
    }

    obj = handler.scene.findObject("filter_nest")
    if (obj?.isValid()) {
      let xrayFilterOption = getXrayFilterOption()
      let isShowOption = this.isDmModeValidForXrayView() && (xrayFilterOption?.values.len() ?? 0) > 0
      obj.show(isShowOption)
      if (isShowOption) {
        if (obj.childrenCount() == 0) {
          let popupFilterHandler = openPopupFilter({
            scene = obj
            btnTitle = loc("xray_part_filter")
            btnName = ""
            btnWidth = "1@airInfoPanelDmSwitcherWidth"
            popupAlign = "top"
            onChangeFn = applyXrayFilter
            filterTypesFn = getXrayFilterList
            closeAsPopup = false
            hasBtnIcon = false
          })
          this.filtersWidget = popupFilterHandler.weakref()
        }
        else
          broadcastEvent("UpdateFiltersCount") 
        set_xray_parts_filter(xrayFilterOption.value)
      } else if (this.isDmModeValidForXrayView() && hasLoadedModel())
        set_xray_parts_filter(0)

      if (!isShowOption && this.filtersWidget?.popupFilterWnd.isValid())
        this.filtersWidget.popupFilterWnd.close()
    }

    obj = handler.scene.findObject("dmviewer_show_extended_hints")
    if (obj?.isValid()) {
      let isShowOption = this.isDmModeValidForXrayView() && !!this.unit?.isShipOrBoat()
      obj.show(isShowOption)
      if (isShowOption)
        obj.setValue(this.needShowExtHints())
    }

    obj = handler.scene.findObject("ammo_load_nest")
    if (obj?.isValid()) {
      let isShowOption = this.isDmModeValidForXrayView() && this.canShowLoadedAmmo()
      obj.show(isShowOption)
      if (isShowOption) {
        local widget = this.getAmmoLoadWidget(obj)
        if (widget == null && obj.childrenCount() == 0) {
          widget = openXrayAmmoLoad({
            scene = obj
            btnWidth = "1@airInfoPanelDmSwitcherWidth"
            onShowLoadedAmmoChangeFn = function(value) {
              saveLocalAccountSettings("dmViewer/showLoadedAmmo", value)
              dmViewer.repaint()
            }
          })
          this.ammoLoadWidgets.append(widget.weakref())
        }
        widget?.updateAmmo(this.unit, this.getLoadedAmmo(), this.needShowLoadedAmmo())
      }
      else
        this.getAmmoLoadWidget(obj)?.closePopup()
    }
    this.updateXrayAmmoCount()

    
    obj = handler.scene.findObject("btn_dm_viewer")
    if (!checkObj(obj))
      return

    let modeNameCur  = this.modes[ dmViewerStorage.view_mode  ]
    let modeNameNext = this.modes[ (dmViewerStorage.view_mode + 1) % this.modes.len() ]

    obj.tooltip = loc($"mainmenu/viewDamageModel/tooltip_{modeNameNext}")
    obj.setValue(loc($"mainmenu/btn_dm_viewer_{modeNameNext}"))

    let objIcon = obj.findObject("btn_dm_viewer_icon")
    if (checkObj(objIcon))
      objIcon["background-image"] = $"#ui/gameuiskin#btn_dm_viewer_{modeNameCur}.svg"
  }

  function clearHint() {
    this.updateHint({ thickness = 0, name = null, posX = 0, posY = 0 })
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

  function findDmPartAnimationInBlk(partType, blk) {
    if (blk == null)
      return null
    for (local i = 0; i < blk.blockCount(); i++) {
      let xrayDmPartBlk = blk.getBlock(i)
      if (xrayDmPartBlk?.animation && xrayDmPartBlk?.name && partType.startswith(xrayDmPartBlk.name))
        return xrayDmPartBlk.animation
    }
    return null
  }

  function getDmPartAnimationSrc(partType, unit, unitBlk) {
    let foundUnitAnim = this.findDmPartAnimationInBlk(partType, unitBlk?.viewer_xray_animations)
    if (foundUnitAnim)
      return foundUnitAnim

    let gameParamsXrayKey = unit.isAir() ? "armorPartNamesAir" : "armorPartNamesGround"
    let gameParamsXrayBlk = get_game_params_blk()[gameParamsXrayKey].viewer_xray

    return this.findDmPartAnimationInBlk(partType, gameParamsXrayBlk)
  }

  function updateHint(params) {
    if (!dmViewerStorage.active) {
      if (this.hasPrevHint()) {
        this.resetPrevHint()
        let hintObj = this.getHintObj()
        if (hintObj)
          hintObj.show(false)
      }
      return
    }

    if (this.isDebugBatchExportProcess && params?.name != null)
      return

    local needUpdatePos = false
    local needUpdateContent = false

    let partName = params?.name ?? ""
    let unitXrayData = this.getUnitXrayData(params?.unit_name)
    let partType = this.isDmModeValidForXrayView() ? getPartType(partName, unitXrayData.xrayRemap) : partName

    if (this.isDmModeValidForXrayView() || (params?.weapon_item_desc ?? false)) {
      
      let prev = this.prevHintParams
      needUpdateContent = ((params?.name ?? true) != (prev?.name ?? false))
        || params?.unit_name != prev?.unit_name
        || (partType == "armor"
          && armorHintParams.findindex(@(key) params?[key] != prev?[key]) != null)
    }
    else
      foreach (key, val in params)
        if (val != this.prevHintParams?[key]) {
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

    let isVisible = partType != ""
    obj.show(isVisible)
    if (!isVisible)
      return

    let handler = handlersManager.getActiveBaseHandler()
    local info = { title = "", desc = [] }
    let isUseCache = this.isDmModeValidForXrayView() && !dmViewerStorage.isDebugMode && partType != "armor"
    let cacheKey = $"{unitXrayData.unit?.name}/{partName}"

    if (isUseCache && (cacheKey in this.xrayDescriptionCache))
      info = this.xrayDescriptionCache[cacheKey]
    else {
      info = this.getPartTooltipInfo(partType, params)
      info.title = info.title.replace(" ", nbsp)

      if (isUseCache)
        this.xrayDescriptionCache[cacheKey] <- info
    }

    obj.findObject("dmviewer_title").setValue(info.title)
    let descObj = obj.findObject("dmviewer_desc")
    if (info.desc != null) {
      let items = info.desc.map(@(v) "value" in v ? v : { value = v })
      let data = handyman.renderCached("%gui/dmViewer/dmViewerHintDescItem.tpl", { items })
      handler.guiScene.replaceContentFromText(descObj, data, data.len(), handler)

      obj.findObject("topValueHint").show(info.desc.findindex(@(v) "topValue" in v) != null)
    }

    let debugStr = params?.raw_name ?? (dmViewerStorage.isDebugMode ? partName : null)
    let isShowDebugStr = debugStr != null
    let debugTxtObj = obj.findObject("dmviewer_debug")
    debugTxtObj.show(isShowDebugStr)
    if (isShowDebugStr) {
      let weapTriggerTxt = ("weapon_trigger" in params)
        ? colorize("warningTextColor", $" + {params.weapon_trigger}")
        : ""
      debugTxtObj.setValue("".concat(colorize("badTextColor", debugStr), weapTriggerTxt))
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

  function getPartTooltipInfo(partType, params) {
    let res = {
      title       = ""
      shortDesc   = ""
      desc        = []
      extDesc     = ""
      extIcon     = ""
      extShortcut = ""
      animation   = null
    }

    let viewMode = params?.viewMode ?? dmViewerStorage.view_mode
    let { unit, simUnitType, unitBlk, unitDataCache, xrayRemap } = this.getUnitXrayData(params?.unit_name)

    if (partType == null) {
      let partName = params?.name ?? ""
      partType = this.isDmModeValidForXrayView(viewMode) ? getPartType(partName, xrayRemap) : partName
    }

    if (partType == "")
      return res

    if (this.isXrayBreechShown && partType == "cannon_breech" && this.isDmModeValidForXrayView(viewMode))
      return res.__update({
        title = loc("xray/ammo/loaded_in_gun")
        desc = [loc("xray/ammo/loaded_in_gun/desc")]
      })

    local partLocId = partType
    let { overrideTitle = "", hideDescription = false } = unitBlk?.xrayOverride[params.name]

    if (params?.weapon_item_desc ?? false)
      return this.getDescriptionWeaponItem(params)
    else if (viewMode == DM_VIEWER_ARMOR || (this.isDmModeValidForXrayView(viewMode) && partType == "armor"))
      res.desc = this.getDescriptionInArmorMode(params)
    else if (this.isDmModeValidForXrayView(viewMode)) {
      let supportPlaneName = unitBlk?.supportPlane.supportPlaneClass
      let supportPlane = supportPlaneName ? getAircraftByName(supportPlaneName) : null
      let descData = getDescriptionInXrayMode(partType, params, {
        unit
        unitName = unit?.name ?? ""
        simUnitType
        unitBlk
        unitDataCache
        crewId = this.crew?.id ?? -1
        ediff = this.ediff
        difficulty = this.difficulty
        armorClassToSteel = this.armorClassToSteel
        isSecondaryModsValid = this.isSecondaryModsValid
        isDebugBatchExportProcess = this.isDebugBatchExportProcess
        supportPlane
      }.__update(xrayCommonGetters))

      partLocId = descData.partLocId
      res.desc = !hideDescription && hasFeature("XRayDescription") ? descData.desc
        : descData.desc.filter(@(v) v?.isDevParam ?? false)
      res.animation = this.getDmPartAnimationSrc(params.name, unit, unitBlk)
      res.__update(this.getExtendedHintInfo(partType, params))
    }

    let titleLocId = overrideTitle != "" ? overrideTitle : partLocId
    res.title = getPartNameLocText(titleLocId, simUnitType)
    res.shortDesc = getPartNameDescLocText(titleLocId)

    return res
  }

  function getExtendedHintInfo(partType, params) {
    if (!this.unit?.isShipOrBoat() || !this.unitBlk)
      return {}

    if (!this.needShowExtHints())
      return {}

    if (!hasFeature("XRayDescription") || !params?.name)
      return {}

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
      if (ammo?.entityMunition != "torpedo") 
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

    let solid = params?.solid
    let variableThickness = params?.variable_thickness
    let thickness = params?.thickness ?? 0.0
    let effectiveThickness = params?.effective_thickness

    if (solid && variableThickness) {
      desc.append(loc("armor_class/variable_thickness_armor"))
    }
    else if (thickness) {
      let thicknessStr = thickness.tostring()
      desc.append("".concat(loc("armor_class/thickness"), nbsp,
        colorize("activeTextColor", thicknessStr), nbsp, loc("measureUnits/mm")))
    }

    let normalAngleValue = params?.normal_angle
    if (normalAngleValue != null)
      desc.append("".concat(loc("armor_class/normal_angle"), nbsp,
        (normalAngleValue + 0.5).tointeger(), nbsp, loc("measureUnits/deg")))

    let angleValue = params?.angle
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

    return desc
  }

  function getDescriptionWeaponItem(params) {
    let res = {
      title       = ""
      desc        = []
      extDesc     = ""
      extIcon     = ""
      extShortcut = ""
      animation   = null
    }

    res.title = loc("".concat("modification/", params.name))
    res.desc.append(loc("".concat("modification/", params.name, "/desc")))

    return res
  }

  function showExternalPartsArmor(isShow) {
    dmViewerStorage.isVisibleExternalPartsArmor = isShow
    hangar_show_external_dm_parts_change(isShow)
  }

  function onEventActiveHandlersChanged(_p) {
    this.loadedAmmo = null
    this.update()
  }

  function onEventHangarModelLoading(_p) {
    this.reinit()
  }

  function onEventHangarModelLoaded(_p) {
    this.appliedXrayAmmo = null
    this.reinit()
  }

  function onEventXrayFilterChanged(_p) {
    this.updateUnitInfo()
    this.updateXrayAmmoCount()
  }

  function onUnitBulletsEvent(p) {
    if (p?.unit != this.unit || this.isLoadedAmmoLoading)
      return
    this.loadedAmmo = null
    this.repaint()
  }

  onEventBulletsCountChanged = @(p) this.onUnitBulletsEvent(p)
  onEventUnitBulletsChanged = @(p) this.onUnitBulletsEvent(p)
  onEventBulletsGroupsChanged = @(p) this.onUnitBulletsEvent(p)

  function onEventUnitModsRecount(p) {
    if (p?.unit != this.unit)
      return
    this.updateSecondaryMods()
    this.resetXrayCache()
    this.loadedAmmo = null
  }

  function onEventUnitWeaponChanged(p) {
    if (!this.unit || p?.unitName != this.unit.name)
      return
    this.resetXrayCache()
    this.loadedAmmo = null
  }

  function onEventCurrentGameModeIdChanged(_p) {
    this.ediff = getCurrentGameModeEdiff()
    this.difficulty = get_difficulty_by_ediff(this.ediff)
    this.resetXrayCache()
  }

  function onEventModificationChanged(_p) {
    this.resetXrayCache()
    this.loadedAmmo = null
  }

  onEventGameLocalizationChanged = @(_p) this.resetXrayCache()
  onEventDebugXrayModeChange = @(_p) this.resetXrayCache()
  onEventMainMenuReturn = @(_p) this.restoreSavedViewMode()
  function onEventSignOut(_p) {
    dmViewerStorage.viewModeForRestore = null
    this.unit = null
  }
}

subscribe_handler(dmViewer, g_listener_priority.DEFAULT_HANDLER)

eventbus_subscribe("on_hangar_damage_part_pick", @(p) dmViewer.updateHint(p))

register_command(@() dmViewerStorage.isDebugMode = !dmViewerStorage.isDebugMode, "ui.debug.dm_viewer")

return dmViewer
