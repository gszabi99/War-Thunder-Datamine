//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

/*
  config = {
    onChangeValueCb = function(selValuesArray)   //callback on each value change
    onChangeValuesBitMaskCb = function(selBitMask)   //callback on each value change
    onFinalApplyCb = function(selValuesArray)   //callback on close window if values was changed
    onFinalApplyBitMaskCb = function(selBitMask)   //callback on close window if values was changed

    align = "top"/"bottom"/"left"/"right"
    alignObj = DaguiObj  //object to align menu

    list = [ //max-len 32
      {
        text = string
        icon = string
        selected = boolean
        show = boolean || function
        value = ...    //only required when use not bitMask callbacks
      }
      ...
    ]
  }
*/
::gui_start_multi_select_menu <- function gui_start_multi_select_menu(config) {
  handlersManager.loadHandler(gui_handlers.MultiSelectMenu, config)
}

gui_handlers.MultiSelectMenu <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/multiSelectMenu.tpl"
  needVoiceChat = false

  list = null
  align = "top"
  alignObj = null

  onChangeValueCb = null
  onChangeValuesBitMaskCb = null
  onFinalApplyCb = null
  onFinalApplyBitMaskCb = null

  initialBitMask = 0
  currentBitMask = 0
  sndSwitchOn = null
  sndSwitchOff = null

  function getSceneTplView() {
    this.initListValues()

    return {
      list = this.list || []
      value = this.currentBitMask
      sndSwitchOn = this.sndSwitchOn
      sndSwitchOff = this.sndSwitchOff
    }
  }

  function initScreen() {
    if (!this.list)
      return this.goBack()

    this.align = setPopupMenuPosAndAlign(this.alignObj, this.align, this.scene.findObject("main_frame"))
    this.guiScene.applyPendingChanges(false)
    move_mouse_on_child(this.scene.findObject("multi_select"), 0)
  }

  function initListValues() {
    if (!this.list)
      return

    local mask = 0
    foreach (idx, option in this.list) {
      option.enable <- option?.enable ?? true
      mask = stdMath.change_bit(mask, idx, getTblValue("selected", option))
    }

    this.initialBitMask = mask
    this.currentBitMask = mask
  }

  function getCurValuesArray() {
    let selOptions = ::get_array_by_bit_value(this.currentBitMask, this.list)
    return selOptions.map(@(o) getTblValue("value", o))
  }

  function onChangeValue(obj) {
    this.currentBitMask = obj.getValue()
    if (this.onChangeValuesBitMaskCb)
      this.onChangeValuesBitMaskCb(this.currentBitMask)
    if (this.onChangeValueCb)
      this.onChangeValueCb(this.getCurValuesArray())
  }

  function close() {
    this.goBack()

    if (this.currentBitMask == this.initialBitMask)
      return

    if (this.onFinalApplyBitMaskCb)
      this.onFinalApplyBitMaskCb(this.currentBitMask)
    if (this.onFinalApplyCb)
      this.onFinalApplyCb(this.getCurValuesArray())
  }
}
