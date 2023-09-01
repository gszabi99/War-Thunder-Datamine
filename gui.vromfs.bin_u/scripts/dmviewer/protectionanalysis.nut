//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { hangar_focus_model, hangar_set_dm_viewer_mode } = require("hangar")
let protectionAnalysisOptions = require("%scripts/dmViewer/protectionAnalysisOptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let protectionAnalysisHint = require("%scripts/dmViewer/protectionAnalysisHint.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let controllerState = require("controllerState")
let { hangar_protection_map_update, set_protection_analysis_editing,
  set_protection_map_y_nulling, get_protection_map_progress, set_explosion_test } = require("hangarEventCommand")
let { hitCameraInit } = require("%scripts/hud/hudHitCamera.nut")
let { getAxisTextOrAxisName } = require("%scripts/controls/controlsVisual.nut")
let { cutPrefix, utf8ToLower } = require("%sqstd/string.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

local switch_damage = false
local allow_cutting = false
local explosionTest = false

const CB_VERTICAL_ANGLE = "protectionAnalysis/cbVerticalAngleValue"

gui_handlers.ProtectionAnalysis <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/dmViewer/protectionAnalysis.blk"
  sceneTplName = "%gui/options/verticalOptions.tpl"

  protectionAnalysisMode = DM_VIEWER_PROTECTION
  hintHandler = null
  unit = null
  applyFilterTimer = null

  getSceneTplContainerObj = @() this.scene.findObject("options_container")
  function getSceneTplView() {
    protectionAnalysisOptions.setParams(this.unit)

    let view = { rows = [] }
    foreach (o in protectionAnalysisOptions.types)
      if (o.isVisible())
        view.rows.append({
          id = o.id
          name = o.getLabel()
          option = o.getControlMarkup()
          infoRows = o.getInfoRows()
          valueWidth = o.valueWidth
        })
    return view
  }

  function initScreen() {
    ::dmViewer.init(this)
    hangar_focus_model(true)
    this.guiScene.performDelayed(this, @() hangar_set_dm_viewer_mode(this.protectionAnalysisMode))
    this.setSceneTitle(" ".concat(loc("mainmenu/btnProtectionAnalysis"),
      loc("ui/mdash"), ::getUnitName(this.unit.name)))

    this.onUpdateActionsHint()

    this.guiScene.setUpdatesEnabled(false, false)
    protectionAnalysisOptions.init(this, this.scene)
    this.guiScene.setUpdatesEnabled(true, true)

    hitCameraInit(this.scene.findObject("dmviewer_hitcamera"))

    this.hintHandler = protectionAnalysisHint.open(this.scene.findObject("hint_scene"))
    this.registerSubHandler(this.hintHandler)

    switch_damage = true //value is off by default it will be changed in AllowSimulation
    allow_cutting = false
    explosionTest = false

    this.scene.findObject("checkboxSaveChoice").setValue(protectionAnalysisOptions.isSaved)

    let isShowProtectionMapOptions = hasFeature("ProtectionMap") && this.unit.isTank()
    showObjById("btnProtectionMap", isShowProtectionMapOptions)
    let cbVerticalAngleObj = showObjById("checkboxVerticalAngle", isShowProtectionMapOptions)
    showObjById("rowSeparator", isShowProtectionMapOptions)
    if (isShowProtectionMapOptions) {
      let value = ::load_local_account_settings(CB_VERTICAL_ANGLE, true)
      cbVerticalAngleObj.setValue(value)
      if (!value) //Need change because y_nulling value is true by default
        set_protection_map_y_nulling(!value)
    }

    let isSimulationEnabled = this.unit?.unitType.canShowVisualEffectInProtectionAnalysis() ?? false
    let obj = this.showSceneBtn("switch_damage", isSimulationEnabled)
    if (isSimulationEnabled)
      this.onAllowSimulation(obj)

    ::allowCuttingInHangar(false)
    this.resetFilter()
  }

  onSave = @(obj) protectionAnalysisOptions.isSaved = obj?.getValue()

  function onChangeOption(obj) {
    if (!checkObj(obj))
      return
    protectionAnalysisOptions.get(obj.id).onChange(this, this.scene, obj)
  }

  onButtonInc = @(obj) this.onProgressButton(obj, true)
  onButtonDec = @(obj) this.onProgressButton(obj, false)
  onDistanceInc = @(_obj) this.onButtonInc(this.scene.findObject("buttonInc"))
  onDistanceDec = @(_obj) this.onButtonDec(this.scene.findObject("buttonDec"))

  function onProgressButton(obj, isIncrement) {
    if (!checkObj(obj))
      return
    let optionId = cutPrefix(obj.getParent().id, "container_", "")
    let option = protectionAnalysisOptions.get(optionId)
    let value = option.value + (isIncrement ? option.step : -option.step)
    this.scene.findObject(option.id).setValue(value)
  }

  function onWeaponsInfo(_obj) {
    ::open_weapons_for_unit(this.unit, { needHideSlotbar = true })
  }

  function goBack() {
    hangar_focus_model(false)
    hangar_set_dm_viewer_mode(DM_VIEWER_NONE)
    ::repairUnit()
    set_protection_analysis_editing(false)
    base.goBack()
  }

   function onRepair() {
    ::repairUnit()
  }

  function onExplosionTest(sObj) {
    if (checkObj(sObj)) {
      explosionTest = !explosionTest
      set_explosion_test(explosionTest)
    }
  }

  function onAllowSimulation(sObj) {
    if (checkObj(sObj)) {
      switch_damage = !switch_damage
      ::allowDamageSimulationInHangar(switch_damage)

      this.showSceneBtn("switch_cut", switch_damage)
      this.showSceneBtn("btn_repair", switch_damage)
    }
  }

  function onAllowCutting(sObj) {
    if (checkObj(sObj)) {
      allow_cutting = !allow_cutting
      ::allowCuttingInHangar(allow_cutting)
    }
  }

  function onUpdateActionsHint() {
    let showHints = hasFeature("HangarHitcamera")
    let hObj = this.showSceneBtn("analysis_hint", showHints)
    if (!showHints || !checkObj(hObj))
      return

    //hint for simulate shot
    let showHint = hasFeature("HangarHitcamera")
    let bObj = this.showSceneBtn("analysis_hint_shot", showHint)
    if (showHint && checkObj(bObj)) {
      let shortcuts = []
      if (showConsoleButtons.value)
        shortcuts.append(getAxisTextOrAxisName("fire"))
      if (controllerState?.is_mouse_connected())
        shortcuts.append(loc("key/LMB"))
      bObj.findObject("push_to_shot").setValue(loc("ui/comma").join(shortcuts, true))
    }
  }

  function buildProtectionMap() {
    let waitTextObj = this.scene.findObject("pa_wait_text")
    let cbVerticalAngleObj = this.scene.findObject("checkboxVerticalAngle")
    if (!waitTextObj?.isValid() || !cbVerticalAngleObj?.isValid())
      return

    cbVerticalAngleObj.enable = "no"
    showObjById("pa_info_block", true)
    hangar_protection_map_update()
    SecondsUpdater(waitTextObj, function(timerObj, p) {
        let progress = get_protection_map_progress()
        if (progress < 100)
          timerObj.setValue($"{progress.tostring()}%")
        else {
          showObjById("pa_info_block", false)
          p.cbVerticalAngleObj.enable = "yes"
        }
      }, false, { cbVerticalAngleObj })
  }

  onProtectionMap = @() this.buildProtectionMap()
  onConsiderVerticalAngle = function(obj) {
    let value = obj.getValue()
    ::save_local_account_settings(CB_VERTICAL_ANGLE, value)
    set_protection_map_y_nulling(!value)
  }

  function applyFilter(obj) {
    clearTimer(this.applyFilterTimer)
    let filterText = utf8ToLower(obj.getValue())
    if(filterText == "") {
      this.showTypes(true)
      protectionAnalysisOptions.init(this, this.scene)
      return
    }

    let applyCallback = Callback(@() this.applyFilterImpl(filterText), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function showTypes(status) {
    let needHideOnSearch = protectionAnalysisOptions.types.filter(@(t) t.needDisabledOnSearch())
      .map(@(t) t.id)
    foreach(typeId in needHideOnSearch)
      this.scene.findObject($"tr_{typeId}")?.show(status)
  }

  function applyFilterImpl(filterText) {
    this.showTypes(false)
    protectionAnalysisOptions.get("UNIT").filterByName(this, this.scene, filterText)
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else
      this.guiScene.performDelayed(this, this.goBack)
  }

  function resetFilter() {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if(!filterEditBox?.isValid())
      return
    filterEditBox.setValue("")
  }
}

return {
  canOpen = function(unit) {
    return hasFeature("DmViewerProtectionAnalysis")
      && ::isInMenu()
      && !::SessionLobby.hasSessionInLobby()
      && unit?.unitType.canShowProtectionAnalysis() == true
  }

  open = function (unit) {
    if (!this.canOpen(unit))
        return
    handlersManager.loadHandler(gui_handlers.ProtectionAnalysis, { unit = unit })
  }
}
