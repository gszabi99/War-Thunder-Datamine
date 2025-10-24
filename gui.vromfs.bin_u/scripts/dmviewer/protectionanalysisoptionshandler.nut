from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { cutPrefix, utf8ToLower } = require("%sqstd/string.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let protectionAnalysisOptions = require("%scripts/dmViewer/protectionAnalysisOptions.nut")

let ProtectionAnalysisOptionsHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  sceneTplName         = "%gui/dmViewer/protectionAnalysisOptionsHandler.tpl"

  unit = null
  applyFilterTimer = null
  onChangeOptionCb = null
  goBackCb = null

  getSceneTplView = @() this.getOptionsView(this.unit)

  function initScreen() {
    this.guiScene.setUpdatesEnabled(false, false)
    protectionAnalysisOptions.init(this, this.scene)
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function getOptionsView(unit, ammo = null, distance = null) {
    protectionAnalysisOptions.setParams(unit, ammo, distance)

    let view = { rows = [], isSavedChoice = protectionAnalysisOptions.isSaved }
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

  function updateOptionsByHitData(hitData) {
    let unit = getAircraftByName(hitData.offenderObject)
    let view = this.getOptionsView(unit, hitData.ammo, hitData.distance)
    let data = handyman.renderCached("%gui/options/verticalOptions.tpl", view)
    this.guiScene.replaceContentFromText(this.scene.findObject("options_container"), data, data.len(), this)
    protectionAnalysisOptions.init(this, this.scene)
  }

  function setDataToOptions(unit) {
    protectionAnalysisOptions.setParams(unit)
    protectionAnalysisOptions.get("DISTANCE").update(this, this.scene)
  }

  function onChangeOption(obj) {
    this.onChangeOptionCb?()
    if (obj?.isValid())
      protectionAnalysisOptions.get(obj.id).onChange(this, this.scene, obj)
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
    this.onChangeOptionCb?()
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else
      this.guiScene.performDelayed(this, this.goBack)
  }

  function goBack() {
    base.goBack()
    this.goBackCb?()
  }

  function resetFilter() {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if(!filterEditBox?.isValid())
      return
    filterEditBox.setValue("")
  }

  onButtonInc = @(obj) this.onProgressButton(obj, true)
  onButtonDec = @(obj) this.onProgressButton(obj, false)
  onDistanceInc = @(_obj) this.onButtonInc(this.scene.findObject("buttonInc"))
  onDistanceDec = @(_obj) this.onButtonDec(this.scene.findObject("buttonDec"))

  function onProgressButton(obj, isIncrement) {
    this.onChangeOptionCb?()
    if (!obj?.isValid())
      return
    let optionId = cutPrefix(obj.getParent().id, "container_", "")
    let option = protectionAnalysisOptions.get(optionId)
    let value = option.value + (isIncrement ? option.step : -option.step)
    this.scene.findObject(option.id).setValue(value)
  }

  onSave = @(obj) protectionAnalysisOptions.isSaved = obj?.getValue()
}

gui_handlers.ProtectionAnalysisOptionsHandler <- ProtectionAnalysisOptionsHandler

return {
  loadProtectionAnalysisOptionsHandler = @(p) handlersManager.loadHandler(ProtectionAnalysisOptionsHandler, p)
}
