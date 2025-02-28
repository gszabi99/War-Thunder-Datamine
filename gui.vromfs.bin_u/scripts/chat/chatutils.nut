from "%scripts/dagui_library.nut" import *
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_ONLY_FRIENDLIST_CONTACT } = require("%scripts/options/optionsExtNames.nut")
let { isPlayerNickInContacts, isPlayerInFriendsGroup } = require("%scripts/contacts/contactsChecks.nut")

function getChatObject(scene) {
  if (!checkObj(scene))
    scene = null
  let guiScene = get_gui_scene()
  local chatObj = scene ? scene.findObject("menuChat_scene") : guiScene["menuChat_scene"]
  if (!chatObj) {
    guiScene.appendWithBlk(scene ? scene : "", "tdiv { id:t='menuChat_scene' }")
    chatObj = scene ? scene.findObject("menuChat_scene") : guiScene["menuChat_scene"]
  }
  return chatObj
}

function isUserBlockedByPrivateSetting(uid = null, name = "") {
  let checkUid = uid != null
  let privateValue = get_gui_option_in_mode(USEROPT_ONLY_FRIENDLIST_CONTACT, OPTIONS_MODE_GAMEPLAY)
  return (privateValue && !isPlayerInFriendsGroup(uid, checkUid, name))
    || isPlayerNickInContacts(name, EPL_BLOCKLIST)
}

return {
  getChatObject
  isUserBlockedByPrivateSetting
}