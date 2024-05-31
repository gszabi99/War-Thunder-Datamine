from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")

local PopupFilterWindow = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupFilterWindow.tpl"
  stateList            = null
  filterTypes          = null
  onChangeFn           = null
  popupAlign           = null
  btnName              = null
  btnWidth             = null
  btnTitle             = null
  btnPosition          = null
  btnHeight            = null
  visualStyle          = null

  function getSceneTplView() {
    let maxTextWidths = {}
    foreach (fType in this.filterTypes) {
      local maxTextWidth = 0
      foreach (cb in fType.checkbox) {
        if (cb?.text)
          maxTextWidth = max(maxTextWidth, getStringWidthPx(cb.text, "fontMedium"))
        let typeName = cb.id.split("_")[0]
        maxTextWidths[typeName] <- maxTextWidth
      }
    }

    let columns = this.filterTypes.map(function(fType, idx) {
      let { checkbox } = fType
      if (!checkbox.len())
        return null

      let isResetShow = checkbox.findindex(@(c) c.value) != null
      let typeName = checkbox[checkbox.len() - 1].id.split("_")[0]
      let hasIcon = checkbox[checkbox.len() - 1]?.image != null
      let params = $"pos:t='0, 1@popupFilterRowHeight-h'; type:t='rightSideCb'; typeName:t={typeName}"
      return fType.__merge({
        typeName
        isResetShow
        typeIdx = idx
        textWidth = maxTextWidths[typeName]
        hasIcon
        checkbox = checkbox.map(function(cb) {
          return cb.__merge({
            typeName
            funcName = "onCheckBoxChange"
            specialParams = params
            textWidth = maxTextWidths[typeName]
            hasMinWidth = true
          })
        })
      })
    }).filter(@(inst) inst != null)
    columns[columns.len() - 1].isLast <- true

    let stateItems = columns.reduce(@(res, inst) res.extend(inst?.checkbox), [])

    this.stateList = {}
    foreach (inst in stateItems)
      this.stateList[inst.id] <- inst

    return {
      columns = columns
      underPopupClick = "close"
      underPopupDblClick = "close"
      btnName = this.btnName
      btnTitle = this.btnTitle
      btnWidth = this.btnWidth
      visualStyle = this.visualStyle
      buttonPos = ", ".join(this.btnPosition)
      on_click = "close"
    }
  }

  function initScreen() {
    this.updateButton()
    this.updatePopupPosition()
  }

  function updatePopupPosition() {
    let popupObj = this.scene.findObject("filter_popup")
    let popupSize = popupObj.getSize()
    local posX = 0
    local posY = 0

    if (this.popupAlign == "top") {
      posX = this.btnPosition[0]
      posY = this.btnPosition[1] - popupSize[1] - to_pixels("1@blockInterval")
    }
    else if (this.popupAlign == "top-center") {
      posX = this.btnPosition[0] + this.btnWidth / 2 - popupSize[0] / 2
      posY = this.btnPosition[0] - popupSize[1] - to_pixels("1@blockInterval")
    }
    else if (this.popupAlign == "top-right") {
      posX = this.btnPosition[0] + this.btnWidth - popupSize[0]
      posY = this.btnPosition[1] - popupSize[1] - to_pixels("1@blockInterval")
    }
    else if (this.popupAlign == "bottom") {
      posX = this.btnPosition[0]
      posY = this.btnPosition[1] + this.btnHeight + to_pixels("1@blockInterval")
    }
    else if (this.popupAlign == "bottom-center") {
      posX = this.btnPosition[0] + this.btnWidth / 2 - popupSize[0] / 2
      posY = this.btnPosition[1] + this.btnHeight + to_pixels("1@blockInterval")
    }
    else if (this.popupAlign == "bottom-right") {
      posX = this.btnPosition[0] + this.btnWidth - popupSize[0]
      posY = this.btnPosition[1] + this.btnHeight + to_pixels("1@blockInterval")
    }
    popupObj["pos"] = $"{posX}, {posY}"
  }

  function updateButton() {
    let count = this.getSelectedFiltersCount()
    setDoubleTextToButton(this.scene, "filter_button", this.btnTitle,
      count == 0 ? ""
        : colorize("lbActiveColumnColor", loc("ui/parentheses", { text = $"+{count}" })))
  }

  function updateColumn(typeName) {
    let curList = this.stateList.filter(@(inst) inst.typeName == typeName)
    let columnObj = this.scene.findObject($"{typeName}_column")
    if (!columnObj?.isValid())
      return

    local isResetShow = false
    for (local i = 0; i < columnObj.childrenCount(); i++) {
      let child = columnObj.getChild(i)
      if (child.id != "reset_btn" && child.id != "separator") {
        let value = curList[child.id].value
        child.setValue(value)
        isResetShow = value || isResetShow
      }
    }
    showObjById("reset_btn", isResetShow, columnObj)
  }

  function onResetFilters(obj) {
    if (!this.onChangeFn)
      return

    foreach (state in this.stateList.filter(@(inst) inst.typeName == obj.typeName))
      this.stateList[state.id].value = false

    this.updateColumn(obj.typeName)
    this.onChangeFn(obj.id, obj.typeName, false)
    broadcastEvent("UpdateFiltersCount")
    this.updateButton()
    this.updatePopupPosition()
  }

  function onCheckBoxChange(obj) {
    if (!this.onChangeFn)
      return

    let value = obj.getValue()
    let curInst = this.stateList[obj.id]
    if (value == curInst.value)
      return


    curInst.value = value
    this.updateColumn(obj.typeName)
    this.onChangeFn(obj.id, obj.typeName, value)
    broadcastEvent("UpdateFiltersCount")
    this.updateButton()
    this.updatePopupPosition()
  }

  getSelectedFiltersCount = @() this.stateList.filter(@(inst) inst.value).len()

  function close() {
    this.goBack()
  }
}

gui_handlers.PopupFilterWindow <- PopupFilterWindow

return {
  PopupFilterWindow
}
