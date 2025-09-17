from "%scripts/dagui_library.nut" import *

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { shouldActionBarFontBeTiny } = require("%scripts/hud/hudActionBarInfo.nut")

const EXTRA_ACTION_ID_PREFIX = "extra_action_bar_item_"
let getExtraActionBarObjId = @(itemId) $"{EXTRA_ACTION_ID_PREFIX}{itemId}"
let { has_secondary_weapons } = require("weaponSelector")

let extraItemViewTemplate = {
  id = 0
  actionId = 0
  selected = "no"
  active = "yes"
  activeBool = true
  enable = "yes"
  enableBool = true
  wheelmenuEnabled = false
  shortcutText = ""
  useShortcutTinyFont = false
  isXinput = false
  showShortcut = true
  amount = ""
  cooldown = 360
  cooldownIncFactor = 0
  blockedCooldown = 360
  blockedCooldownIncFactor = 0
  progressCooldown = 360
  progressCooldownIncFactor = 0
  automatic = false
  hasSecondActionsBtn = false
  isCloseSecondActionsBtn =  false
  icon = null
  inProgressTime = 0.0
  countEx = -1
}

let weaponSelectorActions = [
  {
    shortcutId = "ID_SWITCH_SHOOTING_CYCLE_SECONDARY"
    icon = "#ui/gameuiskin#custom_preset.avif"
    tooltipLocId = "hotkeys/ID_SWITCH_SHOOTING_CYCLE_SECONDARY"
  }
  {
    shortcutId = "ID_OPEN_VISUAL_WEAPON_SELECTOR"
    icon = "#ui/gameuiskin#weapon_selector_icon"
    tooltipLocId = "tooltip/weaponSelector"
  }
]

function addWeaponSelectorActions(unit, items, extraId) {
  let hudUnitType = getHudUnitType()
  let isAir = (hudUnitType == HUD_UNIT_TYPE.AIRCRAFT) || (hudUnitType == HUD_UNIT_TYPE.HELICOPTER)
  if (!isAir || !hasFeature("AirVisualWeaponSelector") || !unit.hasWeaponSlots || !has_secondary_weapons())
    return extraId

  foreach (action in weaponSelectorActions) {
    let { shortcutId, icon, tooltipLocId } = action
    let shType = g_shortcut_type.getShortcutTypeByShortcutId(shortcutId)
    let scInput = shType.getFirstInput(shortcutId)
    let shortcutText = scInput.getTextShort()
    let isXinput = scInput.hasImage() && scInput.getDeviceId() != STD_KEYBOARD_DEVICE_ID
    let showShortcut = isXinput || shortcutText != ""
    let item = extraItemViewTemplate.__merge({
      id = getExtraActionBarObjId(extraId)
      shortcutText
      isXinput = showShortcut && isXinput
      useShortcutTinyFont = shouldActionBarFontBeTiny(shortcutText)
      onClick = "onActivateByShortcutId"
      mainShortcutId = shortcutId
      icon
      cooldownParams = { degree = 360, incFactor = 0 }
      blockedCooldownParams = { degree = 360, incFactor = 0 }
      progressCooldownParams = { degree = 360, incFactor = 0 }
      tooltipText = loc(tooltipLocId)
    })
    extraId++
    items.append(item)
  }
  return extraId
}

function getExtraActionItemsView(unit) {
  if (unit == null)
    return []

  local extraId = 1
  let items = []
  extraId = addWeaponSelectorActions(unit, items, extraId)
  return items
}

return {
  getExtraActionItemsView
}