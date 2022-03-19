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

    local obj = getSceneTplContainerObj()
    if (!obj?.isValid())
      return false

    local view = getSceneTplView()
    if (!view)
      return false

    local data = ::handyman.renderCached(sceneTplName, view)

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
    guiScene.performDelayed(this, @() ::handlersManager.startSceneFullReload())
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
    if (isSceneActive())
      popDelayedActions()
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
}
