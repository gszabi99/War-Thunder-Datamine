::gui_modal_payment <- function gui_modal_payment(params)
{
  ::gui_start_modal_wnd(::gui_handlers.PaymentHandler, params)
}

::gui_handlers.PaymentHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType         = handlerType.MODAL
  sceneBlkName    = "%gui/payment.blk"
  owner           = null

  items = []
  selItem = null
  cancel_fn = null

  function initScreen()
  {
    initPaymentsList()
  }

  function initPaymentsList()
  {
    let paymentsObj = scene.findObject("content")
    foreach (idx, item in items)
    {
      let payItem = guiScene.createElementByObject(paymentsObj, "%gui/paymentItem.blk", "paymentItem", this)
      payItem.id = "payment_"+idx
      payItem.tooltip = ::loc(getTblValue("name", item, ""))
      payItem.findObject("payIcon")["background-image"] = getTblValue("icon", item, "")
      payItem.findObject("payText").setValue(getTblValue("icon", item, "")=="" ? ::loc(getTblValue("name", item, "")) : "")
    }
    ::move_mouse_on_child(paymentsObj)
  }

  function onPaymentSelect(obj)
  {
    if (!obj)
      return
    if (!items)
      return
    let item = items[(obj.id.slice(8)).tointeger()]
    if ("callback" in item && item.callback)
      if (owner)
        item.callback.call(owner)
    goBack()
  }
}
