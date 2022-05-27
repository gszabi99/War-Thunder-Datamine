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
let { getSelectedChild } = require("%sqDagui/daguiUtil.nut")

::gui_handlers.ActionsList <- class extends ::BaseGuiHandler
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/actionsList/actionsListBlock.blk"
  sceneBlkTag = "popup_actions_list"

  params    = null
  parentObj = null

  closeOnUnhover = true

  __al_item_obj_tpl = "%gui/actionsList/actionsListItem"

  static function open(v_parentObj, v_params)
  {
    if (!::checkObj(v_parentObj)
      || v_parentObj.getFinalProp("refuseOpenHoverMenu") == "yes"
      || ::gui_handlers.ActionsList.hasActionsListOnObject(v_parentObj))
      return

    let params = {
      scene = v_parentObj
      params = v_params
    }
    ::handlersManager.loadHandler(::gui_handlers.ActionsList, params)
  }

  function initCustomHandlerScene()
  {
    parentObj = scene
    scene = guiScene.createElementByObject(parentObj, sceneBlkName, sceneBlkTag, this)
    return true
  }

  function initScreen()
  {
    closeOnUnhover = params?.closeOnUnhover ?? closeOnUnhover
    scene.closeOnUnhover = closeOnUnhover ? "yes" : "no"
    fillList()
    updatePosition()
  }

  function fillList()
  {
    if (!("actions" in params) || params.actions.len() <= 0)
      return goBack()

    let nest = scene.findObject("list_nest")

    local isIconed = false
    foreach (idx, action in params.actions)
    {
      let show = ::getTblValue("show", action, true)
      if (!("show" in action))
        action.show <- show

      action.text <- ::stringReplace(::getTblValue("text", action, ""), " ", ::nbsp)

      isIconed = isIconed || (show && ::getTblValue("icon", action) != null)
    }
    scene.iconed = isIconed ? "yes" : "no"

    let data = ::handyman.renderCached(__al_item_obj_tpl, params)
    guiScene.replaceContentFromText(nest, data, data.len(), this)

    // Temp Fix, DaGui cannot recalculate childrens width according to parent after replaceContent
    local maxWidth = 0
    for(local i = 0; i < nest.childrenCount(); i++)
      maxWidth = max(maxWidth, nest.getChild(i).getSize()[0])
    nest.width = maxWidth

    if (::show_console_buttons)
      guiScene.performDelayed(this, function () {
        if (!::checkObj(nest))
          return

        let selIdx = params.actions.findindex(@(action) (action?.selected ?? false) && (action?.show ?? false)) ?? -1
        guiScene.applyPendingChanges(false)
        ::move_mouse_on_child(nest, max(selIdx, 0))
      })
  }

  function updatePosition()
  {
    guiScene.applyPendingChanges(false)
    let defaultAlign = params?.orientation ?? ALIGN.TOP
    ::g_dagui_utils.setPopupMenuPosAndAlign(parentObj, defaultAlign, scene)
  }

  function goBack()
  {
    if (::checkObj(scene))
      scene.close = "yes"
  }

  function onAction(obj)
  {
    close()
    let actionName = obj?.id ?? ""
    if (actionName == "")
      return

    guiScene.performDelayed(this, (@(actionName) function () {
      if (!::checkObj(scene))
        return

      guiScene.destroyElement(scene)
      local func = null
      foreach(action in params.actions)
        if (action.actionName == actionName)
        {
          func = action.action
          break
        }

      if (func == null)
        return

      if (typeof func == "string")
        params.handler[func].call(params.handler)
      else
        func.call(params.handler)
    })(actionName))
  }

  function close()
  {
    goBack()
    ::broadcastEvent("ClosedUnitItemMenu")
  }

  function onFocus(obj)
  {
    guiScene.performDelayed(this, function () {
      if (!::checkObj(scene) || scene?.close == "yes" || !::checkObj(obj))
        return

      let currentObj = getSelectedChild(obj)
      if (!currentObj)
        return close()

      if (( !currentObj.isValid() || !currentObj.isFocused()) &&
        !obj.isFocused() && !closeOnUnhover)
        close()
    })
  }

  function onBtnClose()
  {
    if (scene.isValid())
      ::move_mouse_on_obj(scene.getParent())
    close()
  }

  function onActionsListDeactivate(obj)
  {
    params?.onDeactivateCb()
  }

  static function removeActionsListFromObject(obj, fadeout = false)
  {
    let alObj = obj.findObject("actions_list")
    if (!::checkObj(alObj))
      return
    if (fadeout)
      alObj.close = "yes"
    else
      alObj.getScene().destroyElement(alObj)
  }

  static function hasActionsListOnObject(obj)
  {
    return ::checkObj(obj.findObject("actions_list"))
  }

  static function switchActionsListVisibility(obj)
  {
    if (!::checkObj(obj))
      return false

    if (obj?.refuseOpenHoverMenu)
    {
      obj.refuseOpenHoverMenu = obj.refuseOpenHoverMenu == "yes"? "no" : "yes"
      return true
    }

    return false
  }
}
