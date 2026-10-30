import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/user/profileStates.nut" import userName
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/contacts/contactsChecks.nut" import isPlayerNickInContacts
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%scripts/dagui_library.nut" import *

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
return freeze({
  getSenderColor
  chatColors
})