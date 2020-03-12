global enum WM_CONTENT_TYPE {
  TEXT,
  TEMPLATE
}

// TEST:  ::gui_start_wheelmenu({ menu = [0,1,2,3,4,5,6,7], callbackFunc = dlog })
::gui_start_wheelmenu <- function gui_start_wheelmenu(params)
{
  local defaultParams = {
    menu = []
    callbackFunc = null
    owner = null
    mouseEnabled    = false
    axisEnabled     = true
    contentType     = WM_CONTENT_TYPE.TEXT
    contentTemplate = "gui/wheelMenu/textContent"
    contentPartails = {}
  }

  ::inherit_table(params, defaultParams)
  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.wheelMenuHandler)
  if (handler)
    handler.reinitScreen(params)
  else
    handler = ::handlersManager.loadHandler(::gui_handlers.wheelMenuHandler, params)

  return handler
}

::close_cur_wheelmenu <- function close_cur_wheelmenu()
{
  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.wheelMenuHandler)
  if (handler && handler.isActive)
    handler.showScene(false)
}

//-----------------------------------------------------------------------------

/* *
 * WheelMenu usage
 *
 * just call gui_start_wheelmenu function
 *
 * gui_start_wheelmenu parametrs:
 * @owner - instance of handler, which creates thw wheel menu
 * @params - table with some configs for instanciate wheel menu.
 * Has optinal and requirend paramstr. List of them is blow:
 *  @menu
 *   required parameter. Array of menu items in
 *   special format (described in @contentTepe section).
 *
 *  @contentType
 *   Optionldetermine how to handle menu items.
 *   All available types are in WM_CONTENT_TYPE enum.
 *   @menu format:
 *   WM_CONTENT_TYPE.TEXT:
 *    menu = ["text 1", "text 2", "text 3" ... ]
 *   WM_CONTENT_TYPE.TEMPLATE:
 *    each element of @menu array is a view for your tempalte
 *
 *  @contentTemplate
 *   path to template for WM_CONTENT_TYPE.TEMPLATE content type
 * */


::dagui_propid.add_name_id("index") // for navigation with mouse in wheelmenu

