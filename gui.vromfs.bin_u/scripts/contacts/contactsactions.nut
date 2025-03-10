from "%scripts/dagui_natives.nut" import get_nicks_find_result_blk, find_nicks_by_prefix
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { getContactByName } = require("%scripts/contacts/contactsManager.nut")
let { addTask } = require("%scripts/tasker.nut")
let { isInstance } = require("%sqStdLibs/helpers/u.nut")
let Contact = require("%scripts/contacts/contact.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { updateContactPresence } = require("%scripts/contacts/contactPresence.nut")
let { contactEvent } = require("%scripts/contacts/contactsConsts.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")

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
          func(::getContact(uid, playerName))
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
  let contact = ::getContact(uid, config?.name)
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
  let usersInfoData = getTblValue("usersInfo", params, null)
  if (usersInfoData == null)
    return

  update_contacts_by_list(usersInfoData)
}

function onEventUpdateExternalsIDs(params) {
  if (!(params?.request?.uid) || !(params?.externalIds))
    return

  let config = params.externalIds
  config.uid <- params.request.uid
  if (params?.request?.afterSuccessUpdateFunc)
    config.afterSuccessUpdateFunc <- params.request.afterSuccessUpdateFunc

  updateContact(config)
}

addListenersWithoutEnv({
  UserInfoManagerDataUpdated = @(p) onEventUserInfoManagerDataUpdated(p)
  UpdateExternalsIDs = @(p) onEventUpdateExternalsIDs(p)
}, g_listener_priority.DEFAULT_HANDLER)

return {
  find_contact_by_name_and_do
  updateContact
  update_contacts_by_list
}