from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getSelectedChild, setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child, move_mouse_on_obj, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { removeAllGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { hideTooltip } = require("%scripts/utils/delayedTooltip.nut")

const __al_item_obj_tpl = "%gui/actionsList/actionsListItem.tpl"

/*
  API
    ActionsList.create(parent, params)
      parent - an object, in which will be created ActionsList.
        No need to make a special object for ActionsList.
        ActionList will be aligned on border of parent in specified side

      params = {
        orientation = ALIGN.TOP

        handler = null - handler, which implemets functions, specified in func
          field of actions.

        actions = [
          {
            // icon = ""
            text = ""
            action = function (){}
            // show = function (){return true}
            // selected = false
          }

          ...

        ]
      }

*/
gui_handlers.ActionsList <- class (BaseGuiHandler) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/actionsList/actionsListBlock.blk"
  sceneBlkTag = "popup_actions_list"

  params    = null
  parentObj = null

  closeOnUnhover = true

  static function open(v_parentObj, v_params) {
    if (!checkObj(v_parentObj)
      || v_parentObj.getFinalProp("refuseOpenHoverMenu") == "yes"
      || gui_handlers.ActionsList.hasActionsListOnObject(v_parentObj))
      return

    let params = {
      scene = v_parentObj
      params = v_params
    }
    handlersManager.loadHandler(gui_handlers.ActionsList, params)
  }

  function initCustomHandlerScene() {
    this.parentObj = this.scene
    this.scene = this.guiScene.createElementByObject(this.parentObj, this.sceneBlkName, this.sceneBlkTag, this)
    return true
  }

  function initScreen() {
    this.closeOnUnhover = this.params?.closeOnUnhover ?? this.closeOnUnhover
    this.scene.closeOnUnhover = this.closeOnUnhover ? "yes" : "no"
    this.fillList()
    this.updatePosition()
    if (this.params?.needCloseTooltips) {
      removeAllGenericTooltip()
      hideTooltip()
    }
  }

  function fillList() {
    if (!this.params?.infoBlock
      && (!("actions" in this.params) || this.params.actions.len() <= 0))
        return this.goBack()

    if (this.params?.cssParams)
      foreach (param, val in this.params.cssParams)
        this.scene[param] = val

    if (this.params?.infoBlock) {
      let infoBlock = this.scene.findObject("info_block")
      let infoData = this.params.infoBlock
      this.guiScene.replaceContentFromText(infoBlock, infoData, infoData.len(), this)
    }

    let nest = this.scene.findObject("list_nest")

    local isIconed = false
    local isVisibleActionFinded = false
    foreach (_idx, action in this.params.actions) {
      if (action?.show == null)
        action.show <- true
      action.haveSeparator <- isVisibleActionFinded
      isVisibleActionFinded = isVisibleActionFinded || action.show
      action.text <- (action?.text ?? "").replace(" ", nbsp)
      isIconed = isIconed || (action.show && action?.icon != null)
    }
    this.scene.iconed = isIconed ? "yes" : "no"

    let data = handyman.renderCached(__al_item_obj_tpl, this.params)
    this.guiScene.replaceContentFromText(nest, data, data.len(), this)

    // Temp Fix, DaGui cannot recalculate childrens width according to parent after replaceContent
    local maxWidth = this.scene.getSize()[0]
    for (local i = 0; i < nest.childrenCount(); i++) {
      let child = nest.getChild(i)
      if (child?.isActionsListButton == "no")
        continue
      maxWidth = max(maxWidth, child.getSize()[0])
    }
    nest.width = maxWidth

    if (showConsoleButtons.value)
      this.guiScene.performDelayed(this, function () {
        if (!checkObj(nest))
          return

        let selIdx = this.params.actions.findindex(@(action) (action?.selected ?? false) && (action?.show ?? false)) ?? -1
        this.guiScene.applyPendingChanges(false)
        move_mouse_on_child(nest, max(selIdx, 0))
        this.updatePosition() // after calling move_mouse_on_child the position can change, cause there is scrollToView() call
      })
  }

  function updatePosition() {
    this.guiScene.applyPendingChanges(false)
    let defaultAlign = this.params?.orientation ?? ALIGN.TOP
    setPopupMenuPosAndAlign(this.parentObj, defaultAlign, this.scene)
  }

  function goBack() {
    if (checkObj(this.scene))
      this.scene.close = "yes"
  }

  function onAction(obj) {
    this.close()
    let actionName = obj?.id ?? ""
    if (actionName == "")
      return

    this.guiScene.performDelayed(this, function () {
      if (!checkObj(this.scene))
        return

      this.guiScene.destroyElement(this.scene)
      local func = null
      foreach (action in this.params.actions)
        if (action.actionName == actionName) {
          func = action.action
          break
        }

      if (func == null)
        return

      if (type(func) == "string")
        this.params.handler[func].call(this.params.handler)
      else
        func.call(this.params.handler)
    })
  }

  function close() {
    this.goBack()
    broadcastEvent("ClosedUnitItemMenu")
  }

  function onFocus(obj) {
    this.guiScene.performDelayed(this, function () {
      if (!checkObj(this.scene) || this.scene?.close == "yes" || !checkObj(obj))
        return

      let currentObj = getSelectedChild(obj)
      if (!currentObj)
        return this.close()

      if ((!currentObj.isValid() || !currentObj.isFocused()) &&
        !obj.isFocused() && !this.closeOnUnhover)
        this.close()
    })
  }

  function onBtnClose() {
    if (this.scene.isValid())
      move_mouse_on_obj(this.scene.getParent())
    this.close()
  }

  function onActionsListDeactivate(_obj) {
    this.params?.onDeactivateCb()
  }

  static function removeActionsListFromObject(obj, fadeout = false) {
    let alObj = obj.findObject("actions_list")
    if (!checkObj(alObj))
      return
    if (fadeout)
      alObj.close = "yes"
    else
      alObj.getScene().destroyElement(alObj)
  }

  static function hasActionsListOnObject(obj) {
    return checkObj(obj.findObject("actions_list"))
  }

  static function switchActionsListVisibility(obj) {
    if (!checkObj(obj))
      return false

    if (obj?.refuseOpenHoverMenu) {
      obj.refuseOpenHoverMenu = obj.refuseOpenHoverMenu == "yes" ? "no" : "yes"
      return true
    }

    return false
  }
}
