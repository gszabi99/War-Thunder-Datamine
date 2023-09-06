//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")

const MAIN_BTN_ID  = "filter_button"
const POUP_ID      = "filter_popup"
const RESET_ID     = "reset_btn"
const SEPARATOR_ID = "separator"

local popupFilter = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupFilter.tpl"

  stateList            = null
  isFilterVisible      = false
  iconNestObj          = null
  btnWidth             = null

  //init params
  filterTypes          = null
  btnName              = null
  btnTitle             = null
  onChangeFn           = null
  visualStyle          = null
  popupAlign           = null

  function getSceneTplView() {
    local maxTextWidth = 0
    this.btnTitle = this.btnTitle ?? loc("tournaments/filters")
    let k = ::show_console_buttons ? 2 : 1
    this.btnWidth = to_pixels($"{k}@buttonIconHeight+{k}@buttonTextPadding+{k*2}@blockInterval")
      + getStringWidthPx($"{this.btnTitle} {loc("ui/parentheses", {text = " +99"})}", "nav_button_font")

    foreach (fType in this.filterTypes)
      foreach (cb in fType.checkbox)
        if (cb?.text)
          maxTextWidth = max(maxTextWidth, getStringWidthPx(cb.text, "fontMedium"))

    let columns = this.filterTypes.map(function(fType, idx) {
      let { checkbox } = fType
      if (!checkbox.len())
        return null

      let isResetShow = checkbox.findindex(@(c) c.value) != null
      let typeName = checkbox[checkbox.len() - 1].id.split("_")[0]
      let params = $"pos:t='0, 1@popupFilterRowHeight-h'; type:t='rightSideCb'; typeName:t={typeName}"
      return fType.__merge({
        typeName
        isResetShow
        typeIdx = idx
        textWidth = maxTextWidth
        checkbox = checkbox.map(function(cb) {
          return cb.__merge({
            typeName
            funcName = "onCheckBoxChange"
            specialParams = params
            textWidth = maxTextWidth
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
      btnName = this.btnName ?? "Y"
      underPopupClick    = "onShowFilterBtnClick"
      underPopupDblClick = "onShowFilterBtnClick"
      btnWidth = this.btnWidth
      visualStyle = this.visualStyle
      popupAlign = this.popupAlign
    }
  }

  function initScreen() {
    this.updateMainBtn()
  }

  function updateColumn(typeName) {
    let curList  = this.stateList.filter(@(inst) inst.typeName == typeName)
    let columnObj = this.scene.findObject($"{typeName}_column")
    if (!columnObj?.isValid())
      return

    local isResetShow = false
    for (local i = 0; i < columnObj.childrenCount(); i++) {
      let child = columnObj.getChild(i)
      if (child.id != RESET_ID && child.id != SEPARATOR_ID) {
        let value = curList[child.id].value
        child.setValue(value)
        isResetShow = value || isResetShow
      }
    }
    showObjById(RESET_ID, isResetShow, columnObj)
  }

  function onResetFilters(obj) {
    if (!this.onChangeFn)
      return

    foreach (state in this.stateList.filter(@(inst) inst.typeName == obj.typeName))
      this.stateList[state.id].value = false

    this.updateMainBtn()
    this.updateColumn(obj.typeName)
    this.onChangeFn(obj.id, obj.typeName, false)
  }

  function updateMainBtn() {
    let count = this.stateList.filter(@(inst) inst.value).len()
    setDoubleTextToButton(this.scene, MAIN_BTN_ID, this.btnTitle,
      count == 0 ? ""
        : colorize("lbActiveColumnColor", loc("ui/parentheses", { text = $"+{count}" })))
  }

  function onCheckBoxChange(obj) {
    if (!this.onChangeFn)
      return

    let value    = obj.getValue()
    let curInst = this.stateList[obj.id]
    if (value == curInst.value)
      return


    curInst.value = value
    this.updateMainBtn()
    this.updateColumn(obj.typeName)
    this.onChangeFn(obj.id, obj.typeName, value)
  }

  function onShowFilterBtnClick(_obj) {
    this.isFilterVisible = !this.isFilterVisible
    this.showSceneBtn(POUP_ID, this.isFilterVisible)
  }
}

::gui_handlers.popupFilter <- popupFilter

return {
  RESET_ID
  openPopupFilter = @(params = {}) ::handlersManager.loadHandler(popupFilter, params)
}
