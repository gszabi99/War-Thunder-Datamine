//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

local handlerClass = class extends gui_handlers.EditWeaponryPresetsModal {
  afterModalDestroyFunc = null

  function initScreen() {
    this.showSceneBtn("cancelBtn", false)
    this.scene.findObject("headerTxt").setValue(
    $"{loc("edit/secondary_weapons")} {colorize("badTextColorDark", ::getUnitName(this.unit))}")
    base.initScreen()
  }

  onPresetSave = @() this.goBack()

  function updateButtons() {
    this.showSceneBtn("cancelBtn", false)
    base.updateButtons()
  }

  function afterModalDestroy() {
    if (this.afterModalDestroyFunc)
      this.afterModalDestroyFunc()
  }

  function goBack() {
    this.savePreset()
    this.guiScene.performDelayed(this, function() {
      handlersManager.destroyHandler(this)
      handlersManager.clearInvalidHandlers()

      this.onModalWndDestroy()
    })
  }
}

gui_handlers.FixWeaponryPresetsModal <- handlerClass

let openFixWeaponryPresets = @(params) handlersManager.loadHandler(handlerClass, params)

return {
  openFixWeaponryPresets
}
