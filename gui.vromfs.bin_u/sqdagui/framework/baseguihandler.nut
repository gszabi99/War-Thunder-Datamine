class ::BaseGuiHandler
{
  wndType = handlerType.BASE
  sceneBlkName = "gui/emptyScene.blk"
  sceneNavBlkName = null
  sceneTplName = null //load scene tpl when sceneBlkNmae == null. only work with custom handlers yet.
  keepLoaded = false
  needAnimatedSwitchScene = true
  multipleInstances = false
  rootHandlerClass = null //handlerType.BASE will be created and visible together with listed root handler
                          //but they also can be created without root handler

  guiScene = null
  scene = null     //obj where scene loaded.

  backSceneFunc = null //function to start previous scene on goBack
  subHandlers = null //subhandlers list to automatically forward @onSceneActivate event and other
  delayedActions = null
  rootHandlerWeak = null

  focusArray = null
  isPrimaryFocus = true
  defaultFocusArray = [
    function() { return getMainFocusObj() }       //main focus obj of handler
    function() { return getMainFocusObj2() }      //main focus obj of handler
    function() { return getMainFocusObj3() }      //main focus obj of handler
    function() { return getMainFocusObj4() }      //main focus obj of handler
  ]
  currentFocusItem = 1 //main focus obj

  constructor(gui_scene, params = {})
  {
    guiScene = gui_scene
    delayedActions = []
    subHandlers = []

    //must be before setParams
    if (wndType == handlerType.BASE)
      backSceneFunc = ::handlersManager.getLastBaseHandlerStartFunc()

    setParams(params)
  }

  function init() //init handler after scene full loaded
  {
    loadNavBar()
    initScreen()
  }

  function setParams(params)
  {
    foreach(name, value in params)
      if (name in this)
        this[name] = value
  }

  function initCustomHandlerScene()
  {
    if (!::check_obj(scene))
      return false

    guiScene = scene.getScene()

    if (sceneBlkName)
    {
      guiScene.replaceContent(scene, sceneBlkName, this)
      return true
    }

    return initHandlerSceneTpl()
  }

  function initHandlerSceneTpl()
  {
    if (!sceneTplName)
      return false

    local view = getSceneTplView()
    if (!view)
      return false

    local data = ::handyman.renderCached(sceneTplName, view)
    local obj = getSceneTplContainerObj()
    if (!::check_obj(obj))
      return false

    guiScene.replaceContentFromText(obj, data, data.len(), this)
    return true
  }

  function getSceneTplView() { return null }
  function getSceneTplContainerObj() { return scene }

  function initScreen() {}
  function onDestroy()  {}

  function isValid()
  {
    return ::check_obj(scene)
  }

  function isInCurrentScene()
  {
    return guiScene.isEqual(::get_cur_gui_scene())
  }

  function loadNavBar()
  {
    local markup = getNavbarMarkup()
    if(!markup && !sceneNavBlkName)
      return
    local obj = scene.findObject("nav-help")
    if (!::check_obj(obj))
      return

    if (markup)
      guiScene.replaceContentFromText(obj, markup, markup.len(), this)
    else
      guiScene.replaceContent(obj, sceneNavBlkName, this)
  }

  function getNavbarMarkup() { return null }

  function isSceneActive()
  {
    return ::check_obj(scene) && scene.isEnabled()
  }

  function isSceneActiveNoModals()
  {
    return isSceneActive() && scene.getModalCounter() == 0
  }

  //************** only for wndType == handlerType.ROOT *****************//
  function getBaseHandlersContainer()
  {
    return null
  }
  function onNewContentLoaded(handler) {}

  function onEventNewSceneLoaded(p)
  {
    if (wndType != handlerType.ROOT)
      return

    local handler = getCurActiveContentHandler()
    if (handler)
      onNewContentLoaded(handler)
  }

  function getCurActiveContentHandler()
  {
    local handler = ::handlersManager.getActiveBaseHandler()
    return (handler && handler.rootHandlerClass == getclass()) ? handler : null
  }
  //************** end of only for wndType == handlerType.ROOT *****************//

  function getObj(name)
  {
    if (!::check_obj(scene))
      return null
    return scene.findObject(name)
  }

  function showSceneBtn(id, status)
  {
    return ::showBtn(id, status, scene)
  }

  function msgBox(id, text, buttons, def_btn, options = {})
  {
    for (local i = 0; i < ::gui_scene_boxes.len(); i++)
    {
      if (::gui_scene_boxes[i].id == id)
        return null
    }
    if (!options)
      options = {}
    options.baseHandler <- this
    return scene_msg_box(id, guiScene, text, buttons, def_btn, options)
  }

  function onMsgLink(obj)
  {
    ::open_url_by_obj(obj)
  }

  function goForward(startFunc, needFade=true)
  {
    if (!startFunc)
      return

    if (needFade)
      ::handlersManager.animatedSwitchScene(startFunc)
    else
      startFunc()
  }

  function fullReloadScene()
  {
    ::handlersManager.startSceneFullReload()
  }

  function afterModalDestroy() {}

  function onModalWndDestroy()
  {
    afterModalDestroy()
    ::broadcastEvent("ModalWndDestroy", { handler = this })
  }

  function goBack()
  {
    if (wndType == handlerType.MODAL)
    {
      guiScene.performDelayed(this, function()
      {
        ::handlersManager.destroyHandler(this)
        ::handlersManager.clearInvalidHandlers()

        onModalWndDestroy()
      })
      return
    }

    if (wndType == handlerType.BASE && backSceneFunc != null)
    {
      if (needAnimatedSwitchScene)
        ::handlersManager.animatedSwitchScene(backSceneFunc)
      else
        backSceneFunc()
    }
  }

  function setBackSceneFunc(scene_func)
  {
    backSceneFunc = scene_func
  }

  function onSceneActivate(show)
  {
    if (show)
      popDelayedActions()
    foreach(handler in subHandlers)
      if (::handlersManager.isHandlerValid(handler))
        handler.onSceneActivate(show)
  }

  _isPopActionsInProgress = false
  function popDelayedActions()
  {
    if (_isPopActionsInProgress)
      return
    _isPopActionsInProgress = true
    while(delayedActions.len() > 0)
    {
      if (!checkActiveForDelayedAction())
        break

      local action = delayedActions.remove(0)
      if (typeof(action) == "string" && action in this)
        this[action]()
      else if (typeof(action) == "function")
        action()
    }
    _isPopActionsInProgress = false
  }

  function checkActiveForDelayedAction()
  {
    return isSceneActiveNoModals()
  }

  function doWhenActive(func)
  {
    if (isSceneActiveNoModals())
    {
      if (typeof(func) == "function")
        func()
      else
        ::dagor.assertf(false, "doWhenActive recieved " + func + ", instead of function")
    }
    else
      delayedActions.append(func)
  }

  function doWhenActiveOnce(funcName)
  {
    ::dagor.assertf(typeof(funcName) == "string", "Error: doWhenActiveOnce work only with function names")

    local prevIdx = delayedActions.indexof(funcName)
    if (prevIdx != null)
      delayedActions.remove(prevIdx)
    delayedActions.append(funcName)
    popDelayedActions()
  }

  function onEventModalWndDestroy(params)
  {
    if (!isSceneActive())
      return

    if (!rootHandlerWeak)
      delayedRestoreFocus()
    popDelayedActions()
  }

  function onEventCustomFocusObjLost(params)
  {
    if (!rootHandlerWeak)
      delayedRestoreFocus()
  }

  function delayedRestoreFocus()
  {
    guiScene.performDelayed(this, function() {
      restoreFocus()
    })
  }

  canRestoreFocus = @() true

  function restoreFocus(checkPrimaryFocus = true)
  {
    if ((checkPrimaryFocus && !isPrimaryFocus) || !isSceneActiveNoModals())
      return
    if (rootHandlerWeak)
      return rootHandlerWeak.restoreFocus()

    if (!focusArray || !focusArray.len())
      return

    if (!canRestoreFocus())
      return
    if (wndType == handlerType.ROOT)
    {
      local h = getCurActiveContentHandler()
      if (h && !h.canRestoreFocus())
        return
    }

    checkCurrentFocusItem(guiScene.getSelectedObject())

    if (currentFocusItem < 0 || currentFocusItem >= focusArray.len())
      currentFocusItem = focusArray.len() - 1
    local focusObj = getObjByConfigItem(focusArray[currentFocusItem])
    if (::check_obj(focusObj) && focusObj.isVisible() && focusObj.isEnabled())
    {
      focusObj.select()
      onFocusItemSelected(focusObj)
    } else
      wrapNextSelect(::check_obj(focusObj)? focusObj : null, 1)
  }

  function getObjByConfigItem(item)
  {
    if (type(item)=="function")
      item = item()
    if (type(item)=="string")
      return scene.findObject(item)
    return item
  }

  function initFocusArray()
  {
    if (!focusArray)
      focusArray = defaultFocusArray
    restoreFocus()
  }

  function onEventOutsideObjWrap(p) //{ obj, dir }
  {
    if (rootHandlerWeak || !isPrimaryFocus || !isSceneActiveNoModals() || !("obj" in p))
      return

    local dir = ("dir" in p)? p.dir : 1
    wrapNextSelect(p.obj, dir)
  }

  function onWrapUp(obj)
  {
    wrapNextSelect(obj, -1)
  }

  function onWrapDown(obj)
  {
    wrapNextSelect(obj, 1)
  }

  function onWrapLeft(obj)  {}
  function onWrapRight(obj) {}

  function wrapNextSelect(obj = null, dir = 0)
  {
    if (rootHandlerWeak)
      return rootHandlerWeak.wrapNextSelect(obj, dir)

    if (dir == 0 || !focusArray || !focusArray.len())
      return

    checkCurrentFocusItem(obj)

    local newObj = null
    local sendBroadcast = false

    for(local i = 0; i < focusArray.len(); i++)
    {
      currentFocusItem += dir
      if (currentFocusItem < 0 )
        if (isPrimaryFocus)
          currentFocusItem = focusArray.len() - 1
        else
          sendBroadcast = true
      if (currentFocusItem >= focusArray.len())
        if (isPrimaryFocus)
          currentFocusItem = 0
        else
          sendBroadcast = true

      if (sendBroadcast)
        return broadcastEvent("OutsideObjWrap", { obj = obj, dir = dir })

      newObj = getFocusItemObj(currentFocusItem)
      if (newObj)
        break
    }
    if (!newObj)
      return

    newObj.select()
    onFocusItemSelected(newObj)
  }

  function onFocusItemSelected(obj)
  {
  }

  function getFocusItemObj(idx, onlyAvailable = true)
  {
    local res = null
    if (!(idx in focusArray))
      return res
    res = getObjByConfigItem(focusArray[idx])
    if (::check_obj(res) && (!onlyAvailable || (res.isVisible() && res.isEnabled())))
      return res
    return null
  }

  function setCurrentFocusObj(obj)
  {
    if (rootHandlerWeak)
      return rootHandlerWeak.setCurrentFocusObj(obj)

    if(!::check_obj(obj) || !focusArray)
      return
    obj.select()
    checkCurrentFocusItem(obj)
  }

  function checkCurrentFocusItem(obj)
  {
    if (rootHandlerWeak)
      return rootHandlerWeak.checkCurrentFocusItem()

    if(!::check_obj(obj) || !focusArray)
      return false
    foreach(idx, item in focusArray)
    {
      local itemObj = getObjByConfigItem(item)
      if(itemObj != null && itemObj.isEqual(obj))
      {
        currentFocusItem = idx
        return true
      }
    }
    return false
  }

  function findObjInFocusArray(onlyFocused = true, onlyAvailable = true)
  {
    if (!::check_obj(scene))
      return null
    local res = null
    foreach(idx, item in focusArray)
    {
      local itemObj = getObjByConfigItem(item)
      if (::check_obj(itemObj))
      {
        if (itemObj.isFocused())
          return itemObj
        if (onlyFocused)
          continue

        if (!res && (!onlyAvailable || (itemObj.isVisible() && itemObj.isEnabled())))
          res = itemObj
      }
    }
    return res
  }

  /**
   * Return value must be table with following data format:
   * {
   *   openData = ... // Data to be used during handler open process.
   *   stateData = ... // Data to be used during handler state restore.
   * }
   */
  function getHandlerRestoreData()
  {
    return null
  }

  /**
   * Restores handler to state described in specified state data.
   */
  function restoreHandler(stateData)
  {
  }

  function registerSubHandler(handler)
  {
    if (!::handlersManager.isHandlerValid(handler))
      return

    //clear outdated subHandlers
    for(local i = subHandlers.len() - 1; i >= 0; i--)
      if (!::handlersManager.isHandlerValid(subHandlers[i]))
        subHandlers.remove(i)

    subHandlers.append(handler.weakref())
  }

  function getMainFocusObj()  { return null }
  function getMainFocusObj2() { return null }
  function getMainFocusObj3() { return null }
  function getMainFocusObj4() { return null }
}
