local cfg = require("scripts/wheelmenu/multifuncmenuCfg.nut")
local { isMultifuncMenuAvailable } = require("scripts/wheelmenu/multifuncmenuShared.nut")

local getHandler = @() ::handlersManager.findHandlerClassInScene(::gui_handlers.multifuncMenuHandler)
local callbackFunc = null
local isDebugMode = false
local getSectionTitle = @(id) cfg[id]?.getTitle() ?? ::loc(cfg[id]?.title ?? id)

local function open(curSectionId = null, isForward = true)
{
  if (!isMultifuncMenuAvailable())
    return false

  local joyParams = ::joystick_get_cur_settings()
  local shouldAddAccessKeys = ::is_platform_pc && !::is_xinput_device()
  local unit = ::get_player_cur_unit()
  local unitType = unit?.unitType
  if (!unitType)
    return false

  curSectionId = curSectionId ?? $"root_{unitType.tag}"
  if (cfg?[curSectionId] == null)
    return false

  // Initializing accessKeys once
  if (shouldAddAccessKeys && !getHandler())
  {
    local params = {
      menu = []
      curSectionId = curSectionId
      isAccessKeysEnabled = true
    }
    for (local idx = 0; idx < 8; idx++)
      params.menu.append({ name = " ", accessKey = $"{idx+1} | Num{idx+1}" })
    ::handlersManager.loadHandler(::gui_handlers.multifuncMenuHandler, params)
    getHandler()?.path.clear()
  }

  local allowedShortcutIds = ::g_controls_utils.getControlsList({ unitType = unit.unitType })
    .map(@(s) s.id)

  local menu = []
  foreach (idx, c in cfg[curSectionId].items)
  {
    local isShortcut = "shortcut" in c
    local isSection  = "section"  in c

    local shortcutId = null
    local sectionId = null
    local label = ""
    local isEnabled = false

    if (isShortcut)
    {
      shortcutId = c.shortcut.findvalue(@(id) allowedShortcutIds.indexof(id) != null)
      label = ::loc("hotkeys/{0}".subst(shortcutId ?? c.shortcut?[0] ?? ""))
      isEnabled = shortcutId != null
    }
    else if (isSection)
    {
      sectionId = c.section
      local title = getSectionTitle(sectionId)
      label = "".concat(title, ::loc("ui/ellipsis"))
      isEnabled = cfg?[sectionId].enableFunc(unit) ?? true
    }

    local color = isEnabled ? "hudGreenTextColor" : ""

    if (!isEnabled && isDebugMode)
    {
      if (isShortcut)
        shortcutId = c.shortcut?[0]
      isEnabled = isSection || (isShortcut && shortcutId != null)
      color = isEnabled ? "fadedTextColor" : color
    }

    local isEmpty = label == ""

    menu.append(isEmpty ? null : {
      sectionId  = sectionId
      shortcutId = shortcutId
      name = ::colorize(color, label)
      shortcutText = shouldAddAccessKeys
        ? ::loc("ui/comma").concat($"{idx+1}", ::loc($"key/Num_{idx+1}"))
        : null
      accessKey    = shouldAddAccessKeys ? $"{idx+1} | Num{idx+1}" : null
      wheelmenuEnabled = isEnabled
    })
  }

  local params = {
    menu = menu
    callbackFunc = callbackFunc
    curSectionId = curSectionId
    mouseEnabled = joyParams.useMouseForVoiceMessage || joyParams.useJoystickMouseForVoiceMessage
    axisEnabled  = true
    isAccessKeysEnabled = shouldAddAccessKeys
    shouldShadeBackground = false
  }

  local handler = getHandler()
  if (handler)
    handler.reinitScreen(params)
  else
    ::handlersManager.loadHandler(::gui_handlers.multifuncMenuHandler, params)

  if (isForward)
    cfg[curSectionId]?.onEnter()

  return true
}

callbackFunc = function (idx)
{
  if (idx < 0)
    getHandler()?.gotoPrevMenuOrQuit()
  else if (menu?[idx].sectionId)
    open(menu[idx].sectionId)
  else if (menu?[idx].shortcutId)
    getHandler()?.toggleShortcut(menu[idx].shortcutId)
}

//--------------------------------------------------------------------------------------------------

class ::gui_handlers.multifuncMenuHandler extends ::gui_handlers.wheelMenuHandler
{
  wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_IN_MULTIFUNC_MENU
                                 | CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
                                 | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
                                 | CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP

  wndControlsAllowMaskWhenInactive = CtrlsInGui.CTRL_ALLOW_FULL
  wndControlsAllowMaskOnShortcut   = CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD

  curSectionId = null
  path = null

  function initScreen()
  {
    base.initScreen()

    path = path ?? []
    path.append(curSectionId)

    updateCaption()
  }

  function updateCaption()
  {
    local objCaption = scene.findObject("wheel_menu_category")
    local text = getSectionTitle(curSectionId)
    objCaption.setValue(::colorize("hudGreenTextColor", text))
  }

  function toggleShortcut(shortcutId)
  {
    switchControlsAllowMask(wndControlsAllowMaskOnShortcut)
    ::handlersManager.doDelayed(function() {
      ::toggle_shortcut(shortcutId)
      ::handlersManager.doDelayed(function() {
        switchControlsAllowMask(isActive ? wndControlsAllowMaskWhenActive
                                         : wndControlsAllowMaskWhenInactive)
      }.bindenv(this))
    }.bindenv(this))
  }

  function gotoPrevMenuOrQuit()
  {
    if (path.len() == 0)
      return

    local escapingSectionId = path.pop()
    cfg[escapingSectionId]?.onExit()

    if (path.len() > 0)
      open(path.pop(), false)
    else
      quit()
  }

  function quit()
  {
    if (isActive)
    {
      foreach (escapingSectionId in path.reverse())
        cfg[escapingSectionId]?.onExit()
      path.clear()
      showScene(false)
    }
  }
}

//--------------------------------------------------------------------------------------------------

// Called from client
::on_multifunc_menu_request <- function on_multifunc_menu_request(isShow)
{
  if (isShow)
    return open()
  getHandler()?.quit()
  return true
}

::debug_multifunc_menu <- @(enable) isDebugMode = enable
