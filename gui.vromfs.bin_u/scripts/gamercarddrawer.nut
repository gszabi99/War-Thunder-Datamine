enum GamercardDrawerState
{
  STATE_CLOSED
  STATE_OPENING
  STATE_OPENED
  STATE_CLOSING
}

::gui_handlers.GamercardDrawer <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/gamercardDrawer.blk"
  heightPID = ::dagui_propid.add_name_id("height")
  currentTarget = null
  currentVisible = false
  currentState = GamercardDrawerState.STATE_CLOSED
  isBlockOtherRestoreFocus = false

  function initScreen()
  {
    getObj("gamercard_drawer").setUserData(this)
  }

  function isActive() //opening, opened, or closing to open again
  {
    if (currentState == GamercardDrawerState.STATE_OPENED
        || currentState == GamercardDrawerState.STATE_OPENING)
      return true
    return currentVisible && ::check_obj(currentTarget)
  }

  function closeDrawer()
  {
    if (currentState == GamercardDrawerState.STATE_CLOSED
        || currentState == GamercardDrawerState.STATE_CLOSING)
      return
    currentState = GamercardDrawerState.STATE_CLOSING
    setOpenAnim(false)
    ::broadcastEvent("GamercardDrawerAnimationStart", { isOpening = false })
  }

  function openDrawer()
  {
    if (currentState == GamercardDrawerState.STATE_OPENED
        || currentState == GamercardDrawerState.STATE_OPENING)
      return
    currentState = GamercardDrawerState.STATE_OPENING
    setOpenAnim(true)
    ::broadcastEvent("GamercardDrawerAnimationStart", { isOpening = true })
  }

  function setOpenAnim(open)
  {
    let gamercardDrawerObject = getObj("gamercard_drawer")
    if (!gamercardDrawerObject)
      return

    gamercardDrawerObject.moveOut = open ? "yes" : "no"

    //if we already at finish state, there will be no anim event.
    //so we need to call it self to go to the next state
    let timerValue = gamercardDrawerObject["_size-timer"]
    if ((open && timerValue == "1") || (!open && timerValue == "0"))
      onDrawerDeactivate(gamercardDrawerObject)
  }

  function updateDrawer(params)
  {
    let target = params.target
    let visible = params.visible
    isBlockOtherRestoreFocus = params?.isBlockOtherRestoreFocus ?? false
    let contentObject = getObj("gamercard_drawer_content")
    if (contentObject == null)
      return

    let isTargetChanged = !currentTarget || !currentTarget.isEqual(target)
    if (!isTargetChanged && visible == currentVisible)
      return

    let p = target.getParent()
    if (p?.id == null || p.id != contentObject.id)
      return

    currentTarget = target
    currentVisible = visible

    // Disable all objects.
    setEnableContent()

    if ((isTargetChanged && currentState != GamercardDrawerState.STATE_CLOSED)
        || (!isTargetChanged && !currentVisible))
    {
      closeDrawer()
      return
    }

    openCurTargetIfNeeded()
  }

  function openCurTargetIfNeeded()
  {
    if (!currentVisible || !::checkObj(currentTarget))
      return

    setShowContent(currentTarget)
    openDrawer()
  }

  function onDrawerOpen(obj)
  {
    currentState = GamercardDrawerState.STATE_OPENED
    if (currentTarget != null)
      setEnableContent(currentTarget)
    let params = {
      target = currentTarget
    }
    ::broadcastEvent("GamercardDrawerOpened", params)
  }

  function onDrawerClose(obj)
  {
    currentState = GamercardDrawerState.STATE_CLOSED
    openCurTargetIfNeeded()
  }

  function onEventRequestToggleVisibility(params)
  {
    updateDrawer(params)
  }

  function onDrawerDeactivate(obj)
  {
    switch (currentState)
    {
      case GamercardDrawerState.STATE_OPENING:
        onDrawerOpen(obj)
        break
      case GamercardDrawerState.STATE_CLOSING:
        onDrawerClose(obj)
        break
    }
  }

  function toggleFuncOnObjs(guiObjFunc, obj = null)
  {
    let objId = obj?.id
    let contentObject = getObj("gamercard_drawer_content")
    if (!contentObject)
      return
    for (local i = 0; i < contentObject.childrenCount(); ++i)
    {
      let child = contentObject.getChild(i)
      child[guiObjFunc](child?.id == objId)
    }
  }

  function setShowContent(obj = null)
  {
    toggleFuncOnObjs("show", obj)
  }

  function setEnableContent(obj = null)
  {
    toggleFuncOnObjs("enable", obj)
  }
}
