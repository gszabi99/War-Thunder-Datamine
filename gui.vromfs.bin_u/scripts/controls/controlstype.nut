from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/controls/controlsUtils.nut" import gui_modal_controlsWizard
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY
from "%scripts/controls/controlsState.nut" import isPresetChanged
from "%scripts/controls/controlsTypeUtils.nut" import setControlTypeByID
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "controls" import hasXInputDevice
from "guiOptions" import setGuiOptionsMode, getGuiOptionsMode
from "%scripts/dagui_library.nut" import *

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