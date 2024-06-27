from "%scripts/dagui_natives.nut" import utf8_strlen
from "%scripts/dagui_library.nut" import *

let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { LONG_ACTIONBAR_TEXT_LEN } = require("%scripts/hud/hudActionBarInfo.nut")

const EXTRA_ACTION_ID_PREFIX = "extra_action_bar_item_"
let getExtraActionBarObjId = @(itemId) $"{EXTRA_ACTION_ID_PREFIX}{itemId}"
let { has_secondary_weapons } = require("weaponSelector")

let extraItemViewTemplate = {
  id = 0
  nestIndex = 0
  selected = "no"
  active = "yes"
  enable = "yes"
  wheelmenuEnabled = false
  shortcutText = null
  isLongScText = false
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

function getExtraActionItemsView(unit) {
  if (unit == null)
    return null

  local extraId = 1
  let items = []
  let hudUnitType = getHudUnitType()
  let isAir = (hudUnitType == HUD_UNIT_TYPE.AIRCRAFT) || (hudUnitType == HUD_UNIT_TYPE.HELICOPTER)

  if (hasFeature("AirVisualWeaponSelector") && unit.hasWeaponSlots && isAir && has_secondary_weapons()) {
    let item = clone extraItemViewTemplate
    let shortcutId = "ID_OPEN_VISUAL_WEAPON_SELECTOR"
    let shType = ::g_shortcut_type.getShortcutTypeByShortcutId(shortcutId)
    let scInput = shType.getFirstInput(shortcutId)
    let shortcutText = scInput.getTextShort()
    let isXinput = scInput.hasImage() && scInput.getDeviceId() != STD_KEYBOARD_DEVICE_ID
    let showShortcut = isXinput || shortcutText != ""

    item.shortcutText = shortcutText
    item.isXinput = showShortcut && isXinput
    item.isLongScText = utf8_strlen(shortcutText) >= LONG_ACTIONBAR_TEXT_LEN
    item.onClick <- "onVisualSelectorClick"
    item.mainShortcutId <- shortcutId
    item.icon = "#ui/gameuiskin#weapon_selector_icon"
    item.id = getExtraActionBarObjId(extraId)
    extraId++
    items.append(item)
  }
  return items
}

return {
  getExtraActionItemsView
}