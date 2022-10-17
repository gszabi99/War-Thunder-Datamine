from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.RestrictionsWeaponryPresetModal <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType              = handlerType.MODAL
  sceneBlkName         = "%gui/weaponry/restrictionsWeaponryPresetModal.blk"
  presets = null
  messageText = null
  ok_fn = null

  function initScreen() {

    let presetViewBefore = this.scene.findObject("presetBefore")
    let presetViewAfter = this.scene.findObject("presetAfter")

    let restrictionsMessage = this.scene.findObject("restrictionsMessage")
    restrictionsMessage.setValue(messageText)

    setContent(presetViewBefore, presets.presetBefore)
    setContent(presetViewAfter, presets.presetAfter)
  }

  function setContent(view, preset) {
    let data = ::handyman.renderCached("%gui/weaponry/simplyWeaponryPreset", {
      tiersView = preset.tiersView.map(@(t) {
        tierId        = t.tierId
        img           = t?.img ?? ""
        tierTooltipId = !::show_console_buttons ? t?.tierTooltipId : null
        isActive      = t?.isActive || "img" in t
      })
    })
    this.guiScene.replaceContentFromText(view, data, data.len(), this)
  }

  function onPresetChange() {
    if(ok_fn != null)
      ok_fn()
    this.goBack()
  }
}

let openRestrictionsWeaponryPreset = @(params) ::handlersManager.loadHandler(::gui_handlers.RestrictionsWeaponryPresetModal, params)

return {
  openRestrictionsWeaponryPreset
}