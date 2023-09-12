//checked for plus_string
from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let bhvAvatar = require("%scripts/user/bhvAvatar.nut")
let seenAvatars = require("%scripts/seen/seenList.nut").get(SEEN.AVATARS)
let { AVATARS } = require("%scripts/utils/configs.nut")
let { isUnlockVisible, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockById, getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { USEROPT_PILOT } = require("%scripts/options/optionsExtNames.nut")

let DEFAULT_PILOT_ICON = "cardicon_default"

local icons = null
local allowedIcons = null

let function getIcons() {
  if (!icons)
    icons = getUnlocksByTypeInBlkOrder("pilot").map(@(u) u.id)
  return icons
}

let function getAllowedIcons() {
  if (!allowedIcons)
    allowedIcons = getIcons().filter(@(unlockId) isUnlockOpened(unlockId, UNLOCKABLE_PILOT)
      && isUnlockVisible(getUnlockById(unlockId)))
  return allowedIcons
}

let getIconById = @(id) getIcons()?[id] ?? DEFAULT_PILOT_ICON

let function openChangePilotIconWnd(cb, handler) {
  let pilotsOpt = ::get_option(USEROPT_PILOT)
  let config = {
    options = pilotsOpt.items
    value = pilotsOpt.value
  }

  ::gui_choose_image(config, cb, handler)
}

let function invalidateIcons() {
  icons = null
  allowedIcons = null
  let guiScene = get_cur_gui_scene()
  if (guiScene) //need all other configs invalidate too before push event
    guiScene.performDelayed(this, @() seenAvatars.onListChanged())
}

subscriptions.addListenersWithoutEnv({
  LoginComplete    = @(_p) invalidateIcons()
  ProfileUpdated   = @(_p) invalidateIcons()
}, ::g_listener_priority.CONFIG_VALIDATION)

bhvAvatar.init({
  intIconToString = getIconById
  getIconPath = @(icon) $"#ui/images/avatars/{icon}"
  getConfig = AVATARS.get.bindenv(AVATARS)
})

seenAvatars.setListGetter(getAllowedIcons)

return {
  getIcons = getIcons
  getAllowedIcons = getAllowedIcons
  getIconById = getIconById
  openChangePilotIconWnd = openChangePilotIconWnd
}