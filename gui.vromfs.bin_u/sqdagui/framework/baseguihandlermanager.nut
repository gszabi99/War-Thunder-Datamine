from "%sqDagui/daguiNativeApi.nut" import *

let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { format } = require("string")
let { handlerType } = require("handlerType.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { logerr, debug_dump_stack } = require("dagor.debug")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { broadcastEvent } = subscriptions
let { gui_handlers } = require("gui_handlers.nut")
let { reset_msg_box_check_anim_time, destroy_all_msg_boxes, saved_scene_msg_box } = require("msgBox.nut")
let { eventbus_has_listeners, eventbus_send } = require("eventbus")
let { register_command } = require("console")

local current_base_gui_handler = null 
local always_reload_scenes = false 


                                
                                
let lastBaseHandlerStartData = persist("lastBaseHandlerStartData", @() [])

let activeBaseHandlers = persist("activeBaseHandlers", @() []) 

let handlersManager = {
  handlers = { 
    [handlerType.ROOT] = [],
    [handlerType.BASE] = [],
    [handlerType.MODAL] = [],
    [handlerType.CUSTOM] = []
  }
  activeBaseHandlers
  activeRootHandlers = [] 
  sceneObjIdx = -1
  lastGuiScene = null
  needFullReload = false
  needCheckPostLoadCss = false
  isFullReloadInProgress = false
  isInLoading = true
  restoreDataOnLoadHandler = {}
  restoreDataByTriggerHandler = {}
  lastBaseHandlerStartData

  lastLoadedHandlerName = ""

  setIngameShortcutsActive           = function(_isActive) {}
  beforeClearScene                   = function(_guiScene) {}
  onClearScene                       = function(_guiScene) {}
  isNeedFullReloadAfterClearScene    = function() { return false }
  isNeedReloadSceneSpecific          = function() { return false }
  updatePostLoadCss                  = function() { return false } 
  onSwitchBaseHandler                = function() {}
  onActiveHandlersChanged            = function() {} 
                                                     
                                                     
  animatedSwitchScene                = function(startFunc) { startFunc () } 
  beforeLoadHandler                  = function(_hType) {}
  onBaseHandlerLoadFailed            = function(_handler) {}
  beforeInitHandler                  = function(_handler) {}
  updateCssParams                    = function(_guiScene) {}

  _loadHandlerRecursionLevel         = 0

  delayedActions                     = []
  delayedActionsGuiScene             = null

  function init() {
    subscriptions.subscribe_handler(this, subscriptions.DEFAULT_HANDLER)
  }

  function loadHandler(handlerClass, params = {}) {
    this._loadHandlerRecursionLevel++

    let hType = this.getHandlerType(handlerClass)
    this.beforeLoadHandler(hType)

    let restoreData = this.restoreDataOnLoadHandler?[handlerClass]
    if (restoreData)
      this.restoreDataOnLoadHandler.$rawdelete(handlerClass)

    if (restoreData?.openData)
      params = params.__merge(restoreData.openData)

    let startTime = get_time_msec()
    let dbgName = this.onLoadHandlerDebug(handlerClass, params)

    local handler = null
    if (hType == handlerType.MODAL)
      handler = this.loadModalHandler(handlerClass, params)
    else if (hType == handlerType.CUSTOM)
      handler = this.loadCustomHandler(handlerClass, params)
    else {
      if (this.isFullReloadInProgress) 
        this.setLastBaseHandlerBackSceneParams()
      handler = this.loadBaseHandler(handlerClass, params)
    }

    println(format("GuiManager: loading time = %d (%s)", (get_time_msec() - startTime),  dbgName))

    if (restoreData?.stateData)
      handler.restoreHandler(restoreData.stateData)

    this.restoreHandlers(handlerClass)

    if (hType == handlerType.BASE && saved_scene_msg_box.value!=null)
      saved_scene_msg_box.value()

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
          get_cur_gui_scene().destroyElement(handler.scene)
      }
      else if (hType == handlerType.CUSTOM) {
        if (check_obj(handler.scene))
          get_cur_gui_scene().replaceContentFromText(handler.scene, "", 0, null)
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

  function destroyHandler(handler) { 
                                                   
    if (!this.isHandlerValid(handler))
      return
    if (handler.guiScene?.isInAct()) { 
      script_net_assert_once("destroyHandler", "Try to destroy baseGuiHandler while in dagui:ObjScene:act")
      return
    }

    handler.onDestroy()
    foreach (sh in handler.subHandlers)
      this.destroyHandler(sh)
    handler.guiScene.destroyElement(handler.scene)
  }

  function loadBaseHandler(handlerClass, params = {}) {
    let guiScene = get_gui_scene()
    if (guiScene?.isInAct()) { 
      script_net_assert_once("loadBaseHandler", "Try to load baseHandler while in dagui:ObjScene:act")
      return null
    }

    let reloadScene = this.updatePostLoadCss() || this.needReloadScene()
    let reload = !handlerClass.keepLoaded || reloadScene
    if (!reload) {
      let handler = this.findAndReinitHandler(handlerClass, params)
      if (handler) {
        this.setLastBaseHandlerStartParamsByHandler(handlerClass, params)
        handler.afterBaseHandlerLoaded()
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
    handler.afterBaseHandlerLoaded()

    broadcastEvent("NewSceneLoaded")
    return handler
  }

  function loadHandlerScene(handler) {
    if (!handler.sceneBlkName) {
      debug_dump_stack()
      assert(false, "Error: cant load base handler w/o sceneBlkName.")
      return null
    }

    let id = $"root_scene_{++this.sceneObjIdx} {handler.sceneBlkName}" 
    if (!handler.rootHandlerClass || this.getHandlerType(handler) != handlerType.BASE) {
      let rootObj = handler.guiScene.getRoot()
      handler.scene = handler.guiScene.createElementByObject(rootObj, handler.sceneBlkName, "rootScene", handler)
      handler.initHandlerSceneTpl()
      handler.scene.id = id
      return null
    }

    local newLoadedRootHandler = null
    let guiScene = get_cur_gui_scene()
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

    let guiScene = get_gui_scene()
    handler = this.createHandler(handlerClass, guiScene, params)
    this.handlers[handlerType.MODAL].append(handler.weakref())

    let scene = guiScene.loadModal("", handler.sceneBlkName ?? "%gui/emptyScene.blk", "rootScene", handler)
    scene.id = $"modal_wnd_{++this.sceneObjIdx} {handler.sceneBlkName}" 
    handler.scene = scene

    handler.initHandlerSceneTpl()
    let initResult = this.initHandler(handler)
    if (!initResult)
      return null

    return handler
  }

  function loadCustomHandler(handlerClass, params = {}) {
    let guiScene = get_gui_scene()
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
    let guiScene = get_cur_gui_scene()
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
      current_base_gui_handler = handler

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

    this.removeHandlerFromListByGuiScene(this.activeRootHandlers, get_cur_gui_scene())

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
    reset_msg_box_check_anim_time() 
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

  
  function clearScene(guiScene = null) {
    if (!guiScene)
      guiScene = get_cur_gui_scene()
    if (guiScene?.isInAct()) { 
      script_net_assert_once("clearSceneInAct", "Try to clear scene while in dagui:ObjScene:act")
      return
    }

    this.sendEventToHandlers("onDestroy", guiScene)

    this.beforeClearScene(guiScene)

    guiScene.loadScene("%gui/rootScreen.blk", this)

    this.updateCssParams(guiScene)
    this.setGuiRootOptions(guiScene, false)
    this.startActionsDelay()
    guiScene.initCursor("%gui/cursor.blk", "normal")
    if (!guiScene.isEqual(get_cur_gui_scene())) {
      this.onClearScene(guiScene)
      broadcastEvent("GuiSceneCleared")
      return
    }

    this.lastGuiScene = guiScene

    if (!this.isNeedFullReloadAfterClearScene())
      this.needFullReload = false

    this.updateLoadingFlag()
    this.onClearScene(guiScene)
    broadcastEvent("GuiSceneCleared")
  }

  function updateLoadingFlag() {
    let oldVal = this.isInLoading
    this.isInLoading = !this.isMainGuiSceneActive()
                  || (!this.getActiveBaseHandler() && !this.getActiveRootHandler()) 

    if (oldVal != this.isInLoading)
      broadcastEvent("LoadingStateChange")
  }

  function emptyScreen() {
    println("GuiManager: load emptyScreen")
    this.setLastBaseHandlerStartParams({ eventbusName = "gui_start_empty_screen" })
    this.lastLoadedHandlerName = "emptyScreen"

    if (this.updatePostLoadCss() || this.getActiveBaseHandler() || this.getActiveRootHandler() || this.needReloadScene())
      this.clearScene()
    this.switchBaseHandler(null)

    if (!this._loadHandlerRecursionLevel)
      this.onActiveHandlersChanged()
  }

  function isMainGuiSceneActive() {
    return get_cur_gui_scene().isEqual(get_main_gui_scene())
  }

  function needReloadScene() {
    return this.needFullReload || always_reload_scenes || !check_obj(get_cur_gui_scene()["root_loaded"])
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
    let startData = this.findLastBaseHandlerStartData(get_gui_scene())
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
    if ((guiScene ?? get_cur_gui_scene())?.isInAct()) { 
      script_net_assert_once("closeAllModals", "Try to close all modals while in dagui:ObjScene:act")
      return
    }

    destroy_all_msg_boxes(guiScene)

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
    if (handler.guiScene?.isInAct()) { 
      script_net_assert_once("destroyModal", "Try to destroy modal window while in dagui:ObjScene:act")
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
    let curGuiScene = get_cur_gui_scene()
    foreach (handler in this.activeBaseHandlers)
      if (handler.guiScene && handler.guiScene.isEqual(curGuiScene) && this.isHandlerValid(handler, false))
        return handler
    return null
  }

  function getActiveRootHandler() {
    let curGuiScene = get_cur_gui_scene()
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

  











  function requestHandlerRestore(restoreHandler, triggerHandlerClass = null) {
    let restoreData = restoreHandler.getHandlerRestoreData()
    if (restoreData == null) 
      return false
    restoreData.handlerClass <- restoreHandler.getclass()
    if (triggerHandlerClass == null)
      triggerHandlerClass = this.getActiveBaseHandler()?.getclass()
    if (!triggerHandlerClass)
      return false

    if (triggerHandlerClass == restoreData.handlerClass) {
      this.restoreDataOnLoadHandler[restoreData.handlerClass] <- restoreData
      return true
    }

    this.restoreDataByTriggerHandler[triggerHandlerClass] <- restoreData
    return true
  }

  



  function restoreHandlers(triggerHandlerClass) {
    let restoreData = this.restoreDataByTriggerHandler?[triggerHandlerClass]
    if (restoreData == null)
      return
    this.restoreDataByTriggerHandler[triggerHandlerClass] <- null

    let openData = restoreData?.openData
    let handler = this.loadHandler(restoreData.handlerClass, openData ?? {})

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
      guiScene = get_gui_scene()
    return this.findLastBaseHandlerStartData(guiScene)?.startParams
  }

  function setLastBaseHandlerStartParams(startParams, guiScene = null, handlerLocId = null) {
    if (!guiScene)
      guiScene = get_gui_scene()
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

  function setLastBaseHandlerBackSceneParams() {
    let handler = this.getActiveBaseHandler()
    if (handler == null)
      return
    let { backSceneParams } = handler
    if (backSceneParams == null)
      return
    this.setLastBaseHandlerStartParams(backSceneParams, null, backSceneParams?.handlerLocId ?? "")
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

  
  function doDelayed(action) {
    this.delayedActions.append(action)
    if (this.delayedActions.len() == 1)
      this.startActionsDelay()
  }

  function startActionsDelay() {
    if (!this.delayedActions.len())
      return
    this.delayedActionsGuiScene = get_cur_gui_scene()
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
      && (!this.delayedActionsGuiScene || !this.delayedActionsGuiScene.isEqual(get_cur_gui_scene())))
      this.startActionsDelay()
  }

  function onEventSignOut(_) {
    this.restoreDataOnLoadHandler.clear()
    this.restoreDataByTriggerHandler.clear()
  }

  function callStartFunc(startParams) {
    let { eventbusName = null, handlerName = "", params = null } = startParams
    if (eventbusName != null) {
      let hasListeners = eventbus_has_listeners(eventbusName)
      if (!hasListeners) {
        logerr($"[GuiManager] Listeners for event '{eventbusName}' for start handler not found")
        return
      }
      return eventbus_send(eventbusName, params ?? {})
    }

    let hClass = gui_handlers?[handlerName]
    if (hClass == null) {
      logerr($"[GuiManager] Handler name '{handlerName}' not found in gui_handlers list")
      return
    }

    this.loadHandler(hClass, params ?? {})
  }
}
let isHandlerInScene = @(handlerClass) handlersManager.findHandlerClassInScene(handlerClass) != null
let is_in_loading_screen = @() handlersManager.isInLoading

function closeAllModals() {
  let guiScene = get_cur_gui_scene()
  handlersManager.closeAllModals(guiScene)
}
register_command(closeAllModals, "dagui.close_all_modals")

return {
  handlersManager
  is_in_loading_screen
  isHandlerInScene
  set_always_reload_scenes = @(val) always_reload_scenes = val
  get_always_reload_scenes = @() always_reload_scenes
  get_current_base_gui_handler = @() current_base_gui_handler
}