let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { format } = require("string")
let { handlerType } = require("handlerType.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { debug_dump_stack } = require("dagor.debug")
let { PERSISTENT_DATA_PARAMS, registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { broadcastEvent } = subscriptions
let { logerr } = require("%globalScripts/logs.nut")
let { gui_handlers } = require("gui_handlers.nut")

::current_base_gui_handler <- null //active base handler in main gui scene
::always_reload_scenes <- false //debug only

let handlersManager = {
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
                                //but can be overrided by setLastBaseHandlerStartParams

  lastLoadedHandlerName = ""

  setIngameShortcutsActive           = function(_isActive) {}
  beforeClearScene                   = function(_guiScene) {}
  onClearScene                       = function(_guiScene) {}
  isNeedFullReloadAfterClearScene    = function() { return false }
  isNeedReloadSceneSpecific          = function() { return false }
  updatePostLoadCss                  = function() { return false } //return is css was updated
  onSwitchBaseHandler                = function() {}
  onActiveHandlersChanged            = function() {} //called when loaded or switched handlers,
                                                     //loaded or destroyed modal windows (inclode scene_msg_boxes
                                                     //dosn't called twice when single handler load subhandlers on init.
  animatedSwitchScene                = function(startFunc) { startFunc () } //no anim by default
  beforeLoadHandler                  = function(_hType) {}
  onBaseHandlerLoadFailed            = function(_handler) {}
  beforeInitHandler                  = function(_handler) {}
  updateCssParams                    = function(_guiScene) {}

  _loadHandlerRecursionLevel         = 0

  delayedActions                     = []
  delayedActionsGuiScene             = null

  function init() {
    registerPersistentData("handlersManager", this, this[PERSISTENT_DATA_PARAMS])
    subscriptions.subscribe_handler(this, subscriptions.DEFAULT_HANDLER)
  }

  function loadHandler(handlerClass, params = {}) {
    this._loadHandlerRecursionLevel++

    let hType = this.getHandlerType(handlerClass)
    this.beforeLoadHandler(hType)

    let restoreData = this.restoreDataOnLoadHandler?[handlerClass]
    if (restoreData)
      delete this.restoreDataOnLoadHandler[handlerClass]

    if (restoreData?.openData)
      params = params.__merge(restoreData.openData)

    let startTime = get_time_msec()
    let dbgName = this.onLoadHandlerDebug(handlerClass, params)

    local handler = null
    if (hType == handlerType.MODAL)
      handler = this.loadModalHandler(handlerClass, params)
    else if (hType == handlerType.CUSTOM)
      handler = this.loadCustomHandler(handlerClass, params)
    else
      handler = this.loadBaseHandler(handlerClass, params)

    println(format("GuiManager: loading time = %d (%s)", (get_time_msec() - startTime),  dbgName))

    if (restoreData?.stateData)
      handler.restoreHandler(restoreData.stateData)

    this.restoreHandlers(handlerClass)

    if (hType == handlerType.BASE && ::saved_scene_msg_box)
      ::saved_scene_msg_box()

    this._loadHandlerRecursionLevel--
    if (!this._loadHandlerRecursionLevel)
      this.onActiveHandlersChanged()
    if (hType == handlerType.BASE || hType == handlerType.ROOT)
      this.checkActionsDelayGuiScene()
    return handler
  }

  function getHandlerClassName(handlerClass) {
    foreach (name, hClass in gui_handlers)
      if (handlerClass == hClass)
        return name
    return null
  }

  function getHandlerClassDebugName(handlerClass) {
    let className = this.getHandlerClassName(handlerClass)
    if (className)
      return $"gui_handlers.{className}"
    return "".concat(" sceneBlk = ", (handlerClass?.sceneBlkName ?? "null"))
  }

  function onLoadHandlerDebug(handlerClass, _params) {
    let handlerName = this.getHandlerClassDebugName(handlerClass)
    println($"GuiManager: load handler {handlerName}")

    this.lastLoadedHandlerName = handlerName
    return handlerName
  }

  function initHandler(handler) {
    this.beforeInitHandler(handler)

    local result
    try {
      handler.init()
      result = true
    }
    catch (errorMessage) {
      let handlerName = this.getHandlerClassDebugName(handler)
      let message = format("Error on init handler %s:\n%s", handlerName, errorMessage)
      script_net_assert_once(handlerName, message)
      let hType = this.getHandlerType(handler.getclass())
      if (hType == handlerType.MODAL) {
        if (check_obj(handler.scene))
          ::get_cur_gui_scene().destroyElement(handler.scene)
      }
      else if (hType == handlerType.CUSTOM) {
        if (check_obj(handler.scene))
          ::get_cur_gui_scene().replaceContentFromText(handler.scene, "", 0, null)
        handler.scene = null
      }
      else
        this.onBaseHandlerLoadFailed(handler)
      result = false
    }
    return result
  }

  function reinitHandler(handler, params) {
    if ("reinitScreen" in handler)
      handler.reinitScreen(params)
  }

  function destroyHandler(handler) { //destroy handler with it subhandlers.
                                                   //destroy handler scene, so accurate use with custom handlers
    if (!this.isHandlerValid(handler))
      return
    if (handler.guiScene?.isInAct()) { //isInAct appear at 18.11.2020
      script_net_assert_once("destroyHandler", "Try to destroy baseGuiHandler while in dagui::ObjScene::act")
      return
    }

    handler.onDestroy()
    foreach (sh in handler.subHandlers)
      this.destroyHandler(sh)
    handler.guiScene.destroyElement(handler.scene)
  }

  function loadBaseHandler(handlerClass, params = {}) {
    let guiScene = ::get_gui_scene()
    if (guiScene?.isInAct()) { //isInAct appear at 18.11.2020
      script_net_assert_once("loadBaseHandler", "Try to load baseHandler while in dagui::ObjScene::act")
      return null
    }

    let reloadScene = this.updatePostLoadCss() || this.needReloadScene()
    let reload = !handlerClass.keepLoaded || reloadScene
    if (!reload) {
      let handler = this.findAndReinitHandler(handlerClass, params)
      if (handler) {
        this.setLastBaseHandlerStartParamsByHandler(handlerClass, params)
        broadcastEvent("NewSceneLoaded")
        return handler
      }
    }

    if (reloadScene)
      this.clearScene()

    let handler = this.createHandler(handlerClass, guiScene, params)
    let newLoadedRootHandler = this.loadHandlerScene(handler)
    this.switchBaseHandler(handler)

    local initResult = true
    if (newLoadedRootHandler)
      initResult = this.initHandler(newLoadedRootHandler)
    initResult = initResult && this.initHandler(handler)
    if (!initResult)
      return null

    this.handlers[handlerType.BASE].append(handler.weakref())
    this.lastGuiScene = handler.guiScene

    this.setLastBaseHandlerStartParamsByHandler(handlerClass, params)
    broadcastEvent("NewSceneLoaded")
    return handler
  }

  function loadHandlerScene(handler) {
    if (!handler.sceneBlkName) {
      debug_dump_stack()
      assert(false, "Error: cant load base handler w/o sceneBlkName.")
      return null
    }

    let id = $"root_scene_{++this.sceneObjIdx} {handler.sceneBlkName}" //mostly for debug
    if (!handler.rootHandlerClass || this.getHandlerType(handler) != handlerType.BASE) {
      let rootObj = handler.guiScene.getRoot()
      handler.scene = handler.guiScene.createElementByObject(rootObj, handler.sceneBlkName, "rootScene", handler)
      handler.initHandlerSceneTpl()
      handler.scene.id = id
      return null
    }

    local newLoadedRootHandler = null
    let guiScene = ::get_cur_gui_scene()
    local rootHandler = this.findHandlerClassInScene(handler.rootHandlerClass)
    if (!this.isHandlerValid(rootHandler, true)) {
      rootHandler = handler.rootHandlerClass(guiScene, {})
      this.loadHandlerScene(rootHandler)
      this.handlers[handlerType.ROOT].append(rootHandler.weakref())
      subscriptions.subscribe_handler(rootHandler)
      newLoadedRootHandler = rootHandler
    }

    let rootObj = rootHandler.getBaseHandlersContainer() || guiScene.getRoot()
    handler.scene = guiScene.createElementByObject(rootObj, handler.sceneBlkName, "rootScene", handler)
    handler.scene.id = id
    handler.rootHandlerWeak = rootHandler.weakref()
    return newLoadedRootHandler
  }

  function loadModalHandler(handlerClass, params = {}) {
    if (!handlerClass.sceneBlkName && !handlerClass.sceneTplName) {
      debug_dump_stack()
      assert(handlerClass.sceneBlkName != null, "Error: cant load modal handler w/o sceneBlkName or sceneTplName.")
      return null
    }
    local handler = this.findHandlerClassInScene(handlerClass)
    if (handler && !handlerClass.multipleInstances) {
      this.reinitHandler(handler, params)
      return handler
    }

    let guiScene = ::get_gui_scene()
    handler = this.createHandler(handlerClass, guiScene, params)
    this.handlers[handlerType.MODAL].append(handler.weakref())

    let scene = guiScene.loadModal("", handler.sceneBlkName || "%gui/emptyScene.blk", "rootScene", handler)
    scene.id = $"modal_wnd_{++this.sceneObjIdx} {handler.sceneBlkName}" //mostly for debug
    handler.scene = scene

    handler.initHandlerSceneTpl()
    let initResult = this.initHandler(handler)
    if (!initResult)
      return null

    return handler
  }

  function loadCustomHandler(handlerClass, params = {}) {
    let guiScene = ::get_gui_scene()
    let handler = this.createHandler(handlerClass, guiScene, params)
    if (!handler.sceneBlkName && !handler.sceneTplName) {
      debug_dump_stack()
      assert(false, "Error: cant load custom handler w/o sceneBlkName or sceneTplName.")
      return null
    }

    if (!handler.initCustomHandlerScene())
      this.loadHandlerScene(handler)
    let initResult = this.initHandler(handler)
    if (!initResult)
      return null

    this.handlers[handlerType.CUSTOM].append(handler.weakref())
    return handler
  }

  function createHandler(handlerClass, guiScene, params) {
    let handler = handlerClass(guiScene, params)
    subscriptions.subscribe_handler(handler)
    return handler
  }

  function findAndReinitHandler(handlerClass, params) {
    let curHandler = this.getActiveBaseHandler()
    if (curHandler && curHandler.getclass() == handlerClass) {
      this.reinitHandler(curHandler, params)
      return curHandler
    }

    let handler = this.findHandlerClassInScene(handlerClass)
    if (!handler)
      return null

    this.switchBaseHandler(handler)
    this.reinitHandler(handler, params)
    return handler
  }

  function switchBaseHandler(handler) {
    let guiScene = ::get_cur_gui_scene()
    this.closeAllModals(guiScene)

    let curHandler = this.getActiveBaseHandler()
    this.showBaseHandler(curHandler, false)
    this.onBaseHandlerSwitch()
    if (handler) {
      this.switchRootHandlerChecked(handler.rootHandlerClass)
      this.showBaseHandler(handler, true)
    }

    this.removeHandlerFromListByGuiScene(this.activeBaseHandlers, guiScene)

    if (handler)
      this.activeBaseHandlers.append(handler)

    if (this.isMainGuiSceneActive())
      ::current_base_gui_handler = handler

    this.updateLoadingFlag()

    this.onSwitchBaseHandler()

    broadcastEvent("SwitchedBaseHandler")
  }

  function switchRootHandlerChecked(rootHandlerClass) {
    let curRootHandler = this.getActiveRootHandler()
    if ((!curRootHandler && !rootHandlerClass)
        || (curRootHandler && curRootHandler.getclass() == rootHandlerClass))
      return

    if (curRootHandler)
      this.showBaseHandler(curRootHandler, false)

    this.removeHandlerFromListByGuiScene(this.activeRootHandlers, ::get_cur_gui_scene())

    let newRootHandler = rootHandlerClass && this.findHandlerClassInScene(rootHandlerClass)
    if (newRootHandler) {
      this.activeRootHandlers.append(newRootHandler)
      this.showBaseHandler(newRootHandler, true)
    }
  }

  function removeHandlerFromListByGuiScene(list, guiScene) {
    for (local i = list.len() - 1; i >= 0; i--) {
      let h = list[i]
      if (!h || !h.guiScene || guiScene.isEqual(h.guiScene))
        list.remove(i)
    }
  }

  function onBaseHandlerSwitch() {
    ::reset_msg_box_check_anim_time() //no need msg box anim right after scene switch
  }

  function showBaseHandler(handler, show) {
    if (!this.isHandlerValid(handler, false))
      return this.clearInvalidHandlers()

    if (!show && !handler.keepLoaded) {
      this.destroyHandler(handler)
      this.clearInvalidHandlers()
      return
    }

    handler.scene.show(show)
    handler.scene.enable(show)
    if ("onSceneActivate" in handler)
      handler.onSceneActivate(show)
  }

  getRootScreenBlkPath = @() "%gui/rootScreen.blk"

  //if guiScene == null, will be used current scene
  function clearScene(guiScene = null) {
    if (!guiScene)
      guiScene = ::get_cur_gui_scene()
    if (guiScene?.isInAct()) { //isInAct appear at 18.11.2020
      script_net_assert_once("clearSceneInAct", "Try to clear scene while in dagui::ObjScene::act")
      return
    }

    this.sendEventToHandlers("onDestroy", guiScene)

    this.beforeClearScene(guiScene)

    guiScene.loadScene(this.getRootScreenBlkPath(), this)

    this.updateCssParams(guiScene)
    //this.setGuiRootOptions(guiScene, false) // need to uncomment after merging with baseGuiHandlerManagerWT
    this.startActionsDelay()
    guiScene.initCursor("%gui/cursor.blk", "normal")
    if (!guiScene.isEqual(::get_cur_gui_scene())) {
      this.onClearScene(guiScene)
      broadcastEvent("GuiSceneCleared", { guiScene })
      return
    }

    this.lastGuiScene = guiScene

    if (!this.isNeedFullReloadAfterClearScene())
      this.needFullReload = false

    this.updateLoadingFlag()
    this.onClearScene(guiScene)
    broadcastEvent("GuiSceneCleared", { guiScene })
  }

  function updateLoadingFlag() {
    let oldVal = this.isInLoading
    this.isInLoading = !this.isMainGuiSceneActive()
                  || (!this.getActiveBaseHandler() && !this.getActiveRootHandler()) //empty screen count as loading too

    if (oldVal != this.isInLoading)
      broadcastEvent("LoadingStateChange")
  }

  function emptyScreen() {
    println("GuiManager: load emptyScreen")
    this.setLastBaseHandlerStartParams({ globalFunctionName = "gui_start_empty_screen" })
    this.lastLoadedHandlerName = "emptyScreen"

    if (this.updatePostLoadCss() || this.getActiveBaseHandler() || this.getActiveRootHandler() || this.needReloadScene())
      this.clearScene()
    this.switchBaseHandler(null)

    if (!this._loadHandlerRecursionLevel)
      this.onActiveHandlersChanged()
  }

  function isMainGuiSceneActive() {
    return ::get_cur_gui_scene().isEqual(::get_main_gui_scene())
  }

  function needReloadScene() {
    return this.needFullReload || ::always_reload_scenes || !check_obj(::get_cur_gui_scene()["root_loaded"])
           || this.isNeedReloadSceneSpecific()
  }

  function startSceneFullReload(startSceneParams = null) {
    startSceneParams = startSceneParams ?? this.getLastBaseHandlerStartParams()
    if (startSceneParams == null)
      return

    this.needFullReload = true
    this.isFullReloadInProgress = true
    this.callStartFunc(startSceneParams)
    this.isFullReloadInProgress = false
  }

  function markfullReloadOnSwitchScene(needReloadOnActivateHandlerToo = true) {
    this.needFullReload = true
    if (!needReloadOnActivateHandlerToo)
      return

    let handler = this.getActiveBaseHandler()
    if (handler)
      handler.doWhenActiveOnce("fullReloadScene")
  }

  function onEventScriptsReloaded(_p) {
    this.markfullReloadOnSwitchScene(false)
    let startData = this.findLastBaseHandlerStartData(::get_gui_scene())
    if (!startData)
      return

    let { startParams } = startData
    let backSceneParams = this.getActiveBaseHandler()?.backSceneParams
    if (backSceneParams)
      startData.startParams = backSceneParams
    this.activeBaseHandlers.clear()
    this.callStartFunc(startParams)
  }

  function checkPostLoadCssOnBackToBaseHandler() {
    this.needCheckPostLoadCss = true
  }

  function checkPostLoadCss(isForced = false) {
    if (!this.needCheckPostLoadCss && !isForced)
      return false
    let handler = this.getActiveBaseHandler()
    if (!handler || !handler.isSceneActiveNoModals())
      return false

    this.needCheckPostLoadCss = false
    if (!this.updatePostLoadCss())
      return false

    handler.fullReloadScene()
    return true
  }

  function onEventModalWndDestroy(_p) {
    if (!this.checkPostLoadCss() && !this._loadHandlerRecursionLevel)
      this.onActiveHandlersChanged()
  }

  function onEventMsgBoxCreated(_p) {
    if (!this._loadHandlerRecursionLevel)
      this.onActiveHandlersChanged()
  }

  function isModal(handlerClass) {
    return this.getHandlerType(handlerClass) == handlerType.MODAL
  }

  function getHandlerType(handlerClass) {
    return handlerClass.wndType
  }

  function isHandlerValid(handler, checkGuiScene = false) {
    return handler != null && handler.isValid() && (!checkGuiScene || handler.isInCurrentScene())
  }

  function clearInvalidHandlers() {
    foreach (_hType, group in this.handlers)
      for (local i = group.len() - 1; i >= 0; i--)
        if (!this.isHandlerValid(group[i], false))
          group.remove(i)
  }

  function closeAllModals(guiScene = null) {
    if ((guiScene ?? ::get_cur_gui_scene())?.isInAct()) { //isInAct appear at 18.11.2020
      script_net_assert_once("closeAllModals", "Try to close all modals while in dagui::ObjScene::act")
      return
    }

    ::destroy_all_msg_boxes(guiScene)

    let group = this.handlers[handlerType.MODAL]
    for (local i = group.len() - 1; i >= 0; i--) {
      let handler = group[i]
      if (guiScene && handler && !guiScene.isEqual(handler.guiScene))
        continue

      this.destroyHandler(handler)
      group.remove(i)
    }
  }

  function destroyModal(handler) {
    if (!this.isHandlerValid(handler, true))
      return
    if (handler.guiScene?.isInAct()) { //isInAct appear at 18.11.2020
      script_net_assert_once("destroyModal", "Try to destroy modal window while in dagui::ObjScene::act")
      return
    }

    foreach (idx, h in this.handlers[handlerType.MODAL])
      if (this.isHandlerValid(h, true) && h.scene.isEqual(handler.scene)) {
        this.handlers[handlerType.MODAL].remove(idx)
        break
      }
    this.destroyHandler(handler)
  }

  function findHandlerClassInScene(searchClass, checkGuiScene = true) {
    let searchType = this.getHandlerType(searchClass)
    if (searchType in this.handlers)
      foreach (handler in this.handlers[searchType])
        if (!searchClass || (handler && handler.getclass() == searchClass)) {
          if (this.isHandlerValid(handler, checkGuiScene))
            return handler
        }
    return null
  }

  function isAnyModalHandlerActive() {
    foreach (handler in this.handlers[handlerType.MODAL])
      if (this.isHandlerValid(handler, true))
        return true
    return false
  }

  function getActiveBaseHandler() {
    let curGuiScene = ::get_cur_gui_scene()
    foreach (handler in this.activeBaseHandlers)
      if (handler.guiScene && handler.guiScene.isEqual(curGuiScene) && this.isHandlerValid(handler, false))
        return handler
    return null
  }

  function getActiveRootHandler() {
    let curGuiScene = ::get_cur_gui_scene()
    foreach (handler in this.activeRootHandlers)
      if (handler.guiScene && handler.guiScene.isEqual(curGuiScene) && this.isHandlerValid(handler, false))
        return handler
    return null
  }

  function sendEventToHandlers(eventFuncName, guiScene = null, params = null) {
    foreach (_hType, hList in this.handlers)
      foreach (handler in hList)
        if (this.isHandlerValid(handler)
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
  function requestHandlerRestore(restoreHandler, triggerHandlerClass = null) {
    let restoreData = restoreHandler.getHandlerRestoreData()
    if (restoreData == null) // Not implemented.
      return false
    restoreData.handlerClass <- restoreHandler.getclass()
    if (triggerHandlerClass == null)
      triggerHandlerClass = this.getActiveBaseHandler()
    if (!triggerHandlerClass)
      return false

    if (triggerHandlerClass == restoreData.handlerClass) {
      this.restoreDataOnLoadHandler[restoreData.handlerClass] <- restoreData
      return true
    }

    this.restoreDataByTriggerHandler[triggerHandlerClass] <- restoreData
    return true
  }

  /**
   * Restores handlers requested by specified trigger-handler.
   * Does nothing if no restore data found.
   */
  function restoreHandlers(triggerHandlerClass) {
    let restoreData = this.restoreDataByTriggerHandler?[triggerHandlerClass]
    if (restoreData == null)
      return
    this.restoreDataByTriggerHandler[triggerHandlerClass] <- null

    let openData = restoreData?.openData
    let handler = this.loadHandler(restoreData.handlerClass, openData || {})

    let stateData = restoreData?.stateData
    if (stateData != null)
      handler.restoreHandler(stateData)
  }

  function findLastBaseHandlerStartData(guiScene) {
    for (local i = this.lastBaseHandlerStartData.len() - 1; i >= 0; i--)
      if (this.lastBaseHandlerStartData[i].guiScene.isEqual(guiScene))
        return this.lastBaseHandlerStartData[i]
    return null
  }

  function getLastBaseHandlerStartParams(guiScene = null) {
    if (!guiScene)
      guiScene = ::get_gui_scene()
    return this.findLastBaseHandlerStartData(guiScene)?.startParams
  }

  function setLastBaseHandlerStartParams(startParams, guiScene = null, handlerLocId = null) {
    if (!guiScene)
      guiScene = ::get_gui_scene()
    local data = this.findLastBaseHandlerStartData(guiScene)
    if (!data) {
      data = { guiScene, startParams = {}, handlerLocId }
      this.lastBaseHandlerStartData.append(data)
    }
    data.startParams = startParams
    data.handlerLocId = handlerLocId
  }
  function setLastBaseHandlerStartParamsByHandler(handlerClass, params) {
    let handlerClassName = this.getHandlerClassName(handlerClass)
    this.setLastBaseHandlerStartParams({ handlerName = handlerClassName, params },
      null, handlerClass?.handlerLocId)
  }

  function destroyPrevHandlerAndLoadNew(handlerClass, params, needDestroyIfAlreadyOnTop = false) {
    local isNewHandlerCreated = true
    let prevHandler = this.findHandlerClassInScene(handlerClass)
    if (prevHandler)
      if (!needDestroyIfAlreadyOnTop && prevHandler.scene.getModalCounter() == 0)
        isNewHandlerCreated = false
      else
        this.destroyModal(prevHandler)

    this.loadHandler(handlerClass, params)
    return isNewHandlerCreated
  }

  //run delayed action same with guiScene.performDelayed, but it will survive guiScene reload and switch
  function doDelayed(action) {
    this.delayedActions.append(action)
    if (this.delayedActions.len() == 1)
      this.startActionsDelay()
  }

  function startActionsDelay() {
    if (!this.delayedActions.len())
      return
    this.delayedActionsGuiScene = ::get_cur_gui_scene()
    this.delayedActionsGuiScene.performDelayed(this, function() {
      this.delayedActionsGuiScene = null
      let actions = clone this.delayedActions
      this.delayedActions.clear()
      foreach (action in actions)
        action()
    })
  }

  function checkActionsDelayGuiScene() {
    if (this.delayedActions.len()
      && (!this.delayedActionsGuiScene || !this.delayedActionsGuiScene.isEqual(::get_cur_gui_scene())))
      this.startActionsDelay()
  }

  function onEventSignOut(_) {
    this.restoreDataOnLoadHandler.clear()
    this.restoreDataByTriggerHandler.clear()
  }

  function callStartFunc(startParams) {
    let { globalFunctionName = null, handlerName = "", params = null } = startParams
    if (globalFunctionName != null) {
      let startFunc = getroottable()?[globalFunctionName]
      if (startFunc == null) {
        logerr($"[GuiManager] Global function '{globalFunctionName}' for start handler not found")
        return
      }
      if (params == null)
        return startFunc()
      return startFunc(params)
    }

    let hClass = gui_handlers?[handlerName]
    if (hClass == null) {
      logerr($"[GuiManager] Handler name '{handlerName}' not found in gui_handlers list")
      return
    }

    this.loadHandler(hClass, params ?? {})
  }
}
//=======================  global functions  ==============================

::isHandlerInScene <- function isHandlerInScene(handlerClass) {
  return handlersManager.findHandlerClassInScene(handlerClass) != null
}
::gui_start_modal_wnd <- function gui_start_modal_wnd(handlerClass, params = {}) { //only for basic handlers with sceneBlkName predefined
  return handlersManager.loadHandler(handlerClass, params)
}

::is_in_loading_screen <- function is_in_loading_screen() {
  return handlersManager.isInLoading
}

return {
  handlersManager
}