import "%scripts/g_listener_priority.nut" as g_listener_priority
import "DataBlock" as DataBlock
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/contacts/contactsListState.nut" import getContactByName
from "%scripts/tasker.nut" import addTask
from "%scripts/contacts/contactPresence.nut" import updateContactPresence
from "%scripts/contacts/contactsConsts.nut" import contactEvent
from "%scripts/contacts/contacts.nut" import getContact
from "%sqStdLibs/helpers/u.nut" import isInstance
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%globalScripts/yuplay2Consts.nut" import *
from "%scripts/dagui_natives.nut" import get_nicks_find_result_blk, find_nicks_by_prefix
from "%scripts/dagui_library.nut" import *

let Contact = require("%scripts/contacts/contact.nut")

function find_contact_by_name_and_do(playerName, func) { 
  let contact = getContactByName(playerName)
  if (contact && contact?.uid != "") {
    func(contact)
    return null
  }

  let taskCallback = function(result = YU2_OK) {
    if (!func)
      return

    if (result == YU2_OK) {
      local searchRes = DataBlock()
      searchRes = get_nicks_find_result_blk()
      foreach (uid, nick in searchRes)
        if (nick == playerName) {
          func(getContact(uid, playerName))
          return
        }
    }

    func(null)
    showInfoMsgBox(loc("chat/error/item-not-found", { nick = getPlayerName(playerName) }), "incorrect_user")
  }

  let taskId = find_nicks_by_prefix(playerName, 1, false)
  addTask(taskId, null, taskCallback, taskCallback)
  return taskId
}

function updateContact(config) {
  let configIsContact = isInstance(config) && config instanceof Contact
  if (isInstance(config) && !configIsContact) { 
    script_net_assert_once("strange config for contact update", "strange config for contact update")
    return null
  }

  let uid = config.uid
  let contact = getContact(uid, config?.name)
  if (!contact)
    return null

  
  if (!configIsContact) {
    if (config?.needReset ?? false)
      contact.resetMatchingParams()

    contact.update(config)
  }

  updateContactPresence(contact)

  return contact
}

function update_contacts_by_list(list, needEvent = true) {
  foreach (config in list)
    updateContact(config)

  if (needEvent)
    broadcastEvent(contactEvent.CONTACTS_UPDATED)
}

function onEventUserInfoManagerDataUpdated(params) {
  let usersInfoData = params?.usersInfo
  if (usersInfoData == null)
    return

  update_contacts_by_list(usersInfoData)
}

function onEventUpdateExternalsIDs(params) {
  if (!(params?.request.uid) || !(params?.externalIds))
    return

  let config = params.externalIds
  config.uid <- params.request.uid
  if (params?.request.afterSuccessUpdateFunc)
    config.afterSuccessUpdateFunc <- params.request.afterSuccessUpdateFunc

  updateContact(config)
}

addListenersWithoutEnv({
  UserInfoManagerDataUpdated = @(p) onEventUserInfoManagerDataUpdated(p)
  UpdateExternalsIDs = @(p) onEventUpdateExternalsIDs(p)
}, g_listener_priority.DEFAULT_HANDLER)

return freeze({
  find_contact_by_name_and_do
  updateContact
  update_contacts_by_list
})