class ::gui_handlers.wheelMenuHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/wheelMenu/wheelmenu.blk"
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_NONE
  wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
                                   | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
                                   | CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP

  invalidIndex = -1
  applyIndex = -1
  joystickSides = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
  joystickMinDeviation = 8000
  btnSetsConfig = [
    ["W", "E"],
    ["W", "SW", "E", "SE", "S"],
    ["NW", "W", "SW", "NE", "E", "SE", "S", "N"],
  ]
  watchAxis = []
  stuckAxis = []

  menu = null
  isActive = true
  joystickSelection = null
  callbackFunc = null
  owner = null
  mouseEnabled = false
  axisEnabled = true
  isAccessKeysEnabled = false
  shouldShadeBackground = true
  contentTemplate = "gui/wheelMenu/textContent"
  contentPartails = {}
  contentType = WM_CONTENT_TYPE.TEXT

  function initScreen()
  {
    if (!menu || !::checkObj(scene))
      return close()

    ::close_cur_wheelmenu()

    guiScene = scene.getScene()
    showScene(true)
    fill()
    updateTitlePos()
    if (axisEnabled)
    {
      watchAxis = ::joystickInterface.getAxisWatch(false, true, true)
      stuckAxis = ::joystickInterface.getAxisStuck(watchAxis)
      joystickSelection = null

      scene.findObject("wheelmenu_axis_input_timer").setUserData(this)
      onWheelmenuAxisInputTimer()
    }
    local wheelmenu = scene.findObject("wheelmenu")
    wheelmenu["total-input-transparent"] = mouseEnabled ? "no" : "yes"
    showSceneBtn("fast_shortcuts_block", false)
    showSceneBtn("wheelmenu_bg_shade", shouldShadeBackground)

    ::g_hud_event_manager.subscribe("LocalPlayerDead", function (data) {
      sendAnswerAndClose(invalidIndex)
    }, this)

    wndControlsAllowMask = wndControlsAllowMaskWhenActive
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initScreen()
  }

  function fill()
  {
    local btnAll = btnSetsConfig[ btnSetsConfig.len() - 1 ]
    local btnSet = btnAll
    for (local i = 0; i < btnSetsConfig.len(); i++)
      if (btnSetsConfig[i].len() >= menu.len())
        {
          btnSet = btnSetsConfig[i]
          break
        }

    for (local i = 0; i < btnAll.len(); i++)
    {
      local suffix = btnAll[i]
      local index = ::find_in_array(btnSet, suffix, invalidIndex)
      local item = menu?[index] ?? ""
      if (!::u.isTable(item))
        item = { name = item.tostring() }
      local isShow = (item?.name ?? "") != ""
      local enabled = isShow && (item?.wheelmenuEnabled ?? true)
      local bObj = showSceneBtn("wheelmenuItem" + suffix, isShow)

      if (::checkObj(bObj))
      {
        local buttonType = ::getTblValue("buttonType", item, "")
        if (buttonType != "")
          bObj.type = buttonType
        bObj.accessKey = isAccessKeysEnabled && isShow ? (item?.accessKey ?? "") : ""

        if (isShow)
        {
          local content = bObj.findObject("content")
          local blk = ::handyman.renderCached(contentTemplate, item, contentPartails)
          guiScene.replaceContentFromText(content, blk, blk.len(), this)
        }

        bObj.index = index
        bObj.enable(enabled)
        bObj.selected = "no"
      }
    }
  }

  function updateTitlePos()
  {
    local obj = scene.findObject("wheel_menu_category")
    local hasTopItem = menu?[7] != null
    obj.top = hasTopItem ? "-1.5h" : "-1.5h +1@wheelmenuBtnHeight"
  }

  function onWheelmenuItemClick(obj)
  {
    if (!obj || (!mouseEnabled && !::use_touchscreen && !::is_cursor_visible_in_gui() && !isAccessKeysEnabled) )
      return

    local index = obj.index.tointeger()
    if (index in menu && menu[index].tostring() != "")
      sendAnswerAndClose(index)
  }

  function onWheelmenuAxisInputTimer(obj=null, dt=null)
  {
    if (!axisEnabled)
      return

    local axisData = ::joystickInterface.getAxisData(watchAxis, stuckAxis)
    local joystickData = ::joystickInterface.getMaxDeviatedAxisInfo(axisData, 32000, joystickMinDeviation)

    local selection = null
    if (joystickData)
    {
      local side = joystickData.normLength > 0
        ? (((joystickData.angle / PI + 2.125) * 4).tointeger() % 8)
        : -1
      selection = joystickSides?[side]
    }

    if (selection != joystickSelection)
    {
      local bObj = joystickSelection && scene.findObject("wheelmenuItem" + joystickSelection)
      if (bObj)
        bObj.selected = "no"

      bObj = selection && scene.findObject("wheelmenuItem" + selection)
      if (bObj)
        bObj.selected = "yes"

      joystickSelection = selection
    }
  }

  function onWheelmenuAccesskeyApply(obj)
  {
    if (! joystickSelection) return

    local bObj = scene.findObject("wheelmenuItem" + joystickSelection)
    local index = bObj && bObj.index.tointeger()
    if (index in menu && menu[index].tostring() != "")
      sendAnswerAndClose(index)
  }

  function onWheelmenuAccesskeyCancel(obj)
  {
    sendAnswerAndClose(invalidIndex)
  }

  function onVoiceMessageSwitchChannel(obj) {}

  function sendAnswerAndClose(index)
  {
    if (index!=null)
      applyIndex = index
    close()
  }

  function showScene(show)
  {
    scene.show(show)
    scene.enable(show)
    isActive = show
    switchControlsAllowMask(isActive ? wndControlsAllowMaskWhenActive : CtrlsInGui.CTRL_ALLOW_FULL)
  }

  function close()
  {
    doApply()
  }

  function afterModalDestroy()
  {
    doApply()
  }

  function doApply()
  {
    if (!callbackFunc)
      return

    if (owner)
      callbackFunc.call(owner, applyIndex)
    else
      callbackFunc(applyIndex)
  }

  function onEventHudTypeSwitched(params)
  {
    sendAnswerAndClose(invalidIndex)
  }
}