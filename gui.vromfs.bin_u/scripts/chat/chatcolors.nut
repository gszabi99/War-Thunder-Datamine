from "%scripts/dagui_library.nut" import *

let { userName } = require("%scripts/user/profileStates.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")

let chatColors = freeze({ //better to allow player tune color sheme
  sender =         { [false] = "@mChatSenderColorDark",        [true] = "@mChatSenderColor" }
  senderMe =       { [false] = "@mChatSenderMeColorDark",      [true] = "@mChatSenderMeColor" }
  senderPrivate =  { [false] = "@mChatSenderPrivateColorDark", [true] = "@mChatSenderPrivateColor" }
  senderSquad =    { [false] = "@mChatSenderMySquadColorDark", [true] = "@mChatSenderMySquadColor" }
  senderFriend =   { [false] = "@mChatSenderFriendColorDark",  [true] = "@mChatSenderFriendColor" }
})

function getSenderColor(senderName, isHighlighted = true, isPrivateChat = false, defaultColor = chatColors.sender) {
  if (isPrivateChat)
    return chatColors.senderPrivate[isHighlighted]
  if (senderName == userName.value)
    return chatColors.senderMe[isHighlighted]
  if (g_squad_manager.isInMySquad(senderName, false))
    return chatColors.senderSquad[isHighlighted]
  if (::isPlayerNickInContacts(senderName, EPL_FRIENDLIST))
    return chatColors.senderFriend[isHighlighted]
  return u.isTable(defaultColor) ? defaultColor[isHighlighted] : defaultColor
}
return {
  getSenderColor
  chatColors
}