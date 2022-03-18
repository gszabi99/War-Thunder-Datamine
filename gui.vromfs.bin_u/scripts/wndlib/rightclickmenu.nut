let SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
/*
  config = [
    {
      text = string
      action = function
      show = boolean || function
      onUpdateButton = function(params)  //return table { text = "new button text", enable = true, stopUpdate = false }
                                         //updates button once per sec.
      hasSeparator = boolean
    }
    ...
  ]
*/

global enum RCLICK_MENU_ORIENT
{
  LEFT,
  RIGHT
}

::gui_right_click_menu <- function gui_right_click_menu(config, owner, position = null, orientation = null, onClose = null)
{
  if (typeof config == "array")
    config = { actions = config }
  ::handlersManager.loadHandler(::gui_handlers.RightClickMenu, {
    config = config,
    owner = owner,
    position = position,
    orientation = orientation,
    onClose = onClose,
  })
}

::gui_handlers.RightClickMenu <- class extends ::BaseGuiHandler
{
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/rightClickMenu"
  needVoiceChat = false

  owner        = null
  config       = null
  position     = null
  orientation  = RCLICK_MENU_ORIENT.LEFT
  onClose      = null

  choosenValue = -1

  timeOpen     = 0
  isListEmpty  = true

  idPrefix     = "btn_"

  function getSceneTplView()
  {
    let view = {
      actions = []
    }

    isListEmpty = true
    if (!("actions" in config))
      return view

    foreach(idx, item in config.actions)
    {
      if ("show" in item && !((typeof(item.show) == "function") ? item.show.call(owner) : item.show))
        continue

      local actionData = null //lineDiv
      local enabled = true
      if ("enabled" in item)
        enabled = typeof(item.enabled) == "function"
                  ? item.enabled.call(owner)
                  : item.enabled

      let text = item?.text
      actionData = {
        id = idPrefix + idx.tostring()
        text = text
        textUncolored = text != null ? ::g_dagui_utils.removeTextareaTags(text) : ""
        tooltip = ::getTblValue("tooltip", item, "")
        enabled = enabled
        isVisualDisabled = item?.isVisualDisabled ?? false
        needTimer = ::u.isFunction(::getTblValue("onUpdateButton", item))
        hasSeparator = item?.hasSeparator ?? false
      }

      view.actions.append(actionData)
      isListEmpty = false
    }

    return view
  }

  function initScreen()
  {
    if (isListEmpty)
      return goBack()

    timeOpen = ::dagor.getCurTime()
    let listObj = scene.findObject("rclick_menu_div")

    guiScene.setUpdatesEnabled(false, false)
    initTimers(listObj, config.actions)
    guiScene.setUpdatesEnabled(true, true)

    let rootSize = guiScene.getRoot().getSize()
    let cursorPos = position ? position : ::get_dagui_mouse_cursor_pos_RC()
    let menuSize = listObj.getSize()
    let menuPos =  [cursorPos[0], cursorPos[1]]
    for(local i = 0; i < 2; i++)
      if (menuPos[i] + menuSize[i] > rootSize[i])
        if (menuPos[i] > menuSize[i])
          menuPos[i] -= menuSize[i]
        else
          menuPos[i] = ((rootSize[i] - menuSize[i]) / 2).tointeger()

    let shift = orientation == RCLICK_MENU_ORIENT.RIGHT? menuSize[0] : 0
    listObj.pos = menuPos[0] - shift + ", " + menuPos[1]
    listObj.width = listObj.getSize()[0]
    guiScene.applyPendingChanges(false)
    ::move_mouse_on_child(listObj, 0)
  }

  function initTimers(listObj, actions)
  {
    foreach(idx, item in actions)
    {
      let onUpdateButton = ::getTblValue("onUpdateButton", item)
      if (!::u.isFunction(onUpdateButton))
        continue

      let btnObj = listObj.findObject(idPrefix + idx.tostring())
      if (!::check_obj(btnObj))
        continue

      SecondsUpdater(btnObj, function(obj, params)
      {
        let data = onUpdateButton(params)
        updateBtnByTable(obj, data)
        return data?.stopUpdate ?? false
      }.bindenv(this))
    }
  }

  function updateBtnByTable(btnObj, data)
  {
    let text = ::getTblValue("text", data)
    if (!::u.isEmpty(text))
    {
      btnObj.setValue(::g_dagui_utils.removeTextareaTags(text))
      btnObj.findObject("text").setValue(text)
    }

    let enable = ::getTblValue("enable", data)
    if (::u.isBool(enable))
      btnObj.enable(enable)
  }

  function onMenuButton(obj)
  {
    if (!obj || obj.id.len() < 5)
      return

    choosenValue = obj.id.slice(4).tointeger()
    goBack()
  }

  function goBack()
  {
    if (scene && (::dagor.getCurTime() - timeOpen) < 100 && !isListEmpty)
      return

    base.goBack()
  }

  function afterModalDestroy()
  {
    if (choosenValue in config.actions) {
      let applyFunc = ::getTblValue("action", config.actions[choosenValue])
      ::call_for_handler(owner, applyFunc)
    }
    onClose?()
  }
}
