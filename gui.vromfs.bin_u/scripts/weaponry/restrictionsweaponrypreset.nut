from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let RestrictionsWeaponryPresetModal = class (BaseGuiHandlerWT) {
  wndType              = handlerType.MODAL
  sceneBlkName         = "%gui/weaponry/restrictionsWeaponryPresetModal.blk"
  presets              = null
  messageText          = null
  ok_fn                = null
  isForced             = false

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
    showObjById("cancelBtn", !this.isForced, this.scene)
  }

  function setContent(view, preset) {
    let data = handyman.renderCached("%gui/weaponry/simplyWeaponryPreset.tpl", {
      tiersView = preset.tiersView.map(@(t) {
        tierId        = t.tierId
        img           = t?.img ?? ""
        tierTooltipId = !showConsoleButtons.get() ? t?.tierTooltipId : null
        isActive      = t?.isActive || "img" in t
      })
    })
    this.guiScene.replaceContentFromText(view, data, data.len(), this)
  }

  function goBack() {
    if(this.isForced && this.ok_fn != null)
      this.ok_fn()

    base.goBack()
  }

  function onPresetChange() {
    if (this.ok_fn != null)
      this.ok_fn()
    base.goBack()
  }
}
register_gui_handler("RestrictionsWeaponryPresetModal", RestrictionsWeaponryPresetModal)

let openRestrictionsWeaponryPreset = @(params) handlersManager.loadHandler(RestrictionsWeaponryPresetModal, params)

return freeze({
  openRestrictionsWeaponryPreset
})