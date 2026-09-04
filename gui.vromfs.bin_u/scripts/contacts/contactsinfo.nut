from "%globalScripts/externalPlayerListConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/contacts/contactsConsts.nut" import EPLX_PS4_FRIENDS
let { contactsByGroups } = require("%scripts/contacts/contactsListState.nut")
let { PSN_ICON } = require("%scripts/user/nickTools.nut")





function getPlayerFullName(name, clanTag = "", addInfo = "") {
  local needClan = hasFeature("Clans")



  return nbsp.join([needClan ? clanTag : "", utf8(name), addInfo], true)
}

function colorizeWhitePsnIcon(userName) {
  if (userName.indexof(PSN_ICON) == null)
    return userName
  return userName.replace(PSN_ICON, colorize("white", PSN_ICON))
}

let missed_contacts_data = {}

function getFriendsOnlineNum() {
  if (contactsByGroups.len() == 0)
    return 0
  local online = 0
  foreach (groupName in [EPL_FRIENDLIST, EPLX_PS4_FRIENDS]) {
    if (!(groupName in contactsByGroups))
      continue

    foreach (f in contactsByGroups[groupName])
      if (f.online && !f.forceOffline)
        online++
  }
  return online
}

function collectMissedContactData (uid, key, val) {
  if (!(uid in missed_contacts_data))
    missed_contacts_data[uid] <- {}
  missed_contacts_data[uid][key] <- val
}

return {
  collectMissedContactData
  getFriendsOnlineNum
  missed_contacts_data
  getPlayerFullName
  colorizeWhitePsnIcon
}