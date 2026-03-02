from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { destroyModalInfo } = require("%scripts/modalInfo/modalInfo.nut")
let { loadNameFilterHandler } = require("%scripts/wndLib/nameFilterHandler.nut")


let ProtectionAnalysisOptionsHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  sceneTplName         = "%gui/dmViewer/protectionAnalysisOptionsHandler.tpl"

  unit = null
  ammoName = null
  optionsList = null
  onChangeOptionCb = null
  goBackCb = null
  nameFilterHandler = null

  getSceneTplView = @() this.getOptionsView(this.unit, this.ammoName)

  function initScreen() {
    this.guiScene.setUpdatesEnabled(false, false)
    this.optionsList.init(this, this.scene)

    let nameFilterHandler = loadNameFilterHandler({
      scene = this.scene.findObject("filter_edit_box_nest")
      applyFilterCb = Callback(@(txt) this.applyNameFilter(txt), this)
      goBackCb = Callback(@() this.goBack(), this)
    })
    this.registerSubHandler(nameFilterHandler)
    this.nameFilterHandler = nameFilterHandler.weakref()

    this.guiScene.setUpdatesEnabled(true, true)
  }

  function getOptionsView(unit, ammo = null, distance = null) {
    this.optionsList.setParams(unit, ammo, distance)

    let view = { rows = [], isSavedChoice = this.optionsList?.isSaved,
      canChangeSavedChoice = ("isSaved" in this.optionsList) }
    foreach (o in this.optionsList.types)
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
    this.optionsList.init(this, this.scene)
  }

  function setDataToOptions(unit) {
    this.optionsList.setParams(unit)
    this.optionsList.get("DISTANCE").update(this, this.scene)
  }

  function onChangeOption(obj) {
    if (obj?.isValid())
      this.optionsList.get(obj.id).onChange(this, this.scene, obj)
    this.onChangeOptionCb?()
  }

  function applyNameFilter(filterText) {
    if (filterText != "") {
      this.applyFilterImpl(filterText)
      return
    }
    this.showTypes(true)
    this.optionsList.init(this, this.scene)
  }

  function showTypes(status) {
    let needHideOnSearch = this.optionsList.types.filter(@(t) t.needDisabledOnSearch())
      .map(@(t) t.id)
    foreach(typeId in needHideOnSearch)
      this.scene.findObject($"tr_{typeId}")?.show(status)
  }

  function applyFilterImpl(filterText) {
    this.showTypes(false)
    this.optionsList.get("UNIT").filterByName(this, this.scene, filterText)
    this.onChangeOptionCb?()
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
    let option = this.optionsList.get(optionId)
    let value = option.value + (isIncrement ? option.step : -option.step)
    this.scene.findObject(option.id).setValue(value)
  }

  function onSave(obj) {
    if ("isSaved" not in this.optionsList)
      return
    this.optionsList.isSaved = obj?.getValue()
  }

  onBeforeSelectComboboxValue = @() destroyModalInfo()
}

gui_handlers.ProtectionAnalysisOptionsHandler <- ProtectionAnalysisOptionsHandler

return {
  loadProtectionAnalysisOptionsHandler = @(p) handlersManager.loadHandler(ProtectionAnalysisOptionsHandler, p)
}
