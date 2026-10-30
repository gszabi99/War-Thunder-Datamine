import "%scripts/user/playerContextMenu.nut" as playerContextMenu
import "%scripts/clans/showClanPageModal.nut" as showClanPageModal
import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/chat/chatStates.nut" import isChatEnableWithPlayer, hasMenuChat
from "%scripts/user/profileStates.nut" import userIdStr
from "%scripts/contacts/contactsChecks.nut" import isPlayerInContacts
from "%scripts/user/userCard/userCardView.nut" import gui_modal_userCard
from "%scripts/clans/clanActions.nut" import approvePlayerRequest, rejectPlayerRequest, blacklistAction
from "%scripts/clans/clanModalHelpers.nut" import requestOpenComplainWnd
from "%scripts/clans/clanInfo.nut" import getMyClanRights
from "%scripts/clans/clanRequests.nut" import requestMembership
from "%scripts/contacts/contacts.nut" import getContact
from "%scripts/chat/openChat.nut" import openChatPrivate
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%globalScripts/loc_helpers.nut" import locByVendor
from "%scripts/dagui_natives.nut" import ps4_is_chat_enabled, clan_get_admin_editor_mode, clan_get_requested_clan_id, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *

let getClanActions = function(clanId) {
  let myClanId = clan_get_my_clan_id()

  return [
    {
      text = loc("clan/btn_membership_req")
      show = myClanId == "-1" && clan_get_requested_clan_id() != clanId
      action = @() requestMembership(clanId)
    }
    {
      text = loc("clan/clanInfo")
      show = clanId != "-1"
      action = @() showClanPageModal(clanId, "", "")
    }
    {
      text = loc("mainmenu/btnComplain")
      show = myClanId != clanId
      action = @() requestOpenComplainWnd(clanId)
    }
  ]
}

let retrieveRequestActions = function(clanId, playerUid, playerName, handler, callback) {
  if (!playerUid) {
    callback?([])
  }

  let myClanRights = getMyClanRights()
  let isClanAdmin = clan_get_admin_editor_mode()

  let isBlock = isPlayerInContacts(playerUid, EPL_BLOCKLIST)
  let contact = getContact(playerUid, playerName)
  let name = contact?.name ?? playerName
  contact.checkInteractionStatus(function(comms_state) {
    let canChat = contact?.canChat(comms_state) ?? isChatEnableWithPlayer(name, comms_state)
    let isProfileMuted = contact?.isMuted(comms_state) ?? false

    callback?([
      {
        text = loc("contacts/message")
        isVisualDisabled = !canChat || isBlock || isProfileMuted
        show = playerUid != userIdStr.get()
               && ps4_is_chat_enabled()
               && !u.isEmpty(name)
               && hasMenuChat.get()
        action = function() {
          if (isBlock)
            return playerContextMenu.showBlockedPlayerPopup(name)

          if (isProfileMuted) 
            return playerContextMenu.showXboxPlayerMuted(name)

          if (!canChat)
            return playerContextMenu.notifyPlayerAboutRestriction(contact)

          openChatPrivate(name, handler)
        }
      }
      {
        text = locByVendor("mainmenu/btnProfile")
        action = @() gui_modal_userCard({ uid = playerUid })
      }
      {
        text = loc("clan/requestApprove")
        show = isInArray("MEMBER_ADDING", myClanRights) || isClanAdmin
        action = @() approvePlayerRequest(playerUid, clanId)
      }
      {
        text = loc("clan/requestReject")
        show = isInArray("MEMBER_REJECT", myClanRights) || isClanAdmin
        action = @() rejectPlayerRequest(playerUid, clanId)
      }
      {
        text = loc("clan/blacklistAdd")
        show = isInArray("MEMBER_BLACKLIST", myClanRights) || isClanAdmin
        action = @() blacklistAction(playerUid, true, clanId)
      }
    ])
  })
}

return freeze({
  getClanActions = getClanActions
  retrieveRequestActions = retrieveRequestActions
})