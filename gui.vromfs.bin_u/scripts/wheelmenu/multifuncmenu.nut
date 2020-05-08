local cfg = require("scripts/wheelmenu/multifuncmenuCfg.nut")
local { isMultifuncMenuAvailable } = require("scripts/wheelmenu/multifuncmenuShared.nut")

local getHandler = @() ::handlersManager.findHandlerClassInScene(::gui_handlers.multifuncMenuHandler)
local callbackFunc = null
local isDebugMode = false
local getSectionTitle = @(id) cfg[id]?.getTitle() ?? ::loc(cfg[id]?.title ?? id)

local function isEnabledByUnit(c, unitId)
{
  if (c == null)
    return false
  if (c?.enable)
    return c.enable(unitId)
  if (c?.section)
  {
    local sect = cfg[c.section]
    if (sect?.enable)
      return sect.enable(unitId)
    foreach (cc in sect.items)
      if (isEnabledByUnit(cc, unitId))
        return true
    return false
  }
  return true
}

local function open(curSectionId = null, isForward = true)
{
  if (!isMultifuncMenuAvailable())
    return false

  local joyParams = ::joystick_get_cur_settings()
  local unit = ::get_player_cur_unit()
  local unitId = unit?.name
  local unitType = unit?.unitType
  if (!unitType)
    return false

  curSectionId = curSectionId ?? $"root_{unitType.tag}"
  if (cfg?[curSectionId] == null)
    return false

  local allowedShortcutIds = ::g_controls_utils.getControlsList({ unitType = unit.unitType })
    .map(@(s) s.id)

  local menu = []
  foreach (idx, c in cfg[curSectionId].items)
  {
    if (::u.isFunction(c))
      c = c()

    local isShortcut = "shortcut" in c
    local isSection  = "section"  in c
    local isAction   = "action"   in c

    local shortcutId = null
    local sectionId = null
    local action = null
    local label = ""
    local isEnabled = false

    if (isShortcut)
    {
      shortcutId = c.shortcut.findvalue(@(id) allowedShortcutIds.indexof(id) != null)
      label = ::loc("hotkeys/{0}".subst(shortcutId ?? c.shortcut?[0] ?? ""))
      isEnabled = shortcutId != null && isEnabledByUnit(c, unitId)
    }
    else if (isSection)
    {
      sectionId = c.section
      local title = getSectionTitle(sectionId)
      label = "".concat(title, ::loc("ui/ellipsis"))
      isEnabled = isEnabledByUnit(c, unitId)
    }
    else if (isAction)
    {
      action = c.action
      label = c.label
      isEnabled = label != ""
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

    local shortcutText = ""
    if (!isEmpty && ::is_platform_pc)
      shortcutText = ::get_shortcut_text({
        shortcuts = ::get_shortcuts([ $"ID_VOICE_MESSAGE_{idx+1}" ])
        shortcutId = 0
        cantBeEmpty = false
        strip_tags = true
        colored = isEnabled
      })

    menu.append(isEmpty ? null : {
      sectionId  = sectionId
      shortcutId = shortcutId
      action = action
      name = ::colorize(color, label)
      shortcutText = shortcutText != "" ? shortcutText : null
      wheelmenuEnabled = isEnabled
    })
  }

  local params = {
    menu = menu
    callbackFunc = callbackFunc
    curSectionId = curSectionId
    mouseEnabled = joyParams.useMouseForVoiceMessage || joyParams.useJoystickMouseForVoiceMessage
    axisEnabled  = true
    shouldShadeBackground = ::is_xinput_device()
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
  else if (menu?[idx].action != null)
    menu?[idx].action()
}

//--------------------------------------------------------------------------------------------------

class ::gui_handlers.multifuncMenuHandler extends ::gui_handlers.wheelMenuHandler
{
  wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_IN_MULTIFUNC_MENU
                                 | CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
                                 | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
                                 | CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP

  wndControlsAllowMaskWhenInactive = CtrlsInGui.CTRL_ALLOW_FULL

  wndControlsAllowMaskOnShortcutPc      = CtrlsInGui.CTRL_IN_MULTIFUNC_MENU
                                        | CtrlsInGui.CTRL_ALLOW_FULL

  wndControlsAllowMaskOnShortcutXinput  = CtrlsInGui.CTRL_IN_MULTIFUNC_MENU
                                        | CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                        | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD

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
    if ("emulate_shortcut" in ::getroottable())
    {
      ::emulate_shortcut(shortcutId)
    }
    else // Compatibility with client 1.97.1.X and older
    {
      switchControlsAllowMask(::is_xinput_device() ? wndControlsAllowMaskOnShortcutXinput
                                                   : wndControlsAllowMaskOnShortcutPc)
      ::handlersManager.doDelayed(::Callback(function() {
        ::toggle_shortcut(shortcutId)
        ::handlersManager.doDelayed(::Callback(function() {
          switchControlsAllowMask(isActive ? wndControlsAllowMaskWhenActive
                                           : wndControlsAllowMaskWhenInactive)
        }, this))
      }, this))
    }
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

// Called from client
::on_multifunc_menu_item_selected <- function on_multifunc_menu_item_selected(index, isDown) {
  getHandler()?.onShortcutSelectCallback(index, isDown)
  return true
}

::debug_multifunc_menu <- @(enable) isDebugMode = enable
