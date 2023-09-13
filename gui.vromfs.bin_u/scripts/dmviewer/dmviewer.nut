//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let DataBlock = require("DataBlock")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let regexp2 = require("regexp2")
let { abs, round, sin, PI } = require("math")
let { hangar_get_current_unit_name, hangar_set_dm_viewer_mode,
  hangar_get_dm_viewer_parts_count } = require("hangar")
let { blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { getParametersByCrewId } = require("%scripts/crew/crewSkillParameters.nut")
let { getWeaponXrayDescText } = require("%scripts/weaponry/weaponryDescription.nut")
let { KGF_TO_NEWTON, isCaliberCannon, getCommonWeapons, getLastPrimaryWeapon,
  getPrimaryWeaponsList, getWeaponNameByBlkPath } = require("%scripts/weaponry/weaponryInfo.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { doesLocTextExist } = require("dagor.localize")
let { hasLoadedModel } = require("%scripts/hangarModelLoadManager.nut")
let { unique } = require("%sqstd/underscore.nut")
let { fileName } = require("%sqstd/path.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { TIME_DAY_IN_SECONDS } = require("%scripts/time.nut")
let { utf8ToUpper, startsWith, utf8ToLower } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { shopIsModificationEnabled } = require("chardResearch")

/*
  dmViewer API:

  toggle(state = null)  - switch view_mode to state. if state == null view_mode will be increased by 1
  update()              - update dm viewer active status
                          depend on canShowDmViewer function in cur_base_gui_handler and topMenuHandler
                          and modal windows.
*/

let countMeasure = require("%scripts/options/optionsMeasureUnits.nut").countMeasure

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

::on_check_protection <- function(params) { // called from client
  broadcastEvent("ProtectionAnalysisResult", params)
}

let function isViewModeTutorAvailableForUser() {
  if (!::my_stats.isStatsLoaded())
    return false

  local res = loadLocalAccountSettings("tutor/dmViewer/isAvailable")
  if (res == null) {
    res = ::my_stats.isMeNewbieOnUnitType(ES_UNIT_TYPE_SHIP)
    saveLocalAccountSettings("tutor/dmViewer/isAvailable", res)
  }
  return res
}

let descByPartId = {
  tank = {
    function getTitle(params, unit) {
       let manufacturer = unit?.info[params.name].manufacturer ?? unit?.info.tanks_params.manufacturer
       return manufacturer == null ? null : loc($"armor_class/{manufacturer}")
    }
  }
}

let function distanceToStr(val) {
  return ::g_measure_type.DISTANCE.getMeasureUnitsText(val)
}

::dmViewer <- {
  [PERSISTENT_DATA_PARAMS] = [ "active", "view_mode", "_currentViewMode", "isDebugMode",
    "isVisibleExternalPartsArmor", "isVisibleExternalPartsXray" ]

  active = false
  // This is saved view mode. It is used to restore
  // view mode after player returns from somewhere.
  view_mode = DM_VIEWER_NONE
  unit = null
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
  isVisibleExternalPartsXray  = true

  prevHintParams = {}

  screen = [ 0, 0 ]
  unsafe = [ 0, 0 ]
  offset = [ 0, 0 ]

  absoluteArmorThreshold = 500
  relativeArmorThreshold = 5.0

  showStellEquivForArmorClassesList = []
  armorClassToSteel = null

  prepareNameId = [
    { pattern = regexp2(@"_l_|_r_"),   replace = "_" },
    { pattern = regexp2(@"[0-9]|dm$"), replace = "" },
    { pattern = regexp2(@"__+"),       replace = "_" },
    { pattern = regexp2(@"_+$"),       replace = "" },
  ]

  crewMemberToRole = {
    commander = "commander"
    driver = "driver"
    gunner_tank = "tank_gunner"
    loader = "loader"
    machine_gunner = "radio_gunner"
  }

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
    this.isSecondaryModsValid = ::check_unit_mods_update(this.unit)
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
    if (!::g_login.isLoggedIn())
      return

    this.updateUnitInfo()
    this.update()
  }

  function updateUnitInfo(fircedUnitId = null) {
    let unitId = fircedUnitId || hangar_get_current_unit_name()
    if (this.unit && unitId == this.unit.name)
      return
    this.unit = getAircraftByName(unitId)
    if (! this.unit)
      return
    this.crew = ::getCrewByAir(this.unit)
    this.loadUnitBlk()
    let map = getTblValue("xray", this.unitBlk)
    this.xrayRemap = map ? map.map(@(val) val) : {}
    this.armorClassToSteel = this.collectArmorClassToSteelMuls()
    this.resetXrayCache()
    this.clearHint()
    this.difficulty = ::get_difficulty_by_ediff(::get_current_ediff())
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
    this.unitBlk = ::get_full_unit_blk(this.unit.name)
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
            if (slotPresetBlk?.sensors)
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

    if (!::g_login.isProfileReceived())
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

    if (!::my_stats.isStatsLoaded() || ::my_stats.isMeNewbieOnUnitType(ES_UNIT_TYPE_SHIP))
      return

    let needHasArmor = modeId == DM_VIEWER_ARMOR
    if (needHasArmor) {
      let hasArmor = ::get_unittags_blk()?[this.unit.name].Shop.armorThicknessCitadel != null
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
      shortcut = ::GAMEPAD_ENTER_SHORTCUT
      cb = @() listObj?.isValid() && listObj.setValue(modeId)
    }]
    ::gui_modal_tutor(steps, handler, true)
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

    // Outer parts visibility toggle in Armor and Xray modes
    if (hasFeature("DmViewerExternalArmorHiding")) {
      let isTankOrShip = this.unit != null && (this.unit.isTank() || this.unit.isShipOrBoat())
      obj = handler.scene.findObject("dmviewer_show_external_dm")
      if (checkObj(obj)) {
        let isShowOption = this.view_mode == DM_VIEWER_ARMOR && isTankOrShip
        obj.show(isShowOption)
        if (isShowOption)
          obj.setValue(this.isVisibleExternalPartsArmor)
      }
      obj = handler.scene.findObject("dmviewer_show_extra_xray")
      if (checkObj(obj)) {
        let isShowOption = this.view_mode == DM_VIEWER_XRAY && isTankOrShip
        obj.show(isShowOption)
        if (isShowOption)
          obj.setValue(this.isVisibleExternalPartsXray)
      }
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

    obj.tooltip = loc("mainmenu/viewDamageModel/tooltip_" + modeNameNext)
    obj.setValue(loc("mainmenu/btn_dm_viewer_" + modeNameNext))

    let objIcon = obj.findObject("btn_dm_viewer_icon")
    if (checkObj(objIcon))
      objIcon["background-image"] = "#ui/gameuiskin#btn_dm_viewer_" + modeNameCur + ".svg"
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

    let nameId = this.getPartNameId(params)
    let isVisible = nameId != ""
    obj.show(isVisible)
    if (!isVisible)
      return

    local info = { title = "", desc = "" }
    let isUseCache = this.view_mode == DM_VIEWER_XRAY && !this.isDebugMode
    let cacheId = getTblValue("name", params, "")

    if (isUseCache && (cacheId in this.xrayDescriptionCache))
      info = this.xrayDescriptionCache[cacheId]
    else {
      info = this.getPartTooltipInfo(nameId, params)
      info.title = ::stringReplace(info.title, " ", ::nbsp)
      info.desc  = ::stringReplace(info.desc,  " ", ::nbsp)

      if (isUseCache)
        this.xrayDescriptionCache[cacheId] <- info
    }

    obj.findObject("dmviewer_title").setValue(info.title)

    let descObj = obj.findObject("dmviewer_desc")
    descObj.setValue(info.desc)

    let needShowExtHint = info.extDesc != ""
    let extHintObj = obj.findObject("dmviewer_ext_hint")
    extHintObj.show(needShowExtHint)
    if (needShowExtHint) {
      let handler = handlersManager.getActiveBaseHandler()
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

  function getPartNameId(params) {
    local nameId = getTblValue("name", params) || ""
    if (this.view_mode != DM_VIEWER_XRAY || nameId == "")
      return nameId

    nameId = getTblValue(nameId, this.xrayRemap, nameId)
    foreach (re in this.prepareNameId)
      nameId = re.pattern.replace(re.replace, nameId)
    if (nameId == "gunner")
      nameId += "_" + ::getUnitTypeTextByUnit(this.unit).tolower()
    return nameId
  }

  function getPartNameLocText(nameId) {
    local localizedName = ""
    let localizationSources = ["armor_class/", "dmg_msg_short/", "weapons_types/"]
    let nameVariations = [nameId]
    let idxSeparator = nameId.indexof("_")
    if (idxSeparator)
      nameVariations.append(nameId.slice(0, idxSeparator))
    if (this.unit != null)
      nameVariations.append(::getUnitTypeText(this.unit.esUnitType).tolower() + "_" + nameId)
    if (this.unit?.esUnitType == ES_UNIT_TYPE_BOAT)
      nameVariations.append($"ship_{nameId}")

    foreach (localizationSource in localizationSources)
      foreach (nameVariant in nameVariations) {
        let locId = "".concat(localizationSource, nameVariant)
        localizedName = doesLocTextExist(locId) ? loc(locId, "") : ""
        if (localizedName != "")
          return utf8ToUpper(localizedName, 1);
      }
    return nameId
  }

  function getPartTitle(params, unit) {
    let partId = params?.nameId ?? ""
    return descByPartId?[partId].getTitle(params, unit) ?? this.getPartNameLocText(params?.partLocId ?? partId)
  }

  function getPartLocNameByBlkFile(locKeyPrefix, blkFilePath, blk) {
    let nameLocId = $"{locKeyPrefix}/{blk?.nameLocId ?? fileName(blkFilePath).slice(0, -4)}"
    return doesLocTextExist(nameLocId) ? loc(nameLocId) : (blk?.name ?? nameLocId)
  }

  function getPartTooltipInfo(nameId, params) {
    let res = {
      title       = ""
      desc        = ""
      extDesc     = ""
      extIcon     = ""
      extShortcut = ""
    }

    let isHuman = nameId == "steel_tankman"
    if (isHuman || nameId == "")
      return res

    params.nameId <- nameId

    switch (this.view_mode) {
      case DM_VIEWER_ARMOR:
        res.desc = this.getDescriptionInArmorMode(params)
        break
      case DM_VIEWER_XRAY:
        res.desc = this.getDescriptionInXrayMode(params)
        res.__update(this.getExtendedHintInfo(params))
        break
    }

    res.title = this.getPartTitle(params, this.unit)

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
      extIcon = this.getExtHintIcon(partType)
    }
  }

  function getExtHintIcon(partType) {
    switch (partType) {
      case "ammo_turret":
        return "#ui/gameuiskin#icon_weapons_relocation_in_progress.svg"

      case "bridge":
        return "#ui/gameuiskin#ship_crew_driver.svg"

      case "engine_room":
        return "#ui/gameuiskin#engine_state_indicator.svg"

      case "shaft":
      case "transmission":
        return "#ui/gameuiskin#ship_transmission_state_indicator.svg"

      case "steering_gear":
        return "#ui/gameuiskin#ship_steering_gear_state_indicator.svg"

      case "ammunition_storage":
      case "ammunition_storage_shells":
      case "ammunition_storage_charges":
      case "ammunition_storage_aux":
        return "#ui/gameuiskin#ship_ammo_wetting"
    }
    return ""
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
    switch (partType) {
      case "shaft":
      case "ammo_turret":
      case "pump":
      case "bridge":
      case "radio_station":
      case "fire_control_room":
      case "aircraft":
      case "engine_room":
      case "transmission":
      case "funnel":
      case "steering_gear":
      case "fuel_tank":
      case "coal_bunker":
      case "mine":
      case "depth_charge":
      case "torpedo":
      case "elevator":
      case "tt":
      case "antenna_target_location":
      case "ammunition_storage":
      case "antenna_target_tagging":
      case "fire_director":
      case "rangefinder":
      case "catapult":
        return partType != "torpedo" || this.isStockTorpedo(partName)
          ? $"xray_ext_hint/{partType}"
          : ""

      case "main_caliber_turret":
      case "auxiliary_caliber_turret":
      case "aa_turret":
        return "xray_ext_hint/turret"

      case "engine":
        return "xray_ext_hint/engine_room"

      case "catapult_mount":
        return "xray_ext_hint/catapult"

      case "ammunition_storage_shells":
      case "ammunition_storage_charges":
      case "ammunition_storage_aux":
        return "xray_ext_hint/ammunition_storage"

      case "antenna_target_tagging_mount":
        return "xray_ext_hint/antenna_target_tagging"

      case "fire_director_mount":
        return "xray_ext_hint/fire_director"

      case "rangefinder_mount":
        return "xray_ext_hint/rangefinder"
    }
    return ""
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
      desc.append(loc("armor_class/thickness") + ::nbsp +
        colorize("activeTextColor", thicknessStr) + ::nbsp + loc("measureUnits/mm"))
    }

    let normalAngleValue = getTblValue("normal_angle", params, null)
    if (normalAngleValue != null)
      desc.append(loc("armor_class/normal_angle") + ::nbsp +
        (normalAngleValue + 0.5).tointeger() + ::nbsp + loc("measureUnits/deg"))

    let angleValue = getTblValue("angle", params, null)
    if (angleValue != null)
      desc.append(loc("armor_class/impact_angle") + ::nbsp + round(angleValue) + ::nbsp + loc("measureUnits/deg"))

    if (effectiveThickness) {
      if (solid) {
        desc.append(loc("armor_class/armor_dimensions_at_point") + ::nbsp +
          colorize("activeTextColor", round(effectiveThickness)) +
          ::nbsp + loc("measureUnits/mm"))

        if ((this.armorClassToSteel?[params.name] ?? 0) != 0) {
          let equivSteelMm = round(effectiveThickness * this.armorClassToSteel[params.name])
          desc.append(loc("shop/armorThicknessEquivalent/steel",
            { thickness = "".concat(colorize("activeTextColor", equivSteelMm), " ", loc("measureUnits/mm")) }))
        }
      }
      else {
        let effectiveThicknessClamped = min(effectiveThickness,
          min((this.relativeArmorThreshold * thickness).tointeger(), this.absoluteArmorThreshold))

        desc.append(loc("armor_class/effective_thickness") + ::nbsp +
          (effectiveThicknessClamped < effectiveThickness ? ">" : "") +
          round(effectiveThicknessClamped) + ::nbsp + loc("measureUnits/mm"))
      }
    }

    if (this.isDebugMode)
      desc.append("\n" + colorize("badTextColor", params.nameId))

    let rawPartName = getTblValue("raw_name", params)
    if (rawPartName)
      desc.append(rawPartName)

    return "\n".join(desc, true)
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
    if (blk.getBlockByName(blockName)?[paramName] == paramValue)
      return true
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

    local bands = indent + loc("radar_freq_band") + loc("ui/colon")
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
              bands = bands + loc(format("radar_freq_band_%d", bandStart)) + "-" + loc(format("radar_freq_band_%d", bandPrev)) + ", "
            else
              bands = bands + loc(format("radar_freq_band_%d", bandStart)) + ", "
            bandStart = band
          }
        }
      }
      let bandLast = bandsIndexes[bandsIndexes.len() - 1]
      if (bandLast > bandStart)
        bands = bands + loc(format("radar_freq_band_%d", bandStart)) + "-" + loc(format("radar_freq_band_%d", bandLast)) + " "
      else
        bands = bands + loc(format("radar_freq_band_%d", bandStart)) + " "
    }
    else
      bands = bands + loc(format("radar_freq_band_%d", bandsIndexes[0]))
    desc.append(bands)

    let rangeMax = sensorPropsBlk.getReal("range", 0.0)
    desc.append(indent + loc("radar_range_max") + loc("ui/colon") + distanceToStr(rangeMax))

    let detectTracking = sensorPropsBlk.getBool("detectTracking", true)
    let detectLaunch = sensorPropsBlk.getBool("detectLaunch", false)

    local launchingThreatTypes = {}
    let groupsBlk = sensorPropsBlk.getBlockByName("groups")
    if (!detectLaunch)
      for (local g = 0; g < (groupsBlk?.blockCount() ?? 0); g++) {
        let groupBlk = groupsBlk.getBlock(g)
        let detectGroupLaunching = !detectLaunch && groupBlk.getBool("detectLaunch", false)
        for (local t = 0; t < groupBlk.paramCount(); ++t)
          if (groupBlk.getParamName(t) == "type") {
            let threatType = groupBlk.getParamValue(t)
            if (detectGroupLaunching)
              if (!launchingThreatTypes?[threatType])
                launchingThreatTypes[threatType] <- true
          }
      }

    if (sensorPropsBlk.getBool("targetTracking", false))
      desc.append(indent + loc("rwr_tracked_threats_max") + loc("ui/colon") + format("%d", sensorPropsBlk.getInt("trackedTargetsMax", 16)))

    if (detectTracking)
      desc.append(indent + loc("rwr_tracking_detection"))

    if (detectLaunch || launchingThreatTypes.len() > 3)
      desc.append(indent + loc("rwr_launch_detection"))

    local targetsDirectionGroups = {}
    let targetsDirectionGroupsBlk = sensorPropsBlk.getBlockByName("targetsDirectionGroups")
    for (local d = 0; d < (targetsDirectionGroupsBlk?.blockCount() ?? 0); d++) {
      let targetsDirectionGroupBlk = targetsDirectionGroupsBlk.getBlock(d)
      let targetsDirectionGroupText = targetsDirectionGroupBlk.getStr("text", "")
      if (!targetsDirectionGroups?[targetsDirectionGroupText])
        targetsDirectionGroups[targetsDirectionGroupText] <- true
    }
    if (targetsDirectionGroups.len() > 1)
      desc.append(indent + loc("rwr_scope_id_threats_types") + loc("ui/colon") + format("%d", targetsDirectionGroups.len()))

    let targetsPresenceGroupsBlk = sensorPropsBlk.getBlockByName("targetsPresenceGroups")
    let targetsPresenceGroupsCount = targetsPresenceGroupsBlk?.blockCount() ?? 0
    if (targetsPresenceGroupsCount > 1)
      desc.append(indent + loc("rwr_present_id_threats_types") + loc("ui/colon") + format("%d", targetsPresenceGroupsCount))
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

    local anglesFinder = false
    local iff = false
    local lookUp = false
    local lookDownHeadOn = false
    local lookDownAllAspects = false
    let signalsBlk = sensorPropsBlk.getBlockByName("signals")
    for (local s = 0; s < (signalsBlk?.blockCount() ?? 0); s++) {
      let signalBlk = signalsBlk.getBlock(s)
      anglesFinder = anglesFinder || signalBlk.getBool("anglesFinder", true)
      iff = iff || signalBlk.getBool("friendFoeId", false)
      let groundClutter = signalBlk.getBool("groundClutter", false)
      let distanceBlk = signalBlk.getBlockByName("distance")
      let dopplerSpeedBlk = signalBlk.getBlockByName("dopplerSpeed")
      if (dopplerSpeedBlk && dopplerSpeedBlk.getBool("presents", false)) {
        let dopplerSpeedMin = dopplerSpeedBlk.getReal("minValue", 0.0)
        let dopplerSpeedMax = dopplerSpeedBlk.getReal("maxValue", 0.0)
        if (signalBlk.getBool("mainBeamDopplerSpeed", false) &&
            !signalBlk.getBool("absDopplerSpeed", false) &&
            dopplerSpeedMax > 0.0 && (dopplerSpeedMin > 0.0 || dopplerSpeedMax > -dopplerSpeedMin * 0.25))
          lookDownHeadOn = true
        else if (groundClutter)
          lookDownHeadOn = true
        else
          lookDownAllAspects = true
      }
      else if (distanceBlk && distanceBlk.getBool("presents", false))
        lookUp = true
    }
    let isSearchRadar = this.findBlockByName(sensorPropsBlk, "addTarget")
    let hasTws = this.findBlockByName(sensorPropsBlk, "updateTargetOfInterest")
    let isTrackRadar = this.findBlockByName(sensorPropsBlk, "updateActiveTargetOfInterest")
    let hasSARH = this.findBlockByName(sensorPropsBlk, "setIllumination")
    let hasMG = this.findBlockByName(sensorPropsBlk, "setWeaponRcTransmissionTimeOut")

    local radarType = ""
    if (isRadar)
      radarType = "radar"
    if (isIrst) {
      if (radarType != "")
        radarType = radarType + "_"
      radarType = radarType + "irst"
    }
    if (isTv) {
      if (radarType != "")
        radarType = radarType + "_"
      radarType = radarType + "tv"
    }
    if (isSearchRadar && isTrackRadar)
      radarType = "" + radarType
    else if (isSearchRadar)
      radarType = "search_" + radarType
    else if (isTrackRadar) {
      if (anglesFinder)
        radarType = "track_" + radarType
      else
        radarType = radarType + "_range_finder"
    }
    desc.append(indent + loc("plane_engine_type") + loc("ui/colon") + loc(radarType))
    if (isRadar)
      desc.append(indent + loc("radar_freq_band") + loc("ui/colon") + loc(format("radar_freq_band_%d", radarFreqBand)))
    desc.append(indent + loc("radar_range_max") + loc("ui/colon") + distanceToStr(rangeMax))

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
    if (lookDownHeadOn)
      desc.append(indent + loc("radar_ld_head_on"))
    if (lookDownAllAspects) {
      if (this.unit != null && (this.unit.isTank() || this.unit.isShipOrBoat()))
        desc.append(indent + loc("radar_ld"))
      else
        desc.append(indent + loc("radar_ld_all_aspects"))
    }
    if ((lookDownHeadOn || lookDownAllAspects) && lookUp)
      desc.append(indent + loc("radar_lu"))
    if (iff)
      desc.append(indent + loc("radar_iff"))
    if (isSearchRadar && hasTws)
      desc.append(indent + loc("radar_tws"))
    if (isTrackRadar) {
      let hasBVR = this.findBlockByNameWithParamValue(sensorPropsBlk, "setDistGatePos", "source", "targetDesignation")
      if (hasBVR)
        desc.append(indent + loc("radar_bvr_mode"))
      let hasACM = this.findBlockByNameWithParamValue(sensorPropsBlk, "setDistGatePos", "source", "constRange")
      if (hasACM)
        desc.append(indent + loc("radar_acm_mode"))
      if (hasSARH)
        desc.append(indent + loc("radar_sarh"))
      if (hasMG)
        desc.append(indent + loc("radar_mg"))
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

    switch (partId) {
      case "commander":
      case "driver":
      case "gunner_tank":
      case "machine_gunner":
      case "loader":
        if (this.unit.esUnitType != ES_UNIT_TYPE_TANK)
          break
        let memberBlk = this.getCrewMemberBlkByDMPart(this.unitBlk.tank_crew, partName)
        if (!memberBlk)
          break
        let memberRole = this.crewMemberToRole[partId]
        let duplicateRoles = (memberBlk % "role")
          .filter(@(r) r != memberRole)
          .map(@(r) loc($"duplicate_role/{r}", ""))
          .filter(@(n) n != "")
        desc.extend(duplicateRoles)
        break

      case "engine":              // Engines
        switch (this.unit.esUnitType) {
          case ES_UNIT_TYPE_TANK:
            let infoBlk = this.findAnyModEffectValue("engine") ?? this.unitBlk?.VehiclePhys.engine
            if (infoBlk) {
              let engineModelName = this.getEngineModelName(infoBlk)
              desc.append(engineModelName)

              let engineConfig = []
              let engineType = infoBlk?.type ?? (engineModelName != "" ? "diesel" : "")
              if (engineType != "")
                engineConfig.append(loc($"engine_type/{engineType}"))
              if (infoBlk?.configuration)
                engineConfig.append(loc("engine_configuration/" + infoBlk.configuration))
              let typeText = loc("ui/comma").join(engineConfig, true)
              if (typeText != "")
                desc.append("".concat(loc("plane_engine_type"), loc("ui/colon"), typeText))

              if (infoBlk?.displacement)
                desc.append(loc("engine_displacement")
                          + loc("ui/colon")
                          + loc("measureUnits/displacement", { num = infoBlk.displacement.tointeger() }))
            }

            if (! this.isSecondaryModsValid)
              this.updateSecondaryMods()

            let currentParams = this.unit?.modificators[this.difficulty.crewSkillName]
            if (this.isSecondaryModsValid && currentParams && currentParams.horsePowers && currentParams.maxHorsePowersRPM) {
              desc.append(format("%s %s (%s %d %s)", loc("engine_power") + loc("ui/colon"),
                ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(currentParams.horsePowers),
                loc("shop/unitValidCondition"), currentParams.maxHorsePowersRPM.tointeger(), loc("measureUnits/rpm")))
            }
            if (infoBlk)
              desc.append(this.getMassInfo(infoBlk))
          break;

          case ES_UNIT_TYPE_AIRCRAFT:
          case ES_UNIT_TYPE_HELICOPTER:
            local partIndex = to_integer_safe(this.trimBetween(partName, "engine", "_"), -1, false)
            if (partIndex <= 0)
              break

            let fmBlk = ::get_fm_file(this.unit.name, this.unitBlk)
            if (!fmBlk)
              break

            partIndex-- //engine1_dm -> Engine0

            let infoBlk = this.getInfoBlk(partName)
            desc.append(this.getEngineModelName(infoBlk))

            let enginePartId = infoBlk?.part_id ?? ("Engine" + partIndex.tostring())
            let engineTypeId = "EngineType" + (fmBlk?[enginePartId].Type ?? -1).tostring()
            local engineBlk = fmBlk?[engineTypeId] ?? fmBlk?[enginePartId]
            if (!engineBlk) { // try to find booster
              local numEngines = 0
              while (("Engine" + numEngines) in fmBlk)
                numEngines ++
              let boosterPartIndex = partIndex - numEngines //engine3_dm -> Booster0
              engineBlk = fmBlk?[$"Booster{boosterPartIndex}"]
            }
            let engineMainBlk = engineBlk?.Main

            if (!engineMainBlk)
              break
            let engineInfo = []
            local engineType = this.getFirstFound([infoBlk, engineMainBlk], @(b) b?.Type ?? b?.type, "").tolower()
            if (this.unit.esUnitType == ES_UNIT_TYPE_HELICOPTER && engineType == "turboprop")
              engineType = "turboshaft"
            if (engineType != "")
              engineInfo.append(loc($"plane_engine_type/{engineType}"))
            if (engineType == "inline" || engineType == "radial") {
              let cylinders = this.getFirstFound([infoBlk, engineMainBlk], @(b) b?.Cylinders ?? b?.cylinders, 0)
              if (cylinders > 0)
                engineInfo.append(cylinders + loc("engine_cylinders_postfix"))
            }
            let typeText = loc("ui/comma").join(engineInfo, true)
            if (typeText != "")
              desc.append("".concat(loc("plane_engine_type"), loc("ui/colon"), typeText))

            // display cooling type only for Inline and Radial engines
            if ((engineType == "inline" || engineType == "radial")
                && "IsWaterCooled" in engineMainBlk) {           // Plane : Engine : Cooling
              let coolingKey = engineMainBlk?.IsWaterCooled ? "water" : "air"
              desc.append(loc("plane_engine_cooling_type") + loc("ui/colon")
              + loc("plane_engine_cooling_type_" + coolingKey))
            }

            if (!this.isSecondaryModsValid) {
              this.updateSecondaryMods()
              break;
            }
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
            switch (engineType) {
              case "inline":
              case "radial":
                if (throttleBoost > 1) {
                  powerMax = horsePowerValue
                  powerTakeoff = horsePowerValue * throttleBoost * afterburnerBoost
                }
                else
                  powerTakeoff = horsePowerValue
              break

              case "rocket":
                let sources = [infoBlk, engineMainBlk]
                let boosterMainBlk = fmBlk?["Booster" + partIndex].Main
                if (boosterMainBlk)
                  sources.insert(1, boosterMainBlk)
                thrustTakeoff = this.getFirstFound(sources, @(b) b?.Thrust ?? b?.thrust, 0)
              break

              case "turboprop":
                  powerMax = horsePowerValue
                  thrustMax = thrustValue * thrustMult
              break

              case "jet":
              case "pvrd":
              default:
                if (throttleBoost > 1 && afterburnerBoost > 1) {
                  thrustTakeoff = thrustValue * thrustTakeoffMult * afterburnerBoost
                  thrustMax = thrustValue * thrustMult
                }
                else
                  thrustTakeoff = thrustValue * thrustTakeoffMult
              break
            }

            // final values can be overriden in info block
            powerMax = getTblValue("power_max", infoBlk, powerMax)
            powerTakeoff = getTblValue("power_takeoff", infoBlk, powerTakeoff)
            thrustMax = getTblValue("thrust_max", infoBlk, thrustMax)
            thrustTakeoff = getTblValue("thrust_takeoff", infoBlk, thrustTakeoff)

            // display power values
            if (powerMax > 0) {
              powerMax += horsepowerModDelta
              desc.append(loc("engine_power_max") + loc("ui/colon")
                + ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(powerMax))
            }
            if (powerTakeoff > 0) {
              powerTakeoff += horsepowerModDelta
              desc.append(loc("engine_power_takeoff") + loc("ui/colon")
                + ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(powerTakeoff))
            }
            if (thrustMax > 0) {
              thrustMax += thrustModDelta
              thrustMax *= thrustMaxCoef
              desc.append(loc("engine_thrust_max") + loc("ui/colon")
                + ::g_measure_type.THRUST_KGF.getMeasureUnitsText(thrustMax))
            }
            if (thrustTakeoff > 0) {
              let afterburnerBlk = engineBlk?.Afterburner
              let thrustTakeoffLocId = (afterburnerBlk?.Type == AFTERBURNER_CHAMBER &&
                (afterburnerBlk?.IsControllable ?? false))
                  ? "engine_thrust_afterburner"
                  : "engine_thrust_takeoff"

              thrustTakeoff += thrustModDelta
              thrustTakeoff *= thrustMaxCoef * afterburneThrustMaxCoef
              desc.append(loc(thrustTakeoffLocId) + loc("ui/colon")
                + ::g_measure_type.THRUST_KGF.getMeasureUnitsText(thrustTakeoff))
            }

            // mass
            desc.append(this.getMassInfo(infoBlk))
          break;
        }
        break

      case "transmission":
        let info = this.unitBlk?.VehiclePhys?.mechanics
        if (info) {
          let manufacturer = info?.manufacturer ? loc("transmission_manufacturer/" + info.manufacturer,
            loc("engine_manufacturer/" + info.manufacturer, ""))
                               : ""
          let model = info?.model ? loc("transmission_model/" + info.model, "") : ""
          let props = info?.type ? utf8ToLower(loc("transmission_type/" + info.type, "")) : ""
          desc.append(" ".join([ manufacturer, model ], true) +
            (props == "" ? "" : loc("ui/parentheses/space", { text = props })))

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
              desc.append(loc("xray/transmission/maxSpeed/forward") + loc("ui/colon") +
                countMeasure(0, maxSpeedF) + loc("ui/comma") +
                  loc("xray/transmission/gears") + loc("ui/colon") + gearsF)
            if (maxSpeedB && gearsB)
              desc.append(loc("xray/transmission/maxSpeed/backward") + loc("ui/colon") +
                countMeasure(0, maxSpeedB) + loc("ui/comma") +
                  loc("xray/transmission/gears") + loc("ui/colon") + gearsB)
          }
        }
        break

      case "elevator":
      case "ammo_turret":
      case "ammo_body":
      case "ammunition_storage":
      case "ammunition_storage_shells":
      case "ammunition_storage_charges":
      case "ammunition_storage_aux":
        let isShipOrBoat = this.unit.isShipOrBoat()
        if (isShipOrBoat) {
          let ammoQuantity = this.getAmmoQuantityByPartName(partName)
          if (ammoQuantity > 1)
            desc.append(loc("shop/ammo") + loc("ui/colon") + ammoQuantity)
        }
        let stowageInfo = this.getAmmoStowageInfo(null, partName, isShipOrBoat)
        if (stowageInfo.isCharges)
          params.partLocId <- isShipOrBoat ? "ship_charges_storage" : "ammo_charges"
        if (stowageInfo.firstStageCount) {
          local txt = loc(isShipOrBoat ? "xray/ammo/first_stage_ship" : "xray/ammo/first_stage")
          if (this.unit.isTank())
            txt += loc("ui/comma") + stowageInfo.firstStageCount + " " + loc("measureUnits/pcs")
          desc.append(txt)
        }
        if (stowageInfo.isAutoLoad)
          desc.append(loc("xray/ammo/mechanized_ammo_rack"))
        break

      case "drive_turret_h":
      case "drive_turret_v":

        weaponPartName = ::stringReplace(partName, partId, "gun_barrel")
        let weaponInfoBlk = this.getWeaponByXrayPartName(weaponPartName, partName)
        if (! weaponInfoBlk)
          break
        let isHorizontal = partId == "drive_turret_h"
        desc.extend(this.getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, isHorizontal, !isHorizontal))
        break

      case "pilot":
      case "gunner_helicopter":
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

        if ((this.unitBlk?.haveOpticTurret || this.unit.esUnitType == ES_UNIT_TYPE_HELICOPTER) && this.unitBlk?.gunnerOpticFps != null)
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
          if (sensorType == "radar") {
            local isRadar = false
            local isIrst = false
            local isTv = false
            let transiversBlk = sensorPropsBlk.getBlockByName("transivers")
            for (local t = 0; t < (transiversBlk?.blockCount() ?? 0); t++) {
              let transiverBlk = transiversBlk.getBlock(t)
              let targetSignatureType = transiverBlk?.targetSignatureType != null ? transiverBlk?.targetSignatureType : transiverBlk?.visibilityType
              if (targetSignatureType == "infraRed")
                isIrst = true
              else if (targetSignatureType == "optic")
                isTv = true
              else
                isRadar = true
            }
            if (isRadar && isIrst)
              sensorType = "radar_irst"
            else if (isRadar)
              sensorType = "radar"
            else if (isIrst)
              sensorType = "irst"
            else if (isTv)
              sensorType = "tv"
          }
          else if (sensorType == "lds")
            continue
          desc.append("".concat(loc($"avionics_sensor_{sensorType}"), loc("ui/colon"),
            this.getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))
          if (sensorType == "rwr")
            this.addRwrDescription(sensorPropsBlk, "  ", desc)
        }

        if (this.unitBlk.getBool("hasHelmetDesignator", false))
          desc.append(loc("avionics_hmd"))
        if (this.unitBlk.getBool("havePointOfInterestDesignator", false) || this.unit.esUnitType == ES_UNIT_TYPE_HELICOPTER)
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
        break

      case "radar":
      case "antenna_target_location":
      case "antenna_target_tagging":
      case "antenna_target_tagging_mount":
      case "optic_gun":

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
        break

      case "countermeasure":

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
        break

      case "aps_sensor":
        let activeProtectionSystemBlk = this.unitBlk?.ActiveProtectionSystem
        if (activeProtectionSystemBlk)
          desc.extend(this.getAPSDesc(activeProtectionSystemBlk))
        break

      case "ex_aps_launcher":
      case "aps_launcher":
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
        break

      case "main_caliber_turret":
      case "auxiliary_caliber_turret":
      case "aa_turret":
        weaponPartName = ::stringReplace(partName, "turret", "gun")
        foreach (weapon in this.getUnitWeaponList())
          if (weapon?.turret?.gunnerDm == partName && weapon?.breechDP) {
            weaponPartName = weapon.breechDP
            break
          }
        // No break!

      case "mg": // warning disable: -missed-break
      case "gun":
      case "mgun":
      case "cannon":
      case "mask":
      case "gun_mask":
      case "gun_barrel":
      case "cannon_breech":
      case "tt":
      case "torpedo":
      case "main_caliber_gun":
      case "auxiliary_caliber_gun":
      case "depth_charge":
      case "mine":
      case "aa_gun":

        local weaponInfoBlk = null
        let weaponTrigger = getTblValue("weapon_trigger", params)
        let triggerParam = "trigger"
        if (weaponTrigger) {
          let weaponList = this.getUnitWeaponList()
          foreach (weapon in weaponList) {
            if (triggerParam in weapon && weapon[triggerParam] == weaponTrigger) {
              weaponInfoBlk = weapon
              break
            }
          }
        }

        if (!weaponInfoBlk) {
          weaponPartName = weaponPartName || partName
          weaponInfoBlk = this.getWeaponByXrayPartName(weaponPartName)
        }

        if (! weaponInfoBlk)
          break

        let isSpecialBullet = isInArray(partId, [ "torpedo", "depth_charge", "mine" ])
        let isSpecialBulletEmitter = isInArray(partId, [ "tt" ])

        let weaponBlkLink = weaponInfoBlk?.blk ?? ""
        let weaponName = getWeaponNameByBlkPath(weaponBlkLink)

        let ammo = isSpecialBullet ? 1 : this.getWeaponTotalBulletCount(partId, weaponInfoBlk)
        let shouldShowAmmoInTitle = isSpecialBulletEmitter
        let ammoTxt = ammo > 1 && shouldShowAmmoInTitle ? format(loc("weapons/counter"), ammo) : ""

        if (weaponName != "")
          desc.append("".concat(loc($"weapons/{weaponName}"), ammoTxt))
        if (weaponInfoBlk && ammo > 1 && !shouldShowAmmoInTitle)
          desc.append(loc("shop/ammo") + loc("ui/colon") + ammo)

        if (isSpecialBullet || isSpecialBulletEmitter)
          desc[desc.len() - 1] += getWeaponXrayDescText(weaponInfoBlk, this.unit, ::get_current_ediff())
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
      break;

      case "tank":                     // aircraft fuel tank (tank's fuel tank is 'fuel_tank')
        local tankInfoTable = this.unit?.info?[params.name]
        if (!tankInfoTable)
          tankInfoTable = this.unit?.info?.tanks_params
        if (!tankInfoTable)
          break

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

      break

      case "composite_armor_hull":            // tank Composite armor
      case "composite_armor_turret":          // tank Composite armor
      case "ex_era_hull":                     // tank Explosive reactive armor
      case "ex_era_turret":                   // tank Explosive reactive armor
        let info = this.getModernArmorParamsByDmPartName(partName)

        let strUnits = ::nbsp + loc("measureUnits/mm")
        let strBullet = loc("ui/bullet")
        let strColon  = loc("ui/colon")

        if (info.titleLoc != "")
          params.nameId <- info.titleLoc

        foreach (data in info.referenceProtectionArray) {
          if (u.isPoint2(data.angles))
            desc.append(loc("shop/armorThicknessEquivalent/angles",
              { angle1 = abs(data.angles.y), angle2 = abs(data.angles.x) }))
          else
            desc.append(loc("shop/armorThicknessEquivalent"))

          if (data.kineticProtectionEquivalent)
            desc.append(strBullet + loc("shop/armorThicknessEquivalent/kinetic") + strColon +
              round(data.kineticProtectionEquivalent) + strUnits)
          if (data.cumulativeProtectionEquivalent)
            desc.append(strBullet + loc("shop/armorThicknessEquivalent/cumulative") + strColon +
              round(data.cumulativeProtectionEquivalent) + strUnits)
        }

        let blockSep = desc.len() ? "\n" : ""

        if (info.isComposite && !u.isEmpty(info.layersArray)) { // composite armor
          let texts = []
          foreach (layer in info.layersArray) {
            local thicknessText = ""
            if (u.isFloat(layer?.armorThickness) && layer.armorThickness > 0)
              thicknessText = round(layer.armorThickness).tostring()
            else if (u.isPoint2(layer?.armorThickness) && layer.armorThickness.x > 0 && layer.armorThickness.y > 0)
              thicknessText = round(layer.armorThickness.x).tostring() + loc("ui/mdash") + round(layer.armorThickness.y).tostring()
            if (thicknessText != "")
              thicknessText = loc("ui/parentheses/space", { text = thicknessText + strUnits })
            texts.append(strBullet + this.getPartNameLocText(layer?.armorClass) + thicknessText)
          }
          desc.append(blockSep + loc("xray/armor_composition") + loc("ui/colon") + "\n" + "\n".join(texts, true))
        }
        else if (!info.isComposite && !u.isEmpty(info.armorClass)) // reactive armor
          desc.append(blockSep + loc("plane_engine_type") + loc("ui/colon") + this.getPartNameLocText(info.armorClass))

        break

      case "coal_bunker":
        let coalToSteelMul = this.armorClassToSteel?["ships_coal_bunker"] ?? 0
        if (coalToSteelMul != 0)
          desc.append(loc("shop/armorThicknessEquivalent/coal_bunker",
            { thickness = "".concat(round(coalToSteelMul * 1000).tostring(), " ", loc("measureUnits/mm")) }))
        break

      case "commander_panoramic_sight":
        if (this.unitBlk?.commanderView)
          desc.extend(this.getOpticsDesc(this.unitBlk.commanderView))
        break

      case "rangefinder":
      case "fire_director":
        // "partName" node may belong to only one system
        let fcBlk = this.getFireControlSystems("dmPart", partName)?[0]
        if (!fcBlk)
          break

        // 1. Gives fire solution for
        let weaponNames = this.getFireControlWeaponNames(fcBlk)
        if (weaponNames.len() == 0)
          break

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

        break

      case "fire_control_room":
      case "bridge":
        let numRangefinders = this.getNumFireControlNodes(partName, "rangefinder")
        let numFireDirectors = this.getNumFireControlNodes(partName, "fire_director")
        if (numRangefinders == 0 && numFireDirectors == 0)
          break

        desc.append(loc("xray/fire_control/devices"))
        if (numRangefinders > 0)
          desc.append($"{loc("ui/bullet")}{loc("xray/fire_control/num_rangefinders", {n = numRangefinders})}")
        if (numFireDirectors > 0)
          desc.append($"{loc("ui/bullet")}{loc("xray/fire_control/num_fire_directors", {n = numFireDirectors})}")

        break
    }

    if (this.isDebugMode)
      desc.append("\n" + colorize("badTextColor", partName))

    let rawPartName = getTblValue("raw_name", params)
    if (rawPartName)
      desc.append(rawPartName)

    let description = "\n".join(desc, true)
    return description
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

    return ::get_modifications_blk()?.modifications[modId].effects[effectId] ?? 1.0
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
    let unitTags = getTblValue(this.unit.name, ::get_unittags_blk(), null)
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

  function getAmmoQuantityByPartName(partName) {
    let ammoStowages = this.unitBlk?.ammoStowages
    if (ammoStowages)
      for (local i = 0; i < ammoStowages.blockCount(); i++) {
        let blk = ammoStowages.getBlock(i)
        foreach (blockName in [ "shells", "charges" ])
          foreach (shells in blk % blockName)
            if (shells?[partName])
              return shells[partName].count
      }
    return 0
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
              assert(false, "Bad weapon param " + linkKeyFmt + "='" + weapon[linkKeyFmt] +
                "' on " + this.unit.name)
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
    switch (this.unit.esUnitType) {
      case ES_UNIT_TYPE_TANK:
        let blkPath = weaponInfoBlk?.blk ?? ""
        let blk = blkOptFromPath(blkPath)
        let isRocketGun = blk?.rocketGun
        let isMachinegun = !!blk?.bullet?.caliber && !isCaliberCannon(1000 * blk.bullet.caliber)
        local isPrimary = !isRocketGun && !isMachinegun
        if (!isPrimary)
          foreach (weapon in getCommonWeapons(::dmViewer.unitBlk, "")) {
            if (!weapon?.blk || weapon?.dummy)
              continue
            isPrimary = weapon.blk == blkPath
            break
          }

        let isSecondary = !isPrimary && !isMachinegun
        return { isPrimary = isPrimary, isSecondary = isSecondary, isMachinegun = isMachinegun }
      case ES_UNIT_TYPE_BOAT:
      case ES_UNIT_TYPE_SHIP:
        let isPrimaryName       = startsWith(weaponPartName, "main")
        let isSecondaryName     = startsWith(weaponPartName, "auxiliary")
        let isPrimaryTrigger    = weaponInfoBlk?.triggerGroup == "primary"
        let isSecondaryTrigger  = weaponInfoBlk?.triggerGroup == "secondary"
        return {
          isPrimary     = isPrimaryTrigger   || (isPrimaryName   && !isSecondaryTrigger)
          isSecondary   = isSecondaryTrigger || (isSecondaryName && !isPrimaryTrigger)
          isMachinegun  = weaponInfoBlk?.triggerGroup == "machinegun"
        }
      case ES_UNIT_TYPE_AIRCRAFT:
      case ES_UNIT_TYPE_HELICOPTER:
        return { isPrimary = true, isSecondary = false, isMachinegun = false }
    }
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
        { need = needAxisX, modifName = "turnTurretSpeed",      blkName = "speedYaw",
          shipFxName = [ "mainSpeedYawK",   "auxSpeedYawK",   "aaSpeedYawK"   ] },
        { need = needAxisY, modifName = "turnTurretSpeedPitch", blkName = "speedPitch",
          shipFxName = [ "mainSpeedPitchK", "auxSpeedPitchK", "aaSpeedPitchK" ] },
      ]) {
        if (!a.need)
          continue

        local speed = 0
        switch (this.unit.esUnitType) {
          case ES_UNIT_TYPE_TANK:
            let mainTurretSpeed = unitModificators?[a.modifName] ?? 0
            let value = weaponInfoBlk?[a.blkName] ?? 0
            let weapons = this.getUnitWeaponList()
            let mainTurretValue = weapons?[0]?[a.blkName] ?? 0
            speed = mainTurretValue ? (mainTurretSpeed * value / mainTurretValue) : mainTurretSpeed
            break
          case ES_UNIT_TYPE_BOAT:
          case ES_UNIT_TYPE_SHIP:
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
            speed = baseSpeed * modMul
            break
        }

        if (speed) {
          let speedTxt = speed < 10 ? format("%.1f", speed) : format("%d", round(speed))
          desc.append(loc("crewSkillParameter/" + a.modifName) + loc("ui/colon") +
            speedTxt + loc("measureUnits/deg_per_sec"))
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
        desc.append(loc("shop/gunStabilizer") + " " + loc(valueLoc))
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

  function getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status) {
    local shotFreqRPM = 0.0 // rounds/min
    local reloadTimeS = 0 // sec
    local firstStageShotFreq = 0.0

    let weaponBlk = blkOptFromPath(weaponInfoBlk?.blk)
    let isCartridge = weaponBlk?.reloadTime != null
    local cyclicShotFreqS  = weaponBlk?.shotFreq ?? 0.0 // rounds/sec

    switch (this.unit.esUnitType) {
      case ES_UNIT_TYPE_AIRCRAFT:
      case ES_UNIT_TYPE_HELICOPTER:
        shotFreqRPM = cyclicShotFreqS * 60
        break

      case ES_UNIT_TYPE_TANK:
        if (!status.isPrimary)
          break

        let mainWeaponInfoBlk = this.getUnitWeaponList()?[0]
        if (!mainWeaponInfoBlk)
          break

        local mainGunReloadTime = this.unit?.modificators?[this.difficulty.crewSkillName]?.reloadTime ?? 0.0
        if (!mainGunReloadTime && this.crew) {
          let crewSkillParams = getParametersByCrewId(this.crew.id, this.unit.name)
          let crewSkill = crewSkillParams?[this.difficulty.crewSkillName]?.loader
          mainGunReloadTime = crewSkill?.loading_time_mult?.tankLoderReloadingTime ?? 0.0
        }

        if (weaponInfoBlk.blk == mainWeaponInfoBlk.blk) {
          reloadTimeS = mainGunReloadTime
          break
        }

        let thisGunReloadTimeMax = this.getGunReloadTimeMax(weaponInfoBlk)
        if (!thisGunReloadTimeMax)
          break

        if (weaponInfoBlk?.autoLoader) {
          reloadTimeS = thisGunReloadTimeMax
          break
        }

        let mainGunReloadTimeMax = this.getGunReloadTimeMax(mainWeaponInfoBlk)
        if (!mainGunReloadTimeMax)
          break

        reloadTimeS = mainGunReloadTime * thisGunReloadTimeMax / mainGunReloadTimeMax
        break

      case ES_UNIT_TYPE_BOAT:
      case ES_UNIT_TYPE_SHIP:
        if (isCartridge)
          if (this.crew) {
            let crewSkillParams = getParametersByCrewId(this.crew.id, this.unit.name)
            let crewSkill = crewSkillParams?[this.difficulty.crewSkillName]?.ship_artillery
            foreach (c in [ "main_caliber_loading_time", "aux_caliber_loading_time", "antiair_caliber_loading_time" ]) {
              reloadTimeS = (crewSkill?[c]?[$"weapons/{weaponName}"]) ?? 0.0
              if (reloadTimeS)
                break
            }
          }
          else {
            let wpcostUnit = ::get_wpcost_blk()?[this.unit.name]
            foreach (c in [ "shipMainCaliberReloadTime", "shipAuxCaliberReloadTime", "shipAntiAirCaliberReloadTime" ]) {
              reloadTimeS = wpcostUnit?[$"{c}_{weaponName}"] ?? 0.0
              if (reloadTimeS)
                break
            }
          }

        if (reloadTimeS)
          break
        cyclicShotFreqS = u.search(getCommonWeapons(::dmViewer.unitBlk, ""),
          @(inst) inst.trigger  == weaponInfoBlk.trigger)?.shotFreq ?? cyclicShotFreqS
        shotFreqRPM = cyclicShotFreqS * 60

        if (this.haveFirstStageShells(weaponInfoBlk?.trigger)) {
          firstStageShotFreq = shotFreqRPM
          shotFreqRPM *= 1 / this.getAmmoStowageReloadTimeMult(weaponInfoBlk?.trigger)
        }
        break
    }

    let desc = []
    if (firstStageShotFreq)
      desc.append(" ".join([loc("shop/shotFreq/firstStage"),
        round(firstStageShotFreq),
        loc("measureUnits/rounds_per_min")], true))

    if (shotFreqRPM) {
      shotFreqRPM = ::round(shotFreqRPM, shotFreqRPM > 600 ? -1
        : shotFreqRPM < 10 ? 1
        : 0)
      desc.append(" ".concat(loc("shop/shotFreq"), shotFreqRPM, loc("measureUnits/rounds_per_min")))
    }
    if (reloadTimeS) {
      reloadTimeS = (reloadTimeS % 1) ? format("%.1f", reloadTimeS) : format("%d", reloadTimeS)
      desc.append(loc("shop/reloadTime") + " " + reloadTimeS + " " + loc("measureUnits/seconds"))
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
      isComposite = startsWith(partName, "composite_armor")
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
    switch (this.unit.esUnitType) {
      case ES_UNIT_TYPE_TANK:
        if (partId == "gun_barrel" &&  weaponInfoBlk?.blk) {
          let status = this.getWeaponStatus(partName, weaponInfoBlk)
          params.partLocId <- status.isPrimary ? "weapon/primary"
            : status.isMachinegun ? "weapon/machinegun"
            : "weapon/secondary"
        }
        break
      case ES_UNIT_TYPE_BOAT:
      case ES_UNIT_TYPE_SHIP:
        if (startsWith(partId, "main") && weaponInfoBlk?.triggerGroup == "secondary")
          params.partLocId <- ::stringReplace(partId, "main", "auxiliary")
        if (startsWith(partId, "auxiliary") && weaponInfoBlk?.triggerGroup == "primary")
          params.partLocId <- ::stringReplace(partId, "auxiliary", "main")
        break
      case ES_UNIT_TYPE_HELICOPTER:
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
          return format(loc("shop/tank_mass") + " " + loc(pattern.langKey), data[nameVariant])
    return "";
  }

  function showExternalPartsArmor(isShow) {
    this.isVisibleExternalPartsArmor = isShow
    ::hangar_show_external_dm_parts_change(isShow)
  }

  function showExternalPartsXray(isShow) {
    this.isVisibleExternalPartsXray = isShow
    ::hangar_show_hidden_xray_parts_change(isShow)
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
    this.difficulty = ::get_difficulty_by_ediff(::get_current_ediff())
    this.resetXrayCache()
  }

  function onEventGameLocalizationChanged(_p) {
    this.resetXrayCache()
  }
}

registerPersistentDataFromRoot("dmViewer")
subscribe_handler(::dmViewer, ::g_listener_priority.DEFAULT_HANDLER)

::on_hangar_damage_part_pick <- function on_hangar_damage_part_pick(params) { // Called from API
  ::dmViewer.updateHint(params)
}
