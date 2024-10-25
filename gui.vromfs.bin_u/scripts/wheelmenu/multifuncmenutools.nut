from "%scripts/dagui_natives.nut" import get_player_unit_name
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { isXInputDevice } = require("controls")
let { getHudUnitType } = require("hudState")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { unitTypeByHudUnitType } = require("%scripts/hud/hudUnitType.nut")
let { getControlsList } = require("%scripts/controls/controlsUtils.nut")
let getMfmHandler = @() handlersManager.findHandlerClassInScene(gui_handlers.multifuncMenuHandler)
let getMfmSectionTitle = @(section) section?.getTitle() ?? loc(section?.title ?? "")
let { register_command } = require("console")

local isDebugMode = false
register_command(function() {
  isDebugMode = !isDebugMode
  console_print($"MFM DBG is: {isDebugMode ? "on" : "off"}")
}, "debug.switch_mfm_debug")

function isEnabledByUnit(config, c, unitId) {
  if (c == null)
    return false
  if (c?.enable)
    return c.enable(unitId)
  if (c?.section) {
    let sect = config[c.section]
    if (sect?.enable)
      return sect.enable(unitId)
    foreach (cc in sect.items)
      if (isEnabledByUnit(config, cc, unitId))
        return true
    return false
  }
  return true
}


function handleWheelMenuApply(idx) {
  if (idx < 0)
    getMfmHandler()?.gotoPrevMenuOrQuit()
  else if (this.menu?[idx].sectionId)
    getMfmHandler()?.gotoSection(this.menu[idx].sectionId)
  else if (this.menu?[idx].shortcutId)
    getMfmHandler()?.toggleShortcut(this.menu[idx].shortcutId)
  else if (this.menu?[idx].action != null)
    this.menu?[idx].action()
}


function makeMfmSection(cfg, id, unitId, hudUnitType) {
  let allowedShortcutIds = getControlsList(unitTypeByHudUnitType?[hudUnitType]).map(@(s) s.id)
  let sectionConfig = cfg[id]

  let menu = []
  foreach (idx, item in sectionConfig.items) {
    let c = u.isFunction(item) ? item() : item

    let isShortcut = "shortcut" in c
    let isSection  = "section"  in c
    let isAction   = "action"   in c

    local shortcutId = null
    local sectionId = null
    local action = null
    local label = ""
    local isEnabled = false

    if (isShortcut) {
      shortcutId = c.shortcut.findvalue(@(i) allowedShortcutIds.indexof(i) != null)
      label = item?.getText ? item.getText() : (loc("hotkeys/{0}".subst(shortcutId ?? c.shortcut?[0] ?? "")))
      isEnabled = shortcutId != null && isEnabledByUnit(cfg, c, unitId)
    }
    else if (isSection) {
      sectionId = c.section
      let title = getMfmSectionTitle(cfg[sectionId])
      label = "".concat(title, loc("ui/ellipsis"))
      isEnabled = isEnabledByUnit(cfg, c, unitId)
    }
    else if (isAction) {
      action = c.action
      label = c.label
      isEnabled = isEnabledByUnit(cfg, c, unitId) && label != ""
    }

    local color = isEnabled ? "hudGreenTextColor" : ""

    if (!isEnabled && isDebugMode) {
      if (isShortcut)
        shortcutId = c.shortcut?[0]
      isEnabled = isSection || (isShortcut && shortcutId != null)
      color = isEnabled ? "fadedTextColor" : color
    }

    let isEmpty = label == ""

    local shortcutText = ""
    if (!isEmpty && is_platform_pc)
      shortcutText = ::get_shortcut_text({
        shortcuts = ::get_shortcuts([ $"ID_VOICE_MESSAGE_{idx+1}" ])
        shortcutId = 0
        cantBeEmpty = false
        strip_tags = true
        colored = isEnabled
      })

    let menuItem = isEmpty ? null : {
      sectionId
      shortcutId
      onDestroy = item?.onDestroy
      onCreate = item?.onCreate
      eventName = item?.eventName
      itemName = item?.itemName
      onUpdate = item?.onUpdate
      action
      color
      name = colorize(color, label)
      shortcutText
      wheelmenuEnabled = isEnabled
    }

    menu.append(menuItem)
  }

  return menu
}


function openMfm(cfg, curSectionId = null, isForward = true) {
  let hudUnitType = getHudUnitType()
  curSectionId = curSectionId ?? $"root_{hudUnitType}"
  if (cfg?[curSectionId] == null)
    return false

  let joyParams = ::joystick_get_cur_settings()
  let params = {
    menu = makeMfmSection(cfg, curSectionId, get_player_unit_name(), hudUnitType)
    callbackFunc = handleWheelMenuApply
    curSectionId = curSectionId
    mouseEnabled = joyParams.useMouseForVoiceMessage || joyParams.useJoystickMouseForVoiceMessage
    axisEnabled  = true
    shouldShadeBackground = isXInputDevice()
    mfmDescription = cfg
  }

  let handler = getMfmHandler()
  if (handler)
    handler.reinitScreen(params)
  else
    handlersManager.loadHandler(gui_handlers.multifuncMenuHandler, params)

  if (isForward)
    cfg[curSectionId]?.onEnter()

  return true
}

return {
  getMfmHandler
  getMfmSectionTitle
  openMfm
}
