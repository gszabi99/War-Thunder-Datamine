from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { PopupFilterWindow } = require("%scripts/popups/popupFilterWindow.nut")

const RESET_ID = "reset_btn"

local PopupFilterWidget = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupFilterButton.tpl"

  //init params
  filterTypesFn        = null
  onChangeFn           = null
  popupAlign           = null
  btnName              = null
  btnWidth             = null
  btnHeight            = null
  btnTitle             = null
  visualStyle          = null
  popupFilterWnd       = null

  function getSceneTplView() {
    this.btnTitle = this.btnTitle ?? loc("tournaments/filters")
    let k = showConsoleButtons.value ? 2 : 1
    this.btnWidth = to_pixels($"{k}@buttonIconHeight+{k}@buttonTextPadding+{k*2}@blockInterval")
      + getStringWidthPx($"{this.btnTitle} {loc("ui/parentheses", {text = " +99"})}", "nav_button_font")

    return {
      btnName = this.btnName ?? "Y"
      btnWidth = this.btnWidth
      visualStyle = this.visualStyle
      on_click = "onShowFilterBtnClick"
    }
  }

  initScreen = @() this.updateButton()

  onEventUpdateFiltersCount = @(_p) this.updateButton()

  function updateButton() {
    let count = this.getSelectedFiltersCount()
    setDoubleTextToButton(this.scene, "filter_button", this.btnTitle,
      count == 0 ? ""
        : colorize("lbActiveColumnColor", loc("ui/parentheses", { text = $"+{count}" })))
  }

  function onShowFilterBtnClick(_obj) {
    if((this.popupFilterWnd?.isValid() ?? false) == false)
      this.popupFilterWnd = handlersManager.loadHandler(PopupFilterWindow, {
        filterTypes = this.filterTypesFn()
        onChangeFn = this.onChangeFn
        scene = this.scene
        btnTitle = this.btnTitle
        btnName = this.btnName ?? "Y"
        btnWidth = this.btnWidth
        visualStyle = this.visualStyle
        btnPosition = this.scene.findObject("filter_button").getPosRC()
        btnHeight = to_pixels("1@buttonHeight")
        popupAlign = this.popupAlign ?? "bottom"
      })
    else
      this.popupFilterWnd.close()
  }

  getSelectedFiltersCount = @() this.filterTypesFn()
    .map(@(fType) fType.checkbox.reduce(@(res, v) res += v.value ? 1 : 0, 0))
    .reduce(@(res, v) res += v, 0)
}

gui_handlers.PopupFilterWidget <- PopupFilterWidget

return {
  RESET_ID
  openPopupFilter = @(params = {}) handlersManager.loadHandler(PopupFilterWidget, params)
}
