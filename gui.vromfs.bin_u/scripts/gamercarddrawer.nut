//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

enum GamercardDrawerState {
  STATE_CLOSED
  STATE_OPENING
  STATE_OPENED
  STATE_CLOSING
}

gui_handlers.GamercardDrawer <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/gamercardDrawer.blk"
  heightPID = dagui_propid_add_name_id("height")
  currentTarget = null
  currentVisible = false
  currentState = GamercardDrawerState.STATE_CLOSED
  isBlockOtherRestoreFocus = false

  function initScreen() {
    this.getObj("gamercard_drawer").setUserData(this)
  }

  function isActive() { //opening, opened, or closing to open again
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

    //if we already at finish state, there will be no anim event.
    //so we need to call it self to go to the next state
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

    // Disable all objects.
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

    this.setShowContent(this.currentTarget)
    this.openDrawer()
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
    switch (this.currentState) {
      case GamercardDrawerState.STATE_OPENING:
        this.onDrawerOpen(obj)
        break
      case GamercardDrawerState.STATE_CLOSING:
        this.onDrawerClose(obj)
        break
    }
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
