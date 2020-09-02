local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local { isPlatformSony,
        isPlatformXboxOne,
        targetPlatform } = require("scripts/clientState/platform.nut")

global const PERSISTENT_DATA_PARAMS = "PERSISTENT_DATA_PARAMS"

::dagui_propid.add_name_id("has_ime")
::dagui_propid.add_name_id("target_platform")

::current_base_gui_handler <- null //active base handler in main gui scene
::always_reload_scenes <- false //debug only

::handlersManager <- {
  [PERSISTENT_DATA_PARAMS] = ["lastBaseHandlerStartData", "activeBaseHandlers"]

  handlers = { //handlers weakrefs
    [handlerType.ROOT] = [],
    [handlerType.BASE] = [],
    [handlerType.MODAL] = [],
    [handlerType.CUSTOM] = []
  }
  activeBaseHandlers = [] //one  per guiScene
  activeRootHandlers = [] //not more than one per guiScene
  sceneObjIdx = -1
  lastGuiScene = null
  needFullReload = false
  needCheckPostLoadCss = false
  isFullReloadInProgress = false
  isInLoading = true
  restoreDataOnLoadHandler = {}
  restoreDataByTriggerHandler = {}
  lastBaseHandlerStartData = [] //functions list (by guiScenes) to start backScene or to reload current base handler
                                //automatically set on loadbaseHandler
                                //but can be overrided by setLastBaseHandlerStartFunc

  lastLoadedHandlerName = ""

  setIngameShortcutsActive           = function(isActive) {}
  beforeClearScene                   = function(guiScene) {}
  onClearScene                       = function(guiScene) {}
  isNeedFullReloadAfterClearScene    = function() { return false }
  isNeedReloadSceneSpecific          = function() { return false }
  updatePostLoadCss                  = function() { return false } //return is css was updated
  onSwitchBaseHandler                = function() {}
  onActiveHandlersChanged            = function() {} //called when loaded or switched handlers,
                                                     //loaded or destroyed modal windows (inclode scene_msg_boxes
                                                     //dosn't called twice when single handler load subhandlers on init.
  animatedSwitchScene                = function(startFunc) { startFunc () } //no anim by default
  beforeLoadHandler                  = function(hType) {}
  onBaseHandlerLoadFailed            = function(handler) {}
  beforeInitHandler                  = function(handler) {}

  _loadHandlerRecursionLevel         = 0

  delayedActions                     = []
  delayedActionsGuiScene             = null

  function init()
  {
    ::g_script_reloader.registerPersistentDataFromRoot("handlersManager")
    subscriptions.subscribeHandler(::handlersManager, subscriptions.DEFAULT_HANDLER)
  }

  function loadHandler(handlerClass, params = {})
  {
    _loadHandlerRecursionLevel++

    local hType = getHandlerType(handlerClass)
    beforeLoadHandler(hType)

    local restoreData = restoreDataOnLoadHandler?[handlerClass]
    if (restoreData)
      delete restoreDataOnLoadHandler[handlerClass]

    if (restoreData?.openData)
      params = ::u.extend({}, params, restoreData.openData)

    local startTime = ::dagor.getCurTime()
    local dbgName = onLoadHandlerDebug(handlerClass, params)

    local handler = null
    if (hType == handlerType.MODAL)
      handler = loadModalHandler(handlerClass, params)
    else if (hType==handlerType.CUSTOM)
      handler = loadCustomHandler(handlerClass, params)
    else
      handler = loadBaseHandler(handlerClass, params)

    ::dagor.debug(format("GuiManager: loading time = %d (%s)", (::dagor.getCurTime() - startTime),  dbgName))

    if (restoreData?.stateData)
      handler.restoreHandler(restoreData.stateData)

    restoreHandlers(handlerClass)

    if (hType == handlerType.BASE && ::saved_scene_msg_box)
      ::saved_scene_msg_box()

    _loadHandlerRecursionLevel--
    if (!_loadHandlerRecursionLevel)
      onActiveHandlersChanged()
    if (hType == handlerType.BASE || hType == handlerType.ROOT)
      checkActionsDelayGuiScene()
    return handler
  }

  function getHandlerClassName(handlerClass)
  {
    foreach(name, hClass in ::gui_handlers)
      if (handlerClass == hClass)
        return name
    return null
  }

  function getHandlerClassDebugName(handlerClass)
  {
    local className = getHandlerClassName(handlerClass)
    if (className)
      return "::gui_handlers." + className
    return " sceneBlk = " + (handlerClass?.sceneBlkName ?? "null")
  }

  function onLoadHandlerDebug(handlerClass, params)
  {
    local handlerName = getHandlerClassDebugName(handlerClass)
    ::dagor.debug("GuiManager: load handler " + handlerName)

    lastLoadedHandlerName = handlerName
    return handlerName
  }

  function initHandler(handler)
  {
    beforeInitHandler(handler)

    local result
    try
    {
      handler.init()
      result = true
    }
    catch (errorMessage)
    {
      local handlerName = getHandlerClassDebugName(handler)
      local message = ::format("Error on init handler %s:\n%s", handlerName, errorMessage)
      ::script_net_assert_once(handlerName, message)
      local hType = getHandlerType(handler.getclass())
      if (hType == handlerType.MODAL)
      {
        if (::check_obj(handler.scene))
          ::get_cur_gui_scene().destroyElement(handler.scene)
      }
      else if (hType == handlerType.CUSTOM)
      {
        if (::check_obj(handler.scene))
          ::get_cur_gui_scene().replaceContentFromText(handler.scene, "", 0, null)
        handler.scene = null
      }
      else
        onBaseHandlerLoadFailed(handler)
      result = false
    }
    return result
  }

  function reinitHandler(handler, params)
  {
    if ("reinitScreen" in handler)
      handler.reinitScreen(params)
  }

  function destroyHandler(handler) //destroy handler with it subhandlers.
                                                   //destroy handler scene, so accurate use with custom handlers
  {
    if (!isHandlerValid(handler))
      return

    handler.onDestroy()
    foreach(sh in handler.subHandlers)
      destroyHandler(sh)
    handler.guiScene.destroyElement(handler.scene)
  }

  function loadBaseHandler(handlerClass, params = {})
  {
    local reloadScene = updatePostLoadCss() || needReloadScene()
    local reload = !handlerClass.keepLoaded || reloadScene
    if (!reload)
    {
      local handler = findAndReinitHandler(handlerClass, params)
      if (handler)
      {
        setLastBaseHandlerStartFuncByHandler(handlerClass, params)
        ::broadcastEvent("NewSceneLoaded")
        return handler
      }
    }

    if (reloadScene)
      clearScene()

    local guiScene = ::get_gui_scene()
    local handler = createHandler(handlerClass, guiScene, params)
    local newLoadedRootHandler = loadHandlerScene(handler)
    switchBaseHandler(handler)

    local initResult = true
    if (newLoadedRootHandler)
      initResult = initHandler(newLoadedRootHandler)
    initResult = initResult && initHandler(handler)
    if (!initResult)
      return null

    handlers[handlerType.BASE].append(handler.weakref())
    lastGuiScene = handler.guiScene

    setLastBaseHandlerStartFuncByHandler(handlerClass, params)
    ::broadcastEvent("NewSceneLoaded")
    return handler
  }

  function loadHandlerScene(handler)
  {
    if (!handler.sceneBlkName)
    {
      callstack()
      ::dagor.assertf(false, "Error: cant load base handler w/o sceneBlkName.")
      return null
    }

    local id = "root_scene_" + ++sceneObjIdx + " " + handler.sceneBlkName //mostly for debug
    if (!handler.rootHandlerClass || getHandlerType(handler) != handlerType.BASE)
    {
      local rootObj = handler.guiScene.getRoot()
      handler.scene = handler.guiScene.createElementByObject(rootObj, handler.sceneBlkName, "rootScene", handler)
      handler.initHandlerSceneTpl()
      handler.scene.id = id
      return null
    }

    local newLoadedRootHandler = null
    local guiScene = ::get_cur_gui_scene()
    local rootHandler = findHandlerClassInScene(handler.rootHandlerClass)
    if (!isHandlerValid(rootHandler, true))
    {
      rootHandler = handler.rootHandlerClass(guiScene, {})
      loadHandlerScene(rootHandler)
      handlers[handlerType.ROOT].append(rootHandler.weakref())
      subscriptions.subscribeHandler(rootHandler)
      newLoadedRootHandler = rootHandler
    }

    local rootObj = rootHandler.getBaseHandlersContainer() || guiScene.getRoot()
    handler.scene = guiScene.createElementByObject(rootObj, handler.sceneBlkName, "rootScene", handler)
    handler.scene.id = id
    handler.rootHandlerWeak = rootHandler.weakref()
    return newLoadedRootHandler
  }

  function loadModalHandler(handlerClass, params = {})
  {
    if (!handlerClass.sceneBlkName && !handlerClass.sceneTplName)
    {
      callstack()
      ::dagor.assertf(handlerClass.sceneBlkName!=null, "Error: cant load modal handler w/o sceneBlkName or sceneTplName.")
      return null
    }
    local handler = findHandlerClassInScene(handlerClass)
    if (handler && !handlerClass.multipleInstances)
    {
      reinitHandler(handler, params)
      return handler
    }

    local guiScene = ::get_gui_scene()
    handler = createHandler(handlerClass, guiScene, params)
    handlers[handlerType.MODAL].append(handler.weakref())

    local scene = guiScene.loadModal("", handler.sceneBlkName || "gui/emptyScene.blk", "rootScene", handler)
    scene.id = "modal_wnd_" + ++sceneObjIdx + " " + handler.sceneBlkName //mostly for debug
    handler.scene = scene

    handler.initHandlerSceneTpl()
    local initResult = initHandler(handler)
    if (!initResult)
      return null

    return handler
  }

  function loadCustomHandler(handlerClass, params = {})
  {
    local guiScene = ::get_gui_scene()
    local handler = createHandler(handlerClass, guiScene, params)
    if (!handler.sceneBlkName && !handler.sceneTplName)
    {
      callstack()
      ::dagor.assertf(false, "Error: cant load custom handler w/o sceneBlkName or sceneTplName.")
      return null
    }

    if (!handler.initCustomHandlerScene())
      loadHandlerScene(handler)
    local initResult = initHandler(handler)
    if (!initResult)
      return null

    handlers[handlerType.CUSTOM].append(handler.weakref())
    return handler
  }

  function createHandler(handlerClass, guiScene, params)
  {
    local handler = handlerClass(guiScene, params)
    subscriptions.subscribeHandler(handler)
    return handler
  }

  function findAndReinitHandler(handlerClass, params)
  {
    local curHandler = getActiveBaseHandler()
    if (curHandler && curHandler.getclass() == handlerClass)
    {
      reinitHandler(curHandler, params)
      return curHandler
    }

    local handler = findHandlerClassInScene(handlerClass)
    if (!handler)
      return null

    switchBaseHandler(handler)
    reinitHandler(handler, params)
    return handler
  }

  function switchBaseHandler(handler)
  {
    local guiScene = ::get_cur_gui_scene()
    closeAllModals(guiScene)

    local curHandler = getActiveBaseHandler()
    showBaseHandler(curHandler, false)
    onBaseHandlerSwitch()
    if (handler)
    {
      switchRootHandlerChecked(handler.rootHandlerClass)
      showBaseHandler(handler, true)
    }

    removeHandlerFromListByGuiScene(activeBaseHandlers, guiScene)

    if (handler)
      activeBaseHandlers.append(handler)

    if (isMainGuiSceneActive())
      ::current_base_gui_handler = handler

    updateLoadingFlag()

    onSwitchBaseHandler()

    ::broadcastEvent("SwitchedBaseHandler")
  }

  function switchRootHandlerChecked(rootHandlerClass)
  {
    local curRootHandler = getActiveRootHandler()
    if ((!curRootHandler && !rootHandlerClass)
        || (curRootHandler && curRootHandler.getclass() == rootHandlerClass))
      return

    if (curRootHandler)
      showBaseHandler(curRootHandler, false)

    removeHandlerFromListByGuiScene(activeRootHandlers, ::get_cur_gui_scene())

    local newRootHandler = rootHandlerClass && findHandlerClassInScene(rootHandlerClass)
    if (newRootHandler)
    {
      activeRootHandlers.append(newRootHandler)
      showBaseHandler(newRootHandler, true)
    }
  }

  function removeHandlerFromListByGuiScene(list, guiScene)
  {
    for(local i = list.len()-1; i >= 0; i--)
    {
      local h = list[i]
      if (!h || !h.guiScene || guiScene.isEqual(h.guiScene))
        list.remove(i)
    }
  }

  function onBaseHandlerSwitch()
  {
    ::reset_msg_box_check_anim_time() //no need msg box anim right after scene switch
  }

  function showBaseHandler(handler, show)
  {
    if (!isHandlerValid(handler, false))
      return clearInvalidHandlers()

    if (!show && !handler.keepLoaded)
    {
      destroyHandler(handler)
      clearInvalidHandlers()
      return
    }

    handler.scene.show(show)
    handler.scene.enable(show)
    if ("onSceneActivate" in handler)
      handler.onSceneActivate(show)
  }

  //if guiScene == null, will be used current scene
  function clearScene(guiScene = null)
  {
    if (!guiScene)
      guiScene = ::get_cur_gui_scene()
    sendEventToHandlers("onDestroy", guiScene)

    beforeClearScene(guiScene)

    guiScene.loadScene("gui/rootScreen.blk", this)

    setGuiRootOptions(guiScene, false)
    startActionsDelay()
    guiScene.initCursor("gui/cursor.blk", "normal")
    if (!guiScene.isEqual(::get_cur_gui_scene()))
    {
      onClearScene(guiScene)
      ::broadcastEvent("GuiSceneCleared")
      return
    }

    lastGuiScene = guiScene

    if (!isNeedFullReloadAfterClearScene())
      needFullReload = false

    updateLoadingFlag()
    onClearScene(guiScene)
    ::broadcastEvent("GuiSceneCleared")
  }

  function updateLoadingFlag()
  {
    local oldVal = isInLoading
    isInLoading = !isMainGuiSceneActive()
                  || (!getActiveBaseHandler() && !getActiveRootHandler())//empty screen count as loading too

    if (oldVal != isInLoading)
      ::broadcastEvent("LoadingStateChange")
  }

  function emptyScreen()
  {
    ::dagor.debug("GuiManager: load emptyScreen")
    setLastBaseHandlerStartFunc(function() { ::handlersManager.emptyScreen() })
    lastLoadedHandlerName = "emptyScreen"

    if (updatePostLoadCss() || getActiveBaseHandler() || getActiveRootHandler() || needReloadScene())
      clearScene()
    switchBaseHandler(null)

    if (!_loadHandlerRecursionLevel)
      onActiveHandlersChanged()
  }

  function isMainGuiSceneActive()
  {
    return ::get_cur_gui_scene().isEqual(::get_main_gui_scene())
  }

  function setGuiRootOptions(guiScene, forceUpdate = true)
  {
    local rootObj = guiScene.getRoot()

    rootObj["show_console_buttons"] = ::show_console_buttons ? "yes" : "no" //should to force box buttons in WoP?
    if ("ps4_is_circle_selected_as_enter_button" in ::getroottable() && ::ps4_is_circle_selected_as_enter_button())
      rootObj["swap_ab"] = "yes";

    //Check for special hints, because IME is called with special action, and need to show text about it
    local hasIME = isPlatformSony || isPlatformXboxOne || ::is_platform_android || ::is_steam_big_picture()
    rootObj["has_ime"] = hasIME? "yes" : "no"

    rootObj["target_platform"] = targetPlatform

    if (!forceUpdate)
      return

    rootObj["css-hier-invalidate"] = "all"  //need to update scene after set this parameters
    guiScene.performDelayed(this, function() {
      if (::check_obj(rootObj))
        rootObj["css-hier-invalidate"] = "no"
    })
  }

  function needReloadScene()
  {
    return needFullReload || ::always_reload_scenes || !::check_obj(::get_cur_gui_scene()["root_loaded"])
           || isNeedReloadSceneSpecific()
  }

  function startSceneFullReload(startSceneFunc = null)
  {
    startSceneFunc = startSceneFunc || getLastBaseHandlerStartFunc()
    if (!startSceneFunc)
      return

    needFullReload = true
    isFullReloadInProgress = true
    startSceneFunc()
    isFullReloadInProgress = false
  }

  function markfullReloadOnSwitchScene(needReloadOnActivateHandlerToo = true)
  {
    needFullReload = true
    if (!needReloadOnActivateHandlerToo)
      return

    local handler = ::handlersManager.getActiveBaseHandler()
    if (handler)
      handler.doWhenActiveOnce("fullReloadScene")
  }

  function onEventScriptsReloaded(p)
  {
    markfullReloadOnSwitchScene(false)
    local startData = findLastBaseHandlerStartData(::get_gui_scene())
    if (!startData)
      return

    local startFunc = startData.startFunc
    local backSceneFunc = getActiveBaseHandler()?.backSceneFunc
    if (backSceneFunc)
      startData.startFunc = backSceneFunc
    activeBaseHandlers.clear()
    startFunc()
  }

  function checkPostLoadCssOnBackToBaseHandler()
  {
    needCheckPostLoadCss = true
  }

  function checkPostLoadCss(isForced = false)
  {
    if (!needCheckPostLoadCss && !isForced)
      return false
    local handler = ::handlersManager.getActiveBaseHandler()
    if (!handler || !handler.isSceneActiveNoModals())
      return false

    needCheckPostLoadCss = false
    if (!updatePostLoadCss())
      return false

    handler.fullReloadScene()
    return true
  }

  function onEventModalWndDestroy(p)
  {
    if (!checkPostLoadCss() && !_loadHandlerRecursionLevel)
      onActiveHandlersChanged()
  }

  function onEventMsgBoxCreated(p)
  {
    if (!_loadHandlerRecursionLevel)
      onActiveHandlersChanged()
  }

  function isModal(handlerClass)
  {
    return getHandlerType(handlerClass) == handlerType.MODAL
  }

  function getHandlerType(handlerClass)
  {
    return handlerClass.wndType
  }

  function isHandlerValid(handler, checkGuiScene = false)
  {
    return handler != null && handler.isValid() && (!checkGuiScene || handler.isInCurrentScene())
  }

  function clearInvalidHandlers()
  {
    foreach(hType, group in handlers)
      for(local i = group.len()-1; i >= 0; i--)
        if (!isHandlerValid(group[i], false))
          group.remove(i)
  }

  function closeAllModals(guiScene = null)
  {
    ::destroy_all_msg_boxes(guiScene)

    local group = handlers[handlerType.MODAL]
    for(local i = group.len()-1; i >= 0; i--)
    {
      local handler = group[i]
      if (guiScene && handler && !guiScene.isEqual(handler.guiScene))
        continue

      destroyHandler(handler)
      group.remove(i)
    }
  }

  function destroyModal(handler)
  {
    if (!isHandlerValid(handler, true))
      return

    foreach(idx, h in handlers[handlerType.MODAL])
      if (isHandlerValid(h, true) && h.scene.isEqual(handler.scene))
      {
        handlers[handlerType.MODAL].remove(idx)
        break
      }
    destroyHandler(handler)
  }

  function findHandlerClassInScene(searchClass, checkGuiScene = true)
  {
    local searchType = getHandlerType(searchClass)
    if (searchType in handlers)
      foreach(handler in handlers[searchType])
        if (!searchClass || (handler && handler.getclass() == searchClass))
        {
          if (isHandlerValid(handler, checkGuiScene))
            return handler
        }
    return null
  }

  function isAnyModalHandlerActive()
  {
    foreach(handler in handlers[handlerType.MODAL])
      if (isHandlerValid(handler, true))
        return true
    return false
  }

  function getActiveBaseHandler()
  {
    local curGuiScene = ::get_cur_gui_scene()
    foreach(handler in activeBaseHandlers)
      if (handler.guiScene && handler.guiScene.isEqual(curGuiScene) && isHandlerValid(handler, false))
        return handler
    return null
  }

  function getActiveRootHandler()
  {
    local curGuiScene = ::get_cur_gui_scene()
    foreach(handler in activeRootHandlers)
      if (handler.guiScene && handler.guiScene.isEqual(curGuiScene) && isHandlerValid(handler, false))
        return handler
    return null
  }

  function sendEventToHandlers(eventFuncName, guiScene = null, params = null)
  {
    foreach(hType, hList in handlers)
      foreach(handler in hList)
        if (isHandlerValid(handler)
            && (!guiScene || handler.guiScene.isEqual(guiScene))
            && eventFuncName in handler && type(handler[eventFuncName]) == "function")
          if (params)
            handler[eventFuncName].call(handler, params)
          else
            handler[eventFuncName].call(handler)
  }

  /**
   * Finds handler with class 'restoreHandlerClass' and re-opens
   * it after 'triggerHandlerClass' was inited.
   *
   * @param restoreHandler Handler to be restored.
   * @param triggerHandlerClass Class of handler that triggers window restore.
   * Current base handler if used if this parameter not specified.
   * If triggerHandlerClass is equal restoreHandler class, then this handler will not
   * be loaded by trigger, but its data will be restored when it will be loaded next time.
   * @return False if windows restoration failed. Occures if window
   * handler was not found or getHandlerRestoreData is not implemented.
   */
  function requestHandlerRestore(restoreHandler, triggerHandlerClass = null)
  {
    local restoreData = restoreHandler.getHandlerRestoreData()
    if (restoreData == null) // Not implemented.
      return false
    restoreData.handlerClass <- restoreHandler.getclass()
    if (triggerHandlerClass == null)
      triggerHandlerClass = getActiveBaseHandler()
    if (!triggerHandlerClass)
      return false

    if (triggerHandlerClass == restoreData.handlerClass)
    {
      restoreDataOnLoadHandler[restoreData.handlerClass] <- restoreData
      return true
    }

    local restoreDataArray = restoreDataByTriggerHandler?[triggerHandlerClass] || []
    restoreDataArray.append(restoreData)
    restoreDataByTriggerHandler[triggerHandlerClass] <- restoreDataArray
    return true
  }

  /**
   * Restores handlers requested by specified trigger-handler.
   * Does nothing if no restore data found.
   */
  function restoreHandlers(triggerHandlerClass)
  {
    local restoreDataArray = restoreDataByTriggerHandler?[triggerHandlerClass]
    if (restoreDataArray == null)
      return
    restoreDataByTriggerHandler[triggerHandlerClass] <- null
    for (local i = 0; i < restoreDataArray.len(); ++i) // First in - first out.
    {
      local restoreData = restoreDataArray[i]

      local openData = restoreData?.openData
      local handler = loadHandler(restoreData.handlerClass, openData || {})

      local stateData = restoreData?.stateData
      if (stateData != null)
        handler.restoreHandler(stateData)
    }
  }

  function findLastBaseHandlerStartData(guiScene)
  {
    for(local i = lastBaseHandlerStartData.len() - 1; i >= 0; i--)
      if (lastBaseHandlerStartData[i].guiScene.isEqual(guiScene))
        return lastBaseHandlerStartData[i]
    return null
  }

  function getLastBaseHandlerStartFunc(guiScene = null)
  {
    if (!guiScene)
      guiScene = ::get_gui_scene()
    local data = findLastBaseHandlerStartData(guiScene)
    return data && data.startFunc
  }

  function setLastBaseHandlerStartFunc(startFunc, guiScene = null)
  {
    if (!guiScene)
      guiScene = ::get_gui_scene()
    local data = findLastBaseHandlerStartData(guiScene)
    if (!data)
    {
      data = { guiScene = guiScene, startFunc = null }
      lastBaseHandlerStartData.append(data)
    }
    data.startFunc = startFunc
  }

  function setLastBaseHandlerStartFuncByHandler(handlerClass, params)
  {
    local handlerClassName = getHandlerClassName(handlerClass)
    setLastBaseHandlerStartFunc(function() {
                                 local hClass = ::gui_handlers?[handlerClassName] ?? handlerClass
                                 ::handlersManager.loadHandler(hClass, params)
                               })
  }

  function destroyPrevHandlerAndLoadNew(handlerClass, params, needDestroyIfAlreadyOnTop = false)
  {
    local isNewHandlerCreated = true
    local prevHandler = findHandlerClassInScene(handlerClass)
    if (prevHandler)
      if (!needDestroyIfAlreadyOnTop && prevHandler.scene.getModalCounter() == 0)
        isNewHandlerCreated = false
      else
        destroyModal(prevHandler)

    loadHandler(handlerClass, params)
    return isNewHandlerCreated
  }

  //run delayed action same with guiScene.performDelayed, but it will survive guiScene reload and switch
  function doDelayed(action)
  {
    delayedActions.append(action)
    if (delayedActions.len() == 1)
      startActionsDelay()
  }

  function startActionsDelay()
  {
    if (!delayedActions.len())
      return
    delayedActionsGuiScene = ::get_cur_gui_scene()
    delayedActionsGuiScene.performDelayed(this, function()
    {
      delayedActionsGuiScene = null
      local actions = clone delayedActions
      delayedActions.clear()
      foreach(action in actions)
        action()
    })
  }

  function checkActionsDelayGuiScene() {
    if (delayedActions.len()
      && (!delayedActionsGuiScene || !delayedActionsGuiScene.isEqual(::get_cur_gui_scene())))
      startActionsDelay()
  }
}
//=======================  global functions  ==============================

::isHandlerInScene <- function isHandlerInScene(handlerClass)
{
  return ::handlersManager.findHandlerClassInScene(handlerClass) != null
}
::gui_start_modal_wnd <- function gui_start_modal_wnd(handlerClass, params = {}) //only for basic handlers with sceneBlkName predefined
{
  return ::handlersManager.loadHandler(handlerClass, params)
}

::is_in_loading_screen <- function is_in_loading_screen()
{
  return ::handlersManager.isInLoading
}
