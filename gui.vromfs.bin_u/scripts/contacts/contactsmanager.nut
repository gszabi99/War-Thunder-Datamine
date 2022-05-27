let { isPlatformSony, isPs4XboxOneInteractionAvailable } = require("%scripts/clientState/platform.nut")

let editContactsList = require("%scripts/contacts/editContacts.nut")

local isDisableContactsBroadcastEvents = false

let function verifyContact(params)
{
  let name = params?.playerName
  local newContact = ::getContact(params?.uid, name, params?.clanTag)
  if (!newContact && name)
    newContact = ::Contact.getByName(name)

  return newContact
}

let function addContactGroup(group)
{
  if(::contacts_groups.contains(group))
    return

  ::contacts_groups.insert(2, group)
  ::contacts[group] <- []
  if(!isDisableContactsBroadcastEvents)
    ::broadcastEvent(contactEvent.CONTACTS_GROUP_ADDED)
}

let function addContact(_contact, groupName, params = {}) {
  let contact = _contact || verifyContact(params)
  if (!contact)
    return null

  addContactGroup(groupName) //Group can be not exist in list

  let existContactIdx = ::contacts[groupName].findindex(@(c) c.isSameContact(contact.uid))
  if (existContactIdx == null)
    ::contacts[groupName].append(contact)

  contact?.updateMuteStatus()
  return contact
}

let function clear_contacts()
{
  ::contacts_groups = []
  foreach(num, group in ::contacts_groups_default)
    ::contacts_groups.append(group)
  ::contacts = {}
  foreach(list in ::contacts_groups)
    ::contacts[list] <- []

  if(!isDisableContactsBroadcastEvents)
    ::broadcastEvent("ContactsCleared")
}

let function updateContactsGroups(params) {
  isDisableContactsBroadcastEvents = true

  clear_contacts()

  let friendsToRemove = []
  foreach(listName, list in params.groups)
  {
    if (list == null
        || (
            ::contacts_groups_default.findvalue(@(gr) gr == listName) == null
            && (
                (listName == ::EPLX_PS4_FRIENDS && !isPlatformSony)
                || list.len() == 0
              )
          )
       )
      continue

    foreach (p in list)
    {
      let playerUid = p?.userId
      let playerName = p?.nick
      let playerClanTag = p?.clanTag

      let player = addContact(null, listName, {
        uid = playerUid
        playerName = playerName
        clanTag = playerClanTag
      })

      if (!player)
      {
        let myUserId = ::my_user_id_int64 // warning disable: -declared-never-used
        let errText = playerUid ? "player not found" : "not valid data"
        ::script_net_assert_once("not found contact for group", errText)
        continue
      }

      if (listName == ::EPL_FRIENDLIST && !isPs4XboxOneInteractionAvailable(playerName))
      {
        friendsToRemove.append(player)
        continue
      }
    }
  }

  if (friendsToRemove.len())
    editContactsList({[false] = friendsToRemove}, ::EPL_FRIENDLIST)

  isDisableContactsBroadcastEvents = false
}

return {
  verifyContact
  addContact
  addContactGroup
  updateContactsGroups
  clear_contacts
}