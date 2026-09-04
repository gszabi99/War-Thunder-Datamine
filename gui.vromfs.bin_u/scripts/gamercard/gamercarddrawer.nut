from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")

enum GamercardDrawerState {
  STATE_CLOSED
  STATE_OPENING
  STATE_OPENED
  STATE_CLOSING
}

let GamercardDrawer = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/gamercardDrawer.blk"
  heightPID = dagui_propid_add_name_id("height")
  currentTarget = null
  currentVisible = false
  currentState = GamercardDrawerState.STATE_CLOSED
  isBlockOtherRestoreFocus = false
  contentBaseTop = null

  function initScreen() {
    this.getObj("gamercard_drawer").setUserData(this)
  }

  function isActive() { 
    if (this.currentState == GamercardDrawerState.STATE_OPENED
        || this.currentState == GamercardDrawerState.STATE_OPENING)
      return true
    return this.currentVisible && checkObj(this.currentTarget)
  }

  function closeDrawer() {
    if (this.currentState == GamercardDrawerState.STATE_CLOSED
        || this.currentState == GamercardDrawerState.STATE_CLOSING)
      return
    this.currentState = GamercardDrawerState.STATE_CLOSING
    this.setOpenAnim(false)
    broadcastEvent("GamercardDrawerAnimationStart", { isOpening = false })
  }

  function openDrawer() {
    if (this.currentState == GamercardDrawerState.STATE_OPENED
        || this.currentState == GamercardDrawerState.STATE_OPENING)
      return
    this.currentState = GamercardDrawerState.STATE_OPENING
    this.setOpenAnim(true)
    broadcastEvent("GamercardDrawerAnimationStart", { isOpening = true })
  }

  function setOpenAnim(open) {
    let gamercardDrawerObject = this.getObj("gamercard_drawer")
    if (!gamercardDrawerObject)
      return

    gamercardDrawerObject.moveOut = open ? "yes" : "no"

    
    
    let timerValue = gamercardDrawerObject["_size-timer"]
    if ((open && timerValue == "1") || (!open && timerValue == "0"))
      this.onDrawerDeactivate(gamercardDrawerObject)
  }

  function updateDrawer(params) {
    let target = params.target
    let visible = params.visible
    this.isBlockOtherRestoreFocus = params?.isBlockOtherRestoreFocus ?? false
    let contentObject = this.getObj("gamercard_drawer_content")
    if (contentObject == null)
      return

    let isTargetChanged = !this.currentTarget || !this.currentTarget.isEqual(target)
    if (!isTargetChanged && visible == this.currentVisible)
      return

    let p = target.getParent()
    if (p?.id == null || p.id != contentObject.id)
      return

    this.currentTarget = target
    this.currentVisible = visible

    
    this.setEnableContent()

    if ((isTargetChanged && this.currentState != GamercardDrawerState.STATE_CLOSED)
        || (!isTargetChanged && !this.currentVisible)) {
      this.closeDrawer()
      return
    }

    this.openCurTargetIfNeeded()
  }

  function openCurTargetIfNeeded() {
    if (!this.currentVisible || !checkObj(this.currentTarget))
      return

    this.updateContentPos()
    this.setShowContent(this.currentTarget)
    this.openDrawer()
  }

  function updateContentPos() {
    let contentObject = this.getObj("gamercard_drawer_content")
    if (!contentObject?.isValid())
      return

    if (this.contentBaseTop == null)
      this.contentBaseTop = contentObject.top

    let statusNestObj = topMenuHandler.get()?.scene.findObject("second_game_modes_status")
    local extraTopExpr = "0"
    if (statusNestObj?.isValid())
      for (local i = 0; i < statusNestObj.childrenCount(); i++) {
        let child = statusNestObj.getChild(i)
        if (!child.isVisible())
          continue
        let childHeight = child.getSize()[1]
        extraTopExpr = childHeight >= 0 ? childHeight.tostring() : "30@sf/@pf"
        break
      }

    contentObject.top = $"{this.contentBaseTop} + {extraTopExpr}"
  }

  function onDrawerOpen(_obj) {
    this.currentState = GamercardDrawerState.STATE_OPENED
    if (this.currentTarget != null)
      this.setEnableContent(this.currentTarget)
    let params = {
      target = this.currentTarget
    }
    broadcastEvent("GamercardDrawerOpened", params)
  }

  function onDrawerClose(_obj) {
    this.currentState = GamercardDrawerState.STATE_CLOSED
    this.openCurTargetIfNeeded()
  }

  function onEventRequestToggleVisibility(params) {
    this.updateDrawer(params)
  }

  function onDrawerDeactivate(obj) {
    if (this.currentState == GamercardDrawerState.STATE_OPENING)
      this.onDrawerOpen(obj)
    else if (this.currentState == GamercardDrawerState.STATE_CLOSING)
      this.onDrawerClose(obj)
  }

  function toggleFuncOnObjs(guiObjFunc, obj = null) {
    let objId = obj?.id
    let contentObject = this.getObj("gamercard_drawer_content")
    if (!contentObject)
      return
    for (local i = 0; i < contentObject.childrenCount(); ++i) {
      let child = contentObject.getChild(i)
      child[guiObjFunc](child?.id == objId)
    }
  }

  function setShowContent(obj = null) {
    this.toggleFuncOnObjs("show", obj)
  }

  function setEnableContent(obj = null) {
    this.toggleFuncOnObjs("enable", obj)
  }
}
register_gui_handler("GamercardDrawer", GamercardDrawer)

return { GamercardDrawer }
