from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

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
  sceneTplName         = "%gui/popup/popupFilter"

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
    btnTitle = btnTitle ?? loc("tournaments/filters")
    let k = ::show_console_buttons ? 2 : 1
    btnWidth = to_pixels($"{k}@buttonIconHeight+{k}@buttonTextPadding+{k*2}@blockInterval")
      + getStringWidthPx($"{btnTitle} {loc("ui/parentheses", {text = " +99"})}", "nav_button_font")

    foreach (fType in filterTypes)
      foreach (cb in fType.checkbox)
        if (cb?.text)
          maxTextWidth = max(maxTextWidth, getStringWidthPx(cb.text, "fontMedium"))

    let columns = filterTypes.map(function(fType, idx) {
      let { checkbox } = fType
      if (!checkbox.len())
        return null

      let isResetShow = checkbox.findindex(@(c) c.value) != null
      let typeName = checkbox[checkbox.len()-1].id.split("_")[0]
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
    columns[columns.len()-1].isLast <- true

    let stateItems = columns.reduce(@(res, inst) res.extend(inst?.checkbox), [])

    stateList = {}
    foreach( inst in stateItems)
      stateList[inst.id] <- inst

    return {
      columns = columns
      btnName = btnName ?? "Y"
      underPopupClick    = "onShowFilterBtnClick"
      underPopupDblClick = "onShowFilterBtnClick"
      btnWidth = btnWidth
      visualStyle = visualStyle
      popupAlign = popupAlign
    }
  }

  function initScreen() {
    updateMainBtn()
  }

  function updateColumn(typeName) {
    let curList  = stateList.filter(@(inst) inst.typeName == typeName)
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
    ::showBtn(RESET_ID, isResetShow, columnObj)
  }

  function onResetFilters(obj) {
    if (!onChangeFn)
      return

    foreach (inst in stateList.filter(@(inst) inst.typeName == obj.typeName))
      stateList[inst.id].value = false

    updateMainBtn()
    updateColumn(obj.typeName)
    onChangeFn(obj.id, obj.typeName, false)
  }

  function updateMainBtn() {
    let count = stateList.filter(@(inst) inst.value).len()
    setDoubleTextToButton(this.scene, MAIN_BTN_ID, btnTitle,
      count == 0 ? ""
        : colorize("lbActiveColumnColor", loc("ui/parentheses", {text = $"+{count}"})))
  }

  function onCheckBoxChange(obj) {
    if (!onChangeFn)
      return

    let value    = obj.getValue()
    let curInst = stateList[obj.id]
    if (value == curInst.value)
      return


    curInst.value = value
    updateMainBtn()
    updateColumn(obj.typeName)
    onChangeFn(obj.id, obj.typeName, value)
  }

  function onShowFilterBtnClick(_obj) {
    isFilterVisible = !isFilterVisible
    this.showSceneBtn(POUP_ID, isFilterVisible)
  }
}

::gui_handlers.popupFilter <- popupFilter

return {
  RESET_ID
  openPopupFilter = @(params = {}) ::handlersManager.loadHandler(popupFilter, params)
}
