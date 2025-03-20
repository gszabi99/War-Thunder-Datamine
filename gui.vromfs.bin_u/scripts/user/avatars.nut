from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let bhvAvatar = require("%scripts/user/bhvAvatar.nut")
let seenAvatars = require("%scripts/seen/seenList.nut").get(SEEN.AVATARS)
let { AVATARS } = require("%scripts/utils/configs.nut")
let { isUnlockVisible, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")

local icons = null
local allowedIcons = null

function getIcons(full = false) {
  if (!icons)
    icons = getUnlocksByTypeInBlkOrder("pilot")
  return full ? icons : icons.map(@(u) u.id)
}

function getAllowedIcons() {
  if (!allowedIcons)
    allowedIcons = getIcons(true).filter(@(unlock) isUnlockOpened(unlock.id, UNLOCKABLE_PILOT) && isUnlockVisible(unlock))
  return allowedIcons.map(@(v) v.id)
}

function invalidateIcons() {
  icons = null
  allowedIcons = null
  let guiScene = get_cur_gui_scene()
  if (guiScene) 
    guiScene.performDelayed(this, @() seenAvatars.onListChanged())
}

subscriptions.addListenersWithoutEnv({
  LoginComplete    = @(_p) invalidateIcons()
  ProfileUpdated   = @(_p) invalidateIcons()
}, g_listener_priority.CONFIG_VALIDATION)

bhvAvatar.init({
  getIconPath = @(icon) $"#ui/images/avatars/{icon}.avif"
  getConfig = AVATARS.get.bindenv(AVATARS)
})

seenAvatars.setListGetter(getAllowedIcons)

return {
  getIcons = getIcons
  getAvatarIconById = @(id) getIcons()?[id] ?? "cardicon_default"
}