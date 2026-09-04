import "%sqStdLibs/helpers/u.nut" as u
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let { userName } = require("%scripts/user/profileStates.nut")
let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { isPlayerNickInContacts } = require("%scripts/contacts/contactsChecks.nut")

let chatColors = freeze({ 
  sender =         { [false] = "@mChatSenderColorDark",        [true] = "@mChatSenderColor" }
  senderMe =       { [false] = "@mChatSenderMeColorDark",      [true] = "@mChatSenderMeColor" }
  senderPrivate =  { [false] = "@mChatSenderPrivateColorDark", [true] = "@mChatSenderPrivateColor" }
  senderSquad =    { [false] = "@mChatSenderMySquadColorDark", [true] = "@mChatSenderMySquadColor" }
  senderFriend =   { [false] = "@mChatSenderFriendColorDark",  [true] = "@mChatSenderFriendColor" }
})

function getSenderColor(senderName, isHighlighted = true, isPrivateChat = false, defaultColor = chatColors.sender) {
  if (isPrivateChat)
    return chatColors.senderPrivate[isHighlighted]
  if (senderName == userName.get())
    return chatColors.senderMe[isHighlighted]
  if (g_squad_manager.isInMySquad(senderName, false))
    return chatColors.senderSquad[isHighlighted]
  if (isPlayerNickInContacts(senderName, EPL_FRIENDLIST))
    return chatColors.senderFriend[isHighlighted]
  return u.isTable(defaultColor) ? defaultColor[isHighlighted] : defaultColor
}
return {
  getSenderColor
  chatColors
}