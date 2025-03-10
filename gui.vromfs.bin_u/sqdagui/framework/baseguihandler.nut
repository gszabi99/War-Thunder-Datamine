from "%sqDagui/daguiNativeApi.nut" import *

let { handlerType } = require("handlerType.nut")
let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("baseGuiHandlerManager.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { open_url_by_obj } = require("open_url_by_obj.nut")
let { gui_scene_boxes, scene_msg_box } = require("msgBox.nut")

let BaseGuiHandler = class {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/emptyScene.blk"
  sceneNavBlkName = null
  sceneTplName = null 
  keepLoaded = false
  needAnimatedSwitchScene = true
  multipleInstances = false
  rootHandlerClass = null 
                          

  guiScene = null
  scene = null     

  backSceneParams = null 
  subHandlers = null 
  delayedActions = null
  rootHandlerWeak = null

  constructor(gui_scene, params = {}) {
    this.guiScene = gui_scene
    this.delayedActions = []
    this.subHandlers = []

    
    if (this.wndType == handlerType.BASE)
      this.backSceneParams = handlersManager.getLastBaseHandlerStartParams()

    this.setParams(params)
  }

  function init() { 
    this.loadNavBar()
    this.initScreen()
  }

  function setParams(params) {
    foreach (name, value in params)
      if (name in this)
        this[name] = value
  }

  function initCustomHandlerScene() {
    if (!check_obj(this.scene))
      return false

    this.guiScene = this.scene.getScene()

    if (this.sceneBlkName) {
      this.guiScene.replaceContent(this.scene, this.sceneBlkName, this)
      return true
    }

    return this.initHandlerSceneTpl()
  }

  function initHandlerSceneTpl() {
    if (!this.sceneTplName)
      return false

    let obj = this.getSceneTplContainerObj()
    if (!obj?.isValid())
      return false

    let view = this.getSceneTplView()
    if (!view)
      return false

    let data = handyman.renderCached(this.sceneTplName, view)

    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    return true
  }

  function getSceneTplView() { return null }
  function getSceneTplContainerObj() { return this.scene }

  function initScreen() {}
  function onDestroy()  {}

  function isValid() {
    return check_obj(this.scene)
  }

  function isInCurrentScene() {
    return this.guiScene.isEqual(get_cur_gui_scene())
  }

  function loadNavBar() {
    let markup = this.getNavbarMarkup()
    if (!markup && !this.sceneNavBlkName)
      return
    let obj = this.scene.findObject("nav-help")
    if (!check_obj(obj))
      return

    if (markup)
      this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
    else
      this.guiScene.replaceContent(obj, this.sceneNavBlkName, this)
  }

  function getNavbarMarkup() { return null }

  function isSceneActive() {
    return check_obj(this.scene) && this.scene.isEnabled()
  }

  function isSceneActiveNoModals() {
    return this.isSceneActive() && this.scene.getModalCounter() == 0
  }

  
  function getBaseHandlersContainer() {
    return null
  }
  function onNewContentLoaded(_handler) {}

  function onEventNewSceneLoaded(_p) {
    if (this.wndType != handlerType.ROOT)
      return

    let handler = this.getCurActiveContentHandler()
    if (handler)
      this.onNewContentLoaded(handler)
  }

  function getCurActiveContentHandler() {
    let handler = handlersManager.getActiveBaseHandler()
    return (handler && handler.rootHandlerClass == this.getclass()) ? handler : null
  }
  

  function getObj(name) {
    if (!check_obj(this.scene))
      return null
    return this.scene.findObject(name)
  }

  function msgBox(id, text, buttons, def_btn, options = {}) {
    for (local i = 0; i < gui_scene_boxes.len(); i++) {
      if (gui_scene_boxes[i].id == id)
        return null
    }
    if (!options)
      options = {}
    options.baseHandler <- this
    return scene_msg_box(id, this.guiScene, text, buttons, def_btn, options)
  }

  function onMsgLink(obj) {
    open_url_by_obj(obj)
  }

  function goForward(startFunc, needFade = true) {
    if (!startFunc)
      return

    if (needFade)
      handlersManager.animatedSwitchScene(startFunc)
    else
      startFunc()
  }

  function fullReloadScene() {
    this.guiScene.performDelayed(this, @() handlersManager.startSceneFullReload())
  }

  function afterModalDestroy() {}

  function onModalWndDestroy() {
    this.afterModalDestroy()
    broadcastEvent("ModalWndDestroy", { handler = this })
  }

  function goBack() {
    if (this.wndType == handlerType.MODAL) {
      this.guiScene.performDelayed(this, function() {
        handlersManager.destroyHandler(this)
        handlersManager.clearInvalidHandlers()

        this.onModalWndDestroy()
      })
      return
    }

    if (this.wndType == handlerType.BASE && this.backSceneParams != null) {
      let backParams = this.backSceneParams
      if (this.needAnimatedSwitchScene)
        handlersManager.animatedSwitchScene(@() handlersManager.callStartFunc(backParams))
      else
        handlersManager.callStartFunc(backParams)
    }
  }

  function onSceneActivate(show) {
    if (show)
      this.popDelayedActions()
    foreach (handler in this.subHandlers)
      if (handlersManager.isHandlerValid(handler))
        handler.onSceneActivate(show)
  }

  _isPopActionsInProgress = false
  function popDelayedActions() {
    if (this._isPopActionsInProgress)
      return
    this._isPopActionsInProgress = true
    while (this.delayedActions.len() > 0) {
      if (!this.checkActiveForDelayedAction())
        break

      let action = this.delayedActions.remove(0)
      if (type(action) == "string" && action in this)
        this[action]()
      else if (type(action) == "function")
        action()
    }
    this._isPopActionsInProgress = false
  }

  function checkActiveForDelayedAction() {
    return this.isSceneActiveNoModals()
  }

  function doWhenActive(func) {
    if (this.isSceneActiveNoModals()) {
      if (type(func) == "function")
        func()
      else
        assert(false, $"doWhenActive received {func}, instead of function")
    }
    else
      this.delayedActions.append(func)
  }

  function doWhenActiveOnce(funcName) {
    assert(type(funcName) == "string", "Error: doWhenActiveOnce work only with function names")

    let prevIdx = this.delayedActions.indexof(funcName)
    if (prevIdx != null)
      this.delayedActions.remove(prevIdx)
    this.delayedActions.append(funcName)
    this.popDelayedActions()
  }

  function onEventModalWndDestroy(_params) {
    if (this.isSceneActive())
      this.popDelayedActions()
  }

  






  function getHandlerRestoreData() {
    return null
  }

  


  function restoreHandler(_stateData) {
  }

  function registerSubHandler(handler) {
    if (!handlersManager.isHandlerValid(handler))
      return

    
    for (local i = this.subHandlers.len() - 1; i >= 0; i--)
      if (!handlersManager.isHandlerValid(this.subHandlers[i]))
        this.subHandlers.remove(i)

    this.subHandlers.append(handler.weakref())
  }

  _tostring = @() $"BaseGuiHandler(sceneBlkName = {this.sceneBlkName})"
}

return {
  BaseGuiHandler
}