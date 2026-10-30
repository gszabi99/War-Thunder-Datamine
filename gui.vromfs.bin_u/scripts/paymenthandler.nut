from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/dagui_library.nut" import *

let PaymentHandler = class (BaseGuiHandlerWT) {
  wndType         = handlerType.MODAL
  sceneBlkName    = "%gui/payment.blk"

  items = []
  cancel_fn = null

  function initScreen() {
    this.initPaymentsList()
  }

  function initPaymentsList() {
    let paymentsObj = this.scene.findObject("content")
    foreach (idx, item in this.items) {
      let payItem = this.guiScene.createElementByObject(paymentsObj, "%gui/paymentItem.blk", "paymentItem", this)
      payItem.id = $"payment_{idx}"
      payItem.tooltip = loc((item?.name ?? ""))
      payItem.findObject("payIcon")["background-image"] = (item?.icon ?? "")
      payItem.findObject("payText").setValue((item?.icon ?? "") == "" ? loc((item?.name ?? "")) : "")
    }
    move_mouse_on_child(paymentsObj)
  }

  function onPaymentSelect(obj) {
    if (!obj)
      return
    if (!this.items)
      return
    let item = this.items[(obj.id.slice(8)).tointeger()]
    if ("callback" in item && item.callback)
      item.callback()
    this.goBack()
  }
}
register_gui_handler("PaymentHandler", PaymentHandler)

let openPaymentWnd = @(params) loadHandler(PaymentHandler, params)

return freeze({
  openPaymentWnd
})
