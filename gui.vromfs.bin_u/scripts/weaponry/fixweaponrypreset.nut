from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { EditWeaponryPresetsModal } = require("%scripts/weaponry/editWeaponryPreset.nut")

local handlerClass = class (EditWeaponryPresetsModal) {
  afterModalDestroyFunc = null

  function initScreen() {
    showObjById("cancelBtn", false, this.scene)
    this.scene.findObject("headerTxt").setValue(
    $"{loc("edit/secondary_weapons")} {colorize("badTextColorDark", getUnitName(this.unit))}")
    base.initScreen()
  }

  onPresetSave = @() this.goBack()

  function updateButtons() {
    showObjById("cancelBtn", false, this.scene)
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
