// TEST:  ::gui_start_wheelmenu({ menu = [0,1,2,3,4,5,6,7].map(@(v) { name = v.tostring() }), callbackFunc = dlog })

local { getGamepadAxisTexture } = require("scripts/controls/gamepadIcons.nut")

::gui_start_wheelmenu <- function gui_start_wheelmenu(params)
{
  local defaultParams = {
    menu = []
    callbackFunc = null
    owner = null
    mouseEnabled    = false
    axisEnabled     = true
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
 * gui_start_wheelmenu parameters:
 * @owner - instance of handler, which creates the wheel menu
 * @params - table with some configs for instantiate wheel menu.
 *  Has optional and required parameters:
 *  @menu
 *   required parameter. Array of menu items,
 *   each element of array is a view for your template.
 *  @contentTemplate
 *   optional parameter. path to view template of @menu item.
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
  joystickMinDeviation = 0.25
  btnSetIdx = -1
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
  isKbdShortcutDown = false
  callbackFunc = null
  owner = null
  mouseEnabled = false
  axisEnabled = true
  shouldShadeBackground = true
  contentTemplate = "gui/wheelMenu/textContent"
  contentPartails = {}

  function initScreen()
  {
    if (!menu || !::checkObj(scene))
      return close()

    ::close_cur_wheelmenu()

    guiScene = scene.getScene()
    showScene(true)
    fill()
    updateTitlePos()
    updateSelectShortcutImage()
    if (axisEnabled)
    {
      watchAxis = ::joystickInterface.getAxisWatch(true)
      stuckAxis = ::joystickInterface.getAxisStuck(watchAxis)
      joystickSelection = null
      isKbdShortcutDown = false

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
    btnSetIdx = btnSetsConfig.len() - 1
    for (local i = 0; i < btnSetsConfig.len(); i++)
      if (btnSetsConfig[i].len() >= menu.len())
        {
          btnSetIdx = i
          break
        }
    local btnSet = btnSetsConfig[btnSetIdx]

    foreach (suffix in joystickSides)
    {
      local index = ::find_in_array(btnSet, suffix, invalidIndex)
      local item = menu?[index]
      local isShow = (item?.name ?? "") != ""
      local enabled = isShow && (item?.wheelmenuEnabled ?? true)
      local bObj = showSceneBtn("wheelmenuItem" + suffix, isShow)

      if (::checkObj(bObj))
      {
        local buttonType = ::getTblValue("buttonType", item, "")
        if (buttonType != "")
          bObj.type = buttonType

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

  function updateSelectShortcutImage()
  {
    local obj = scene.findObject("wheelmenu_select_shortcut")
    local isShow = ::show_console_buttons && axisEnabled
    if (isShow)
    {
      local shortcuts = ::get_player_cur_unit()?.unitType.wheelmenuAxis ?? []
      local shortcutType = ::g_shortcut_type.COMPOSIT_AXIS
      isShow = shortcutType.isComponentsAssignedToSingleInputItem(shortcuts)
      local axesId = shortcutType.getComplexAxesId(shortcuts)
      obj["background-image"] = getGamepadAxisTexture(axesId)
    }
    obj.show(isShow)
  }

  function onWheelmenuItemClick(obj)
  {
    if (!obj || (!mouseEnabled && !::use_touchscreen && !::is_cursor_visible_in_gui()) )
      return

    local index = obj.index.tointeger()
    sendAvailableAnswerDelayed(index)
  }

  function onWheelmenuAxisInputTimer(obj=null, dt=null)
  {
    if (!axisEnabled || isKbdShortcutDown)
      return

    local axisData = ::joystickInterface.getAxisData(watchAxis, stuckAxis)
    local joystickData = ::joystickInterface.getMaxDeviatedAxisInfo(axisData, joystickMinDeviation)
    if (joystickData == null || joystickData.normLength == 0)
      return

    local side = ((joystickData.angle / PI + 2.125) * 4).tointeger() % 8
    highlightItemBySide(joystickSides?[side])
  }

  function highlightItemBySide(selection)
  {
    if (selection == joystickSelection)
      return

    local bObj = joystickSelection && scene.findObject("wheelmenuItem" + joystickSelection)
    if (bObj)
      bObj.selected = "no"

    bObj = selection && scene.findObject("wheelmenuItem" + selection)
    if (bObj)
      bObj.selected = "yes"

    joystickSelection = selection
  }

  function highlightItemByIndex(index)
  {
    local selection = btnSetsConfig[btnSetIdx]?[index]
    highlightItemBySide(selection)
  }

  function onWheelmenuAccesskeyApply(obj)
  {
    if (! joystickSelection) return

    local bObj = scene.findObject("wheelmenuItem" + joystickSelection)
    local index = bObj && bObj.index.tointeger()
    sendAvailableAnswerDelayed(index)
  }

  function onWheelmenuAccesskeyCancel(obj)
  {
    sendAnswerAndClose(invalidIndex)
  }

  function onVoiceMessageSwitchChannel(obj) {}

  function onShortcutSelectCallback(index, isDown)
  {
    if (!isItemAvailable(index))
      return false
    isKbdShortcutDown = isDown
    highlightItemByIndex(isDown ? index : -1)
    if (!isDown)
      sendAvailableAnswerDelayed(index)
    return true // processed
  }

  function isItemAvailable(index)
  {
    return (menu?[index].name ?? "") != "" && (menu?[index].wheelmenuEnabled ?? true)
  }

  function sendAvailableAnswerDelayed(index)
  {
    if (isItemAvailable(index))
      guiScene.performDelayed(this, function() {
        if (isValid())
          sendAnswerAndClose(index)
      })
  }

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
