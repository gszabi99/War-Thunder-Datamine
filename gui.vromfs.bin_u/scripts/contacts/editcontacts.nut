//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let CONTACT_ADD_PARAM_NAME = "add"
let CONTACT_REMOVE_PARAM_NAME = "remove"
let DataBlock = require("DataBlock")

return function(list, groupName, showNotification = false) {
  let blk = DataBlock()
  blk.addBlock("body")
  blk.body.setBool("returnResultedChanges", true)
  blk.body.addBlock(groupName)

  foreach (isAdding, playersList in list) {
    let opParamName = isAdding ? CONTACT_ADD_PARAM_NAME : CONTACT_REMOVE_PARAM_NAME
    foreach (player in playersList) {
      if (isAdding == ::isPlayerInContacts(player.uid, groupName))
        continue //no need to do something

      if (isAdding && !::can_add_player_to_contacts_list(groupName, !showNotification))
        continue //Too many contacts

      blk.body[groupName].addInt(opParamName, player.uid.tointeger())
    }
  }

  if (blk.body[groupName].paramCount() == 0)
    return

  ::g_tasker.charRequestBlk(
    "cln_set_contact_lists",
    blk,
    null,
    function(result) {
      //Result is always returns
      ::reload_contact_list()

      let added = result?.added ?? -1
      if (added > 0 && groupName == EPL_FRIENDLIST) {
        for (local i = 0; i < blk.body[groupName].paramCount(); i++)
          if (blk.body[groupName].getParamName(i) == CONTACT_ADD_PARAM_NAME)
            ::send_friend_added_event(blk.body[groupName].getParamValue(i))
      }

      if (showNotification && added >= 0) {
        local text = ""

        if (added == 0)
          text = loc("msgbox/no_friends_added")
        else if (added == 1) {
          let msg = loc("msg/added_to_" + groupName)
          let contactsList = []
          for (local i = 0; i < blk.body[groupName].paramCount(); i++) {
            let uid = blk.body[groupName].getParamValue(i)
            let contact = ::getContact(uid.tostring())
            if (contact)
              contactsList.append(contact)
          }
          text = format(msg, ::g_string.implode(contactsList.map(@(c) c?.getName()), loc("ui/comma")))
        }
        else
          text = format(loc("msgbox/added_friends_number"), added)

        ::g_popups.add(null, text)
      }
    },
    function(result) {
      log($"Contacts: Return error on edit contacts list, {result}")
      debugTableData(blk)

      ::reload_contact_list()
    }
  )
}