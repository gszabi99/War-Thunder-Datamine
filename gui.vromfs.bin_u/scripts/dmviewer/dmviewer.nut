from "%scripts/dagui_natives.nut" import hangar_show_external_dm_parts_change
from "%scripts/dagui_library.nut" import *
let { register_command } = require("console")
let { S_UNDEFINED, getPartType, getPartNameLocText } = require("%globalScripts/modeXrayLib.nut")
let { GAMEPAD_ENTER_SHORTCUT }  = require("%scripts/controls/rawShortcuts.nut")
let { get_difficulty_by_ediff } = require("%scripts/difficulty.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let DataBlock = require("DataBlock")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { round } = require("math")
let { hangar_get_current_unit_name, hangar_set_dm_viewer_mode, DM_VIEWER_NONE, DM_VIEWER_ARMOR, DM_VIEWER_XRAY,
  hangar_get_dm_viewer_parts_count, set_xray_parts_filter } = require("hangar")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { hasLoadedModel } = require("%scripts/hangarModelLoadManager.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { TIME_DAY_IN_SECONDS } = require("%scripts/time.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { checkUnitModsUpdate, checkSecondaryWeaponModsRecount } = require("%scripts/unit/unitChecks.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { get_game_params_blk, get_unittags_blk } = require("blkGetters")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { isStatsLoaded, isMeNewbieOnUnitType } = require("%scripts/myStats.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { eventbus_subscribe } = require("eventbus")
let { get_option, set_option } = require("%scripts/options/optionsExt.nut")
let { USEROPT_XRAY_FILTER_TANK, USEROPT_XRAY_FILTER_SHIP
} = require("%scripts/options/optionsExtNames.nut")
let { openPopupFilter, RESET_ID, SELECT_ALL_ID } = require("%scripts/popups/popupFilterWidget.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { gui_modal_tutor } = require("%scripts/guiTutorial.nut")
let { getSimpleUnitType, xrayCommonGetters, getDescriptionInXrayMode } = require("modeXrayUtils.nut")










const XRAY_FILTER_OBJ_PREFIX = "xray_filter_"

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

local dmViewer
dmViewer = {
  active = false
  
  
  view_mode = DM_VIEWER_NONE
  unit = null
  simUnitType = S_UNDEFINED
  crew = null
  unitBlk = null
  unitDataCache = {}
  xrayRemap = {}
  ediff = null
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
    this.prevHintParams.clear()
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
    this.ediff = getCurrentGameModeEdiff()
    this.difficulty = get_difficulty_by_ediff(this.ediff)
    this.crew = getCrewByAir(this.unit)
    this.loadUnitBlk()
    this.xrayRemap = (this.unitBlk?.xray ?? {}).map(@(v) v)
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
    if (!newActive && !this.active) 
      return false

    let handler = handlersManager.getActiveBaseHandler()
    newActive = newActive && (handler?.canShowDmViewer() ?? false)
    if (topMenuHandler.get()?.isSceneActive() ?? false)
      newActive = newActive && topMenuHandler.get().canShowDmViewer()

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

    local obj = showObjById("air_info_dmviewer_listbox", this.hasDmViewer(), handler.scene)
    if (!checkObj(obj))
      return

    obj.setValue(this.view_mode)

    
    if (hasFeature("DmViewerProtectionAnalysis")) {
      let isEnabled = this.view_mode == DM_VIEWER_ARMOR
        && (this.unit?.unitType.canShowProtectionAnalysis() ?? false)
      showObjById("dmviewer_protection_analysis_btn", isEnabled, handler.scene)
    }

    let isTankOrShip = this.unit != null && (this.unit.isTank() || this.unit.isShipOrBoat())
    
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
          broadcastEvent("UpdateFiltersCount") 
        set_xray_parts_filter(xrayFilterOption.value)
      } else if (this.view_mode == DM_VIEWER_XRAY && hasLoadedModel())
        set_xray_parts_filter(0)
    }

    obj = handler.scene.findObject("dmviewer_show_extended_hints")
    if (obj?.isValid()) {
      let isShowOption = this.view_mode == DM_VIEWER_XRAY && !!this.unit?.isShipOrBoat()
      obj.show(isShowOption)
      if (isShowOption)
        obj.setValue(this.needShowExtHints())
    }

    
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

  function getDmPartAnimationSrc(partType) {
    let foundUnitAnim = this.findDmPartAnimationInBlk(partType, this.unitBlk?.viewer_xray_animations)
    if (foundUnitAnim)
      return foundUnitAnim

    let gameParamsXrayKey = this.unit.isAir() ? "armorPartNamesAir" : "armorPartNamesGround"
    let gameParamsXrayBlk = get_game_params_blk()[gameParamsXrayKey].viewer_xray

    return this.findDmPartAnimationInBlk(partType, gameParamsXrayBlk)
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

    if (this.isDebugBatchExportProcess && params?.name != null)
      return

    local needUpdatePos = false
    local needUpdateContent = false

    if (this.view_mode == DM_VIEWER_XRAY || (params?.weapon_item_desc ?? false))
      
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

    let partName = params?.name ?? ""
    let partType = this.view_mode == DM_VIEWER_XRAY ? getPartType(partName, this.xrayRemap) : partName

    let isVisible = partType != ""
    obj.show(isVisible)
    if (!isVisible)
      return

    let handler = handlersManager.getActiveBaseHandler()
    local info = { title = "", desc = [] }
    let isUseCache = this.view_mode == DM_VIEWER_XRAY && !this.isDebugMode

    if (isUseCache && (partName in this.xrayDescriptionCache))
      info = this.xrayDescriptionCache[partName]
    else {
      info = this.getPartTooltipInfo(partType, params)
      info.title = info.title.replace(" ", nbsp)

      if (isUseCache)
        this.xrayDescriptionCache[partName] <- info
    }

    obj.findObject("dmviewer_title").setValue(info.title)
    let descObj = obj.findObject("dmviewer_desc")
    if (info.desc != null) {
      let items = info.desc.map(@(v) "value" in v ? v : { value = v })
      let data = handyman.renderCached("%gui/dmViewer/dmViewerHintDescItem.tpl", { items })
      handler.guiScene.replaceContentFromText(descObj, data, data.len(), handler)

      obj.findObject("topValueHint").show(info.desc.findindex(@(v) "topValue" in v) != null)
    }

    let debugStr = params?.raw_name ?? (this.isDebugMode ? partName : null)
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
      desc        = []
      extDesc     = ""
      extIcon     = ""
      extShortcut = ""
      animation   = null
    }

    if (partType == "")
      return res

    local partLocId = partType
    let { overrideTitle = "", hideDescription = false } = this.unitBlk?.xrayOverride[params.name]

    if (params?.weapon_item_desc ?? false)
      return this.getDescriptionWeaponItem(params)
    else if (this.view_mode == DM_VIEWER_ARMOR)
      res.desc = this.getDescriptionInArmorMode(params)
    else if (this.view_mode == DM_VIEWER_XRAY) {
      let descData = getDescriptionInXrayMode(partType, params, {
        unit = this.unit
        unitName = this.unit?.name ?? ""
        simUnitType = this.simUnitType
        unitBlk = this.unitBlk
        unitDataCache = this.unitDataCache
        crewId = this.crew?.id ?? -1
        ediff = this.ediff
        difficulty = this.difficulty
        armorClassToSteel = this.armorClassToSteel
        isSecondaryModsValid = this.isSecondaryModsValid
        isDebugBatchExportProcess = this.isDebugBatchExportProcess
      }.__update(xrayCommonGetters))

      partLocId = descData.partLocId
      if (!hideDescription && hasFeature("XRayDescription"))
        res.desc = descData.desc
      res.animation = this.getDmPartAnimationSrc(params.name)
      res.__update(this.getExtendedHintInfo(partType, params))
    }

    let titleLocId = overrideTitle != "" ? overrideTitle : partLocId
    res.title = getPartNameLocText(titleLocId, this.simUnitType)

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
    this.updateSecondaryMods()
    this.resetXrayCache()
  }

  function onEventUnitWeaponChanged(p) {
    if (!this.unit || p?.unitName != this.unit.name)
      return
    this.resetXrayCache()
  }

  function onEventCurrentGameModeIdChanged(_p) {
    this.ediff = getCurrentGameModeEdiff()
    this.difficulty = get_difficulty_by_ediff(this.ediff)
    this.resetXrayCache()
  }

  onEventGameLocalizationChanged = @(_p) this.resetXrayCache()
  onEventModificationChanged = @(_p) this.resetXrayCache()
}

registerPersistentData("dmViewer", dmViewer, [ "active", "view_mode", "_currentViewMode", "isDebugMode",
    "isVisibleExternalPartsArmor" ])
subscribe_handler(dmViewer, g_listener_priority.DEFAULT_HANDLER)

eventbus_subscribe("on_hangar_damage_part_pick", @(p) dmViewer.updateHint(p))

register_command(@() dmViewer.isDebugMode = !dmViewer.isDebugMode, "ui.debug.dm_viewer")

return dmViewer