from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/viewUtils/daguiFonts.nut" import getStringWidthPx
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/viewUtils/objectTextUpdate.nut" import setDoubleTextToButton
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/popups/popupFilterWindow.nut" import PopupFilterWindow
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const RESET_ID = "reset_btn"
const SELECT_ALL_ID = "select_all_btn"


local PopupFilterWidget = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupFilterWidget.tpl"

  
  filterTypesFn        = null
  onChangeFn           = null
  popupAlign           = null
  btnName              = null
  btnWidth             = null
  btnHeight            = null
  btnTitle             = null
  visualStyle          = null
  popupFilterWnd       = null
  closeAsPopup         = true
  isShowCountFilters   = true
  hasBtnIcon           = true

  function getSceneTplView() {
    this.btnTitle = this.btnTitle ?? loc("tournaments/filters")
    let k = showConsoleButtons.get() ? 2 : 1
    let countFiltersText = this.isShowCountFilters ? $" {loc("ui/parentheses", {text = " +99"})}" : ""
    this.btnWidth = this.btnWidth
      ?? (to_pixels($"{k}@buttonIconHeight+{k}@buttonTextPadding+{k*2}@blockInterval")
        + getStringWidthPx($"{this.btnTitle}{countFiltersText}", "nav_button_font"))

    return {
      btnName = this.btnName == "" ? null
        : this.btnName ?? "Y"
      btnWidth = this.btnWidth
      visualStyle = this.visualStyle
      btnTitle = this.btnTitle
      hasBtnIcon = this.hasBtnIcon
      on_click = "onShowFilterBtnClick"
    }
  }

  initScreen = @() this.updateButton()

  onEventUpdateFiltersCount = @(_p) this.updateButton()

  function updateButton() {
    if (!this.isShowCountFilters)
      return

    let count = this.getSelectedFiltersCount()
    setDoubleTextToButton(this.scene, "filter_button", this.hasBtnIcon ? this.btnTitle : "",
      count == 0 ? ""
        : colorize("lbActiveColumnColor", loc("ui/parentheses", { text = $"+{count}" })))
  }

  function onShowFilterBtnClick(_obj) {
    if (!this.isValid())
      return

    if((this.popupFilterWnd?.isValid() ?? false) == false)
      this.popupFilterWnd = handlersManager.loadHandler(PopupFilterWindow, {
        filterTypes = this.filterTypesFn()
        onChangeFn = this.onChangeFn
        scene = this.scene.findObject("filter_window_nest")
        btnTitle = this.btnTitle
        btnName = this.btnName ?? "Y"
        btnWidth = this.btnWidth
        visualStyle = this.visualStyle
        btnPosition = this.scene.findObject("filter_button").getPosRC()
        btnHeight = to_pixels("1@buttonHeight")
        popupAlign = this.popupAlign ?? "bottom"
        closeAsPopup = this.closeAsPopup
        isShowCountFilters = this.isShowCountFilters
        hasBtnIcon = this.hasBtnIcon
      })
    else
      this.popupFilterWnd.close()
  }

  getSelectedFiltersCount = @() this.filterTypesFn()
    .map(@(fType) fType.checkbox.reduce(@(res, v) res += v.value ? 1 : 0, 0))
    .reduce(@(res, v) res += v, 0)
}

register_gui_handler("PopupFilterWidget", PopupFilterWidget)

return freeze({
  RESET_ID
  SELECT_ALL_ID
  openPopupFilter = @(params = {}) handlersManager.loadHandler(PopupFilterWidget, params)
})
