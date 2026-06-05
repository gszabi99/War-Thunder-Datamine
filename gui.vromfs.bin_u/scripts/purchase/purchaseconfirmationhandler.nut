from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { get_balance } = require("%scripts/user/balance.nut")
let { maxAllowedWarbondsBalance } = require("%scripts/warbonds/warbondsState.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_game_params_blk } = require("blkGetters")

local confirmationWpEdge = -1

local purchaseConfirmationHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/purchase/purchaseConfirmation.blk"
  id = ""
  text = ""
  warbond = null
  callbackYes = null
  callbackNo = null
  onExitFunc = null
  customButtons = null

  function initScreen() {
    this.scene.findObject("msgText").setValue(this.text)
    this.scene.findObject("gc_warpoints").show(hasFeature("WarpointsInMenu"))
    this.scene.findObject("gc_eagles").show(hasFeature("SpendGold"))
    let { wp, gold } = get_balance()
    this.scene.findObject("gc_balance").setValue(decimalFormat(wp))
    this.scene.findObject("gc_gold").setValue(decimalFormat(gold))
    this.updateWarbonds()
    println($"GuiManager: load msgbox = {this.id}")

    let buttonsHolder = this.scene.findObject("buttons_holder")
    if (this.customButtons) {
      local markUp = ""
      local btnIndex = 0
      foreach (button in this.customButtons) {
        let buttonView = { id = $"btn_{btnIndex}", text = loc(button.text), funcName = "onCustomBtnClick" }
        markUp = "".concat(markUp, handyman.renderCached("%gui/commonParts/button.tpl", buttonView))
        btnIndex++
      }
      this.guiScene.replaceContentFromText(buttonsHolder, markUp, markUp.len(), this)
    }
    this.guiScene.applyPendingChanges(false)
    buttonsHolder.select()
  }

  function updateWarbonds() {
    let needShowWarbonds = this.warbond != null
    let warbondsObj = this.scene.findObject("gc_warbonds")
    warbondsObj.show(needShowWarbonds)
    if (!needShowWarbonds)
      return
    let text = loc("warbonds/currentAmount", { warbonds = this.warbond.getBalanceText() })
    let tooltip = loc("warbonds/maxAmount", { warbonds = maxAllowedWarbondsBalance.get() })
    let textObj = warbondsObj.findObject("warbonds_text")
    textObj.setValue(text)
    textObj.tooltip = tooltip
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

  function onCustomBtnClick(btn) {
    let btnIndex = to_integer_safe(btn.id.split("_")[1])
    this.customButtons[btnIndex].cb()
    base.goBack()
  }

  function onDummyA() {
    if (!this.isValid())
      return
    let buttonsHolder = this.scene.findObject("buttons_holder")
    let activeButtonindex = this.getHoveredButtonIndex() ?? buttonsHolder.getValue()
    if (this.customButtons?[activeButtonindex] != null) {
      this.customButtons[activeButtonindex].cb()
      base.goBack()
      return
    }
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

  function onDestroy() {
    this.onExitFunc?()
  }
}

gui_handlers.purchaseConfirmationHandler <- purchaseConfirmationHandler


function needPurchaseConfirmation(cost) {
  if (cost?.isZero())
    return false
  let wpCost = cost?.wp ?? 0
  if (wpCost == 0)
    return true

  let currentWp = get_balance().wp
  if (confirmationWpEdge < 0) {
    let gameParams = get_game_params_blk()
    confirmationWpEdge = gameParams?.purchaseConfirmationWpEdge ?? 0
  }
  if (wpCost < currentWp * confirmationWpEdge)
    return false
  return true
}

function purchaseConfirmation(params, cost = null) {
  if (cost && !needPurchaseConfirmation(cost)) {
    params?.callbackYes()
    return
  }
  handlersManager.loadHandler(purchaseConfirmationHandler, params)
}

return {
  needPurchaseConfirmation
  purchaseConfirmation
}