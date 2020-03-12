local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local bhvAvatar = ::require("scripts/user/bhvAvatar.nut")
local seenAvatars = ::require("scripts/seen/seenList.nut").get(SEEN.AVATARS)

local DEFAULT_PILOT_ICON = "cardicon_default"

local icons = null
local allowedIcons = null

local function getIcons()
{
  if (!icons)
    icons = ::g_unlocks.getUnlocksByTypeInBlkOrder("pilot").map(@(u) u.id)
  return icons
}

local function getAllowedIcons()
{
  if (!allowedIcons)
    allowedIcons = getIcons().filter(@(unlockId) ::is_unlocked_scripted(::UNLOCKABLE_PILOT, unlockId)
      && ::is_unlock_visible(::g_unlocks.getUnlockById(unlockId)))
  return allowedIcons
}

local getIconById = @(id) getIcons()?[id] ?? DEFAULT_PILOT_ICON

local function openChangePilotIconWnd(cb, handler)
{
  local pilotsOpt = ::get_option(::USEROPT_PILOT)
  local config = {
    options = pilotsOpt.items
    value = pilotsOpt.value
  }

  ::gui_choose_image(config, cb, handler)
}

local function invalidateIcons()
{
  icons = null
  allowedIcons = null
  local guiScene = ::get_cur_gui_scene()
  if (guiScene) //need all other configs invalidate too before push event
    guiScene.performDelayed(this, @() seenAvatars.onListChanged())
}

subscriptions.addListenersWithoutEnv({
  LoginComplete    = @(p) invalidateIcons()
  ProfileUpdated   = @(p) invalidateIcons()
}, ::g_listener_priority.CONFIG_VALIDATION)

bhvAvatar.init({
  intIconToString = getIconById
  getIconPath = @(icon) "#ui/images/avatars/" + icon
  getConfig = ::configs.AVATARS.get.bindenv(::configs.AVATARS)
})

seenAvatars.setListGetter(getAllowedIcons)

return {
  getIcons = getIcons
  getAllowedIcons = getAllowedIcons
  getIconById = getIconById
  openChangePilotIconWnd = openChangePilotIconWnd
}