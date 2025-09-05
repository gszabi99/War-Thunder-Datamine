from "%scripts/dagui_library.nut" import *
import "%sqstd/math.nut" as stdMath

let { get_array_by_bit_value } = require("%scripts/utils_sa.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { move_mouse_on_child, setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")























gui_handlers.MultiSelectMenu <- class (gui_handlers.BaseGuiHandlerWT) {
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
      list = this.list ?? []
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
    let selOptions = get_array_by_bit_value(this.currentBitMask, this.list)
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
