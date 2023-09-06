//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getSelectedChild, setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

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
::gui_handlers.ActionsList <- class extends ::BaseGuiHandler {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/actionsList/actionsListBlock.blk"
  sceneBlkTag = "popup_actions_list"

  params    = null
  parentObj = null

  closeOnUnhover = true

  static function open(v_parentObj, v_params) {
    if (!checkObj(v_parentObj)
      || v_parentObj.getFinalProp("refuseOpenHoverMenu") == "yes"
      || ::gui_handlers.ActionsList.hasActionsListOnObject(v_parentObj))
      return

    let params = {
      scene = v_parentObj
      params = v_params
    }
    ::handlersManager.loadHandler(::gui_handlers.ActionsList, params)
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
  }

  function fillList() {
    if (!("actions" in this.params) || this.params.actions.len() <= 0)
      return this.goBack()

    let nest = this.scene.findObject("list_nest")

    local isIconed = false
    foreach (_idx, action in this.params.actions) {
      let show = getTblValue("show", action, true)
      if (!("show" in action))
        action.show <- show

      action.text <- ::stringReplace(getTblValue("text", action, ""), " ", ::nbsp)

      isIconed = isIconed || (show && getTblValue("icon", action) != null)
    }
    this.scene.iconed = isIconed ? "yes" : "no"

    let data = handyman.renderCached(__al_item_obj_tpl, this.params)
    this.guiScene.replaceContentFromText(nest, data, data.len(), this)

    // Temp Fix, DaGui cannot recalculate childrens width according to parent after replaceContent
    local maxWidth = 0
    for (local i = 0; i < nest.childrenCount(); i++)
      maxWidth = max(maxWidth, nest.getChild(i).getSize()[0])
    nest.width = maxWidth

    if (::show_console_buttons)
      this.guiScene.performDelayed(this, function () {
        if (!checkObj(nest))
          return

        let selIdx = this.params.actions.findindex(@(action) (action?.selected ?? false) && (action?.show ?? false)) ?? -1
        this.guiScene.applyPendingChanges(false)
        ::move_mouse_on_child(nest, max(selIdx, 0))
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
      ::move_mouse_on_obj(this.scene.getParent())
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
