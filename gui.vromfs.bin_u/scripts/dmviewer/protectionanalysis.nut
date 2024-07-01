from "%scripts/dagui_natives.nut" import allowCuttingInHangar, repairUnit, allowDamageSimulationInHangar
from "%scripts/dagui_library.nut" import *

let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { hangar_focus_model, hangar_set_dm_viewer_mode } = require("hangar")
let protectionAnalysisOptions = require("%scripts/dmViewer/protectionAnalysisOptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let protectionAnalysisHint = require("%scripts/dmViewer/protectionAnalysisHint.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let controllerState = require("controllerState")
let { hangar_protection_map_update, hangar_crew_map_update, set_protection_analysis_editing,
  set_protection_map_y_nulling, get_protection_map_progress, set_explosion_test } = require("hangarEventCommand")
let { hitCameraInit } = require("%scripts/hud/hudHitCamera.nut")
let { getAxisTextOrAxisName } = require("%scripts/controls/controlsVisual.nut")
let { cutPrefix, utf8ToLower } = require("%sqstd/string.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

local switch_damage = false
local allow_cutting = false
local explosionTest = false

const CB_VERTICAL_ANGLE = "protectionAnalysis/cbVerticalAngleValue"

let helpHintsParams = [
  {hintName = "hint_filter_edit_box", objName = "filter_edit_box", shiftX = "- 1@bw", shiftY = "- 1@bh -h - 1.5@helpInterval"}
  {hintName = "hint_unit_params", objName = "UNITTYPE", shiftX = "- 1@bw + 1@sliderWidth + 1@blockInterval + 1@dmInfoTextWidth + 2@tablePad + 2@framePadding", shiftY = "- 1@bh"}
  {hintName = "hint_distanse_offset", objName = "tr_DISTANCE", shiftX = "- 1@bw + 1@sliderWidth + 1@blockInterval + 1@dmInfoTextWidth + 2@tablePad + 2@framePadding", shiftY = "- 1@bh - h/2", sizeMults = [0, 0.5]}
  {hintName = "hint_checkboxSaveChoice", objName = "checkboxSaveChoice", shiftX = "- 1@bw + 1@sliderWidth + 1@blockInterval + 1@dmInfoTextWidth + 2@tablePad + 2@framePadding", shiftY = "- 1@bh -h/2", sizeMults = [0, 0.5]}
  {hintName = "hint_btnProtectionMap", objName = "btnProtectionMap", shiftX = "- 1@bw + 1@sliderWidth + 1@blockInterval + 2@helpInterval + 1@dmInfoTextWidth + 2@tablePad + 2@framePadding + 1.5@shopWidthMax", shiftY = "- 1@bh -h/2", sizeMults = [0, 0.5]}
  {hintName = "hint_checkboxVerticalAngle", objName = "checkboxVerticalAngle", shiftX = "- 1@bw + 1@sliderWidth + 1@blockInterval + 1@dmInfoTextWidth + 2@tablePad + 2@framePadding", shiftY = "- 1@bh"}
]


gui_handlers.ProtectionAnalysis <- class (gui_handlers.BaseGuiHandlerWT) {
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
      loc("ui/mdash"), getUnitName(this.unit.name)))

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
    let isShowCrewMapOptions = hasFeature("CrewMap") && this.unit.isShip()
    showObjById("btnCrewMap", isShowCrewMapOptions)
    let cbVerticalAngleObj = showObjById("checkboxVerticalAngle", isShowProtectionMapOptions)
    showObjById("rowSeparator", isShowProtectionMapOptions)
    if (isShowProtectionMapOptions) {
      let value = loadLocalAccountSettings(CB_VERTICAL_ANGLE, true)
      cbVerticalAngleObj.setValue(value)
      if (!value) //Need change because y_nulling value is true by default
        set_protection_map_y_nulling(!value)
    }

    let isSimulationEnabled = this.unit?.unitType.canShowVisualEffectInProtectionAnalysis() ?? false
    let obj = showObjById("switch_damage", isSimulationEnabled, this.scene)
    if (isSimulationEnabled)
      this.onAllowSimulation(obj)

    allowCuttingInHangar(false)
    this.resetFilter()
  }

  onSave = @(obj) protectionAnalysisOptions.isSaved = obj?.getValue()

  function onCollapseButton(_obj) {
    let panel = this.scene.findObject("protection_analysis_left_panel")
    let content = panel.findObject("wnd_frame")
    let isVisible = !content.isVisible()
    panel.collapsed = isVisible ? "no" : "yes"
    content.show(isVisible)
  }

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
    repairUnit()
    set_protection_analysis_editing(false)
    base.goBack()
  }

   function onRepair() {
    repairUnit()
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
      allowDamageSimulationInHangar(switch_damage)

      showObjById("switch_cut", switch_damage, this.scene)
      showObjById("btn_repair", switch_damage, this.scene)
    }
  }

  function onAllowCutting(sObj) {
    if (checkObj(sObj)) {
      allow_cutting = !allow_cutting
      allowCuttingInHangar(allow_cutting)
    }
  }

  function onUpdateActionsHint() {
    let showHints = hasFeature("HangarHitcamera")
    let hObj = showObjById("analysis_hint", showHints, this.scene)
    if (!showHints || !checkObj(hObj))
      return

    //hint for simulate shot
    let showHint = hasFeature("HangarHitcamera")
    let bObj = showObjById("analysis_hint_shot", showHint, this.scene)
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

  function buildCrewMap() {
    hangar_crew_map_update()
  }

  onCrewMap = @() this.buildCrewMap()

  onConsiderVerticalAngle = function(obj) {
    let value = obj.getValue()
    saveLocalAccountSettings(CB_VERTICAL_ANGLE, value)
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

  function onHelp() {
    gui_handlers.HelpInfoHandlerModal.openHelp(this)
  }

  function getWndHelpConfig() {
    let res = {
      textsBlk = "%gui/dmViewer/protectionAnalysisHelp.blk"
      objContainer = this.scene.findObject("protection_analysis_container")
    }

    let links = [
      { obj = [$"analysis_hint_shot"], msgId = "hint_analysis_hint_shot"}
      { obj = [$"UNITTYPE", "COUNTRY", "RANK", "UNIT", "tr_BULLET"], msgId = "hint_unit_params"}
      { obj = [$"filter_edit_box"], msgId = "hint_filter_edit_box"}
      { obj = [$"tr_DISTANCE", "tr_OFFSET"], msgId = "hint_distanse_offset"}
      { obj = [$"checkboxSaveChoice"], msgId = "hint_checkboxSaveChoice"}
      { obj = [$"btnProtectionMap"], msgId = "hint_btnProtectionMap"}
      { obj = [$"checkboxVerticalAngle"], msgId = "hint_checkboxVerticalAngle"}
    ]

    res.links <- links
    return res
  }

  function prepareHelpPage(handler) {
    foreach (params in helpHintsParams) {
      let hintObj = handler.scene.findObject(params.hintName)
       if (hintObj?.isValid()) {
          let obj = this.scene.findObject(params.objName)
          if (obj?.isValid()) {
            let objPos = obj.getPos()
            let objSize = (params?.sizeMults) ? obj.getSize() : [0,0]
            let sizeMults = params?.sizeMults ?? [0,0]
            hintObj.pos = $"{objPos[0] + sizeMults[0]*objSize[0]} {params.shiftX}, {objPos[1] + sizeMults[1]*objSize[1]} {params.shiftY}"
          }
       }
    }
  }

}


return {
  canOpen = function(unit) {
    return hasFeature("DmViewerProtectionAnalysis")
      && isInMenu()
      && !::SessionLobby.hasSessionInLobby()
      && unit?.unitType.canShowProtectionAnalysis() == true
  }

  open = function (unit) {
    if (!this.canOpen(unit))
        return
    handlersManager.loadHandler(gui_handlers.ProtectionAnalysis, { unit = unit })
  }
}
