//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.RestrictionsWeaponryPresetModal <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType              = handlerType.MODAL
  sceneBlkName         = "%gui/weaponry/restrictionsWeaponryPresetModal.blk"
  presets              = null
  messageText          = null
  ok_fn                = null

  function initScreen() {
    let weaponsSlotCount = this.presets.presetBefore.weaponsSlotCount
    this.scene.findObject("restrictions_wnd").width = "{0}@tierIconSize + 2@blockInterval".subst(weaponsSlotCount)

    let presetViewBefore = this.scene.findObject("presetBefore")
    let presetViewAfter = this.scene.findObject("presetAfter")

    presetViewBefore.width = "{0}@tierIconSize".subst(weaponsSlotCount)
    presetViewAfter.width = "{0}@tierIconSize".subst(weaponsSlotCount)

    let restrictionsMessage = this.scene.findObject("restrictionsMessage")
    restrictionsMessage.setValue(this.messageText)

    this.setContent(presetViewBefore, this.presets.presetBefore)
    this.setContent(presetViewAfter, this.presets.presetAfter)
  }

  function setContent(view, preset) {
    let data = ::handyman.renderCached("%gui/weaponry/simplyWeaponryPreset.tpl", {
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
    if (this.ok_fn != null)
      this.ok_fn()
    this.goBack()
  }
}

let openRestrictionsWeaponryPreset = @(params) ::handlersManager.loadHandler(::gui_handlers.RestrictionsWeaponryPresetModal, params)

return {
  openRestrictionsWeaponryPreset
}