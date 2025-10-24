enum contactEvent {
  CONTACTS_UPDATED = "ContactsUpdated"
  CONTACTS_GROUP_ADDED = "ContactsGroupAdd"
  CONTACTS_GROUP_UPDATE = "ContactsGroupUpdate"
}

const GAME_GROUP_NAME = "warthunder"

const EPLX_SEARCH = "search"
const EPLX_CLAN = "clan"
const EPLX_PS4_FRIENDS = "ps4_friends"
const EPLX_STEAM = "s"

let statusGroupsToRequest = ["requestsToMe", "meInBlacklist"]

let contactsGroupWithoutMaxCount = {
  [EPLX_STEAM] = true,
  [EPLX_PS4_FRIENDS] = true,
  [EPLX_CLAN] = true,
}

let maxContactsByGroup = {
  [EPL_FRIENDLIST] = 300,
  [EPL_BLOCKLIST] = 300,
  [EPL_RECENT_SQUAD] = 100,
  OTHER = 100
}

let getMaxContactsByGroup = @(groupName) maxContactsByGroup?[groupName] ?? maxContactsByGroup.OTHER

return {
  contactEvent
  GAME_GROUP_NAME
  statusGroupsToRequest
  EPLX_SEARCH
  EPLX_CLAN
  EPLX_PS4_FRIENDS
  EPLX_STEAM
  contactsGroupWithoutMaxCount
  getMaxContactsByGroup
}