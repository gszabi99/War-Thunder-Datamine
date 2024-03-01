from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { get_balance } = require("%scripts/user/balance.nut")

local purchaseConfirmationHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/purchase/purchaseConfirmation.blk"
  id = ""
  text = ""
  callbackYes = null
  callbackNo = null

  function initScreen() {
    this.scene.findObject("msgText").setValue(this.text)
    this.scene.findObject("gc_warpoints").show(hasFeature("WarpointsInMenu"))
    this.scene.findObject("gc_eagles").show(hasFeature("SpendGold"))
    let { wp, gold } = get_balance()
    this.scene.findObject("gc_balance").setValue(decimalFormat(wp))
    this.scene.findObject("gc_gold").setValue(decimalFormat(gold))
    println($"GuiManager: load msgbox = {this.id}")
    this.guiScene.applyPendingChanges(false)
    this.scene.findObject("buttons_holder").select()
  }

  function onButtonYes() {
    if(this.callbackYes != null)
      this.callbackYes()
    base.goBack()
  }

  function onButtonNo() {
    if(this.callbackNo != null)
      this.callbackNo()
    base.goBack()
  }

  function onDummyA() {
    let buttonsHolder = this.scene.findObject("buttons_holder")
    let activeButtonindex = this.getHoveredButtonIndex() ?? buttonsHolder.getValue()
    if(activeButtonindex == 0)
      this.onButtonYes()
    else
      this.onButtonNo()
  }

  function getHoveredButtonIndex() {
    let buttonsHolder = this.scene.findObject("buttons_holder")
    let total = buttonsHolder.childrenCount()
    for (local i = 0; i < total; i++)
      if (buttonsHolder.getChild(i).isHovered())
        return i
    return null
  }
}

gui_handlers.purchaseConfirmationHandler <- purchaseConfirmationHandler

function purchaseConfirmation(id, text, callbackYes, callbackNo = null) {
  handlersManager.loadHandler(purchaseConfirmationHandler, { id, text, callbackYes, callbackNo })
}

return purchaseConfirmation