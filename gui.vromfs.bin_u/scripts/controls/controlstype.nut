from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "controls" import hasXInputDevice
from "guiOptions" import setGuiOptionsMode, getGuiOptionsMode
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { gui_modal_controlsWizard } = require("%scripts/controls/controlsUtils.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { isPresetChanged } = require("%scripts/controls/controlsState.nut")
let { setControlTypeByID } = require("%scripts/controls/controlsTypeUtils.nut")

register_gui_handler("ControlType", class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/controlTypeChoice.blk"

  controlsOptionsMode = 0
  startControlsWizard = false

  function initScreen() {
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)
    showObjById("ct_xinput", hasXInputDevice(), this.scene)
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
    if (this.startControlsWizard)
      gui_modal_controlsWizard()
    isPresetChanged.set(true)
    broadcastEvent("ControlsPresetChanged")
  }

  function onControlTypeApply() {
    local ct_id = "ct_mouse"
    let obj = this.scene.findObject("controlType")
    if (checkObj(obj)) {
      let value = obj.getValue()
      if (value >= 0 && value < obj.childrenCount())
        ct_id = obj.getChild(value).id
    }

    if (ct_id == "ct_own") {
      this.doControlTypeApply(ct_id)
      return
    }

    let text = loc("msgbox/controlPresetApply")
    let onOk = Callback(@() this.doControlTypeApply(ct_id), this)
    this.msgBox("controlPresetApply", text, [["yes", onOk], ["no"]], "yes")
  }

  function doControlTypeApply(ctId) {
    setControlTypeByID(ctId)
    this.startControlsWizard = ctId == "ct_own"
    this.goBack()
  }

  function onControlTypeDblClick() {
    this.onControlTypeApply()
  }
})