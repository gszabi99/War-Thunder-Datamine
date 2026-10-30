import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
import "%scripts/user/bhvAvatar.nut" as bhvAvatar
from "%scripts/unlocks/unlocksModule.nut" import isUnlockVisible, isUnlockOpened
from "%scripts/unlocks/unlocksCache.nut" import getUnlocksByTypeInBlkOrder
from "%globalScripts/unlockConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let seenAvatars = require("%scripts/seen/seenList.nut").get(SEEN.AVATARS)
let { AVATARS } = require("%scripts/utils/configs.nut")

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

function getAvatarIconIdByUserInfo(userInfo) {
  let { pilotIcon = "", pilotId = "" } = userInfo
  if (pilotIcon != null && pilotIcon != "")
    return pilotIcon

  return getIcons()?[pilotId] ?? "cardicon_default"
}

return freeze({
  getIcons = getIcons
  getAvatarIconIdByUserInfo
})