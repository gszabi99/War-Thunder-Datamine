local { getPlayerCurUnit } = require("scripts/slotbar/playerCurUnit.nut")

local getMfmHandler = @() ::handlersManager.findHandlerClassInScene(::gui_handlers.multifuncMenuHandler)
local getMfmSectionTitle = @(section) section?.getTitle() ?? ::loc(section?.title ?? id)

local isDebugMode = false

::debug_multifunc_menu <- @(enable) isDebugMode = enable


local function isEnabledByUnit(config, c, unitId)
{
  if (c == null)
    return false
  if (c?.enable)
    return c.enable(unitId)
  if (c?.section)
  {
    local sect = config[c.section]
    if (sect?.enable)
      return sect.enable(unitId)
    foreach (cc in sect.items)
      if (isEnabledByUnit(config, cc, unitId))
        return true
    return false
  }
  return true
}


local function handleWheelMenuApply(idx)
{
  if (idx < 0)
    getMfmHandler()?.gotoPrevMenuOrQuit()
  else if (menu?[idx].sectionId)
    getMfmHandler()?.gotoSection(menu[idx].sectionId)
  else if (menu?[idx].shortcutId)
    getMfmHandler()?.toggleShortcut(menu[idx].shortcutId)
  else if (menu?[idx].action != null)
    menu?[idx].action()
}


local function makeMfmSection(cfg, id, unit)
{
  local allowedShortcutIds = ::g_controls_utils.getControlsList({ unitType = unit.unitType }).map(@(s) s.id)
  local unitId = unit?.name
  local sectionConfig = cfg[id]

  local menu = []
  foreach (idx, c in sectionConfig.items)
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
      isEnabled = shortcutId != null && isEnabledByUnit(cfg, c, unitId)
    }
    else if (isSection)
    {
      sectionId = c.section
      local title = getMfmSectionTitle(cfg[sectionId])
      label = "".concat(title, ::loc("ui/ellipsis"))
      isEnabled = isEnabledByUnit(cfg, c, unitId)
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

  return menu
}


local function openMfm(cfg, curSectionId = null, isForward = true)
{
  local unit = getPlayerCurUnit()
  local unitType = unit?.unitType
  if (!unitType)
    return false

  curSectionId = curSectionId ?? $"root_{unitType.tag}"
  if (cfg?[curSectionId] == null)
    return false

  local joyParams = ::joystick_get_cur_settings()
  local params = {
    menu = makeMfmSection(cfg, curSectionId, unit)
    callbackFunc = handleWheelMenuApply
    curSectionId = curSectionId
    mouseEnabled = joyParams.useMouseForVoiceMessage || joyParams.useJoystickMouseForVoiceMessage
    axisEnabled  = true
    shouldShadeBackground = ::is_xinput_device()
    mfmDescription = cfg
  }

  local handler = getMfmHandler()
  if (handler)
    handler.reinitScreen(params)
  else
    ::handlersManager.loadHandler(::gui_handlers.multifuncMenuHandler, params)

  if (isForward)
    cfg[curSectionId]?.onEnter()

  return true
}



return {
  getMfmHandler
  getMfmSectionTitle
  openMfm
}
