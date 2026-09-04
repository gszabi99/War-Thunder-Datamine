import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%scripts/dagui_natives.nut" import gchat_chat_message, gchat_escape_target

let systemMsg = require("%scripts/utils/systemMsg.nut")



const MAX_MSG_LEN = 200
const LOCALIZED_MESSAGE_PREFIX = "LMSG "

function validateChatMessage(text, multilineAllowed = false) {
  
  text = text.replace("<", "[")
  text = text.replace(">", "]")
  if (!multilineAllowed)
    text = text.replace("\\n", " ")
  return text
}

function sendLocalizedMessage(roomId, langConfig, isSeparationAllowed = true, needAssert = true) {
  let message = systemMsg.configToJsonString(langConfig, validateChatMessage)
  let messageLen = message.len() 
  if (messageLen > MAX_MSG_LEN) {
    local res = false
    if (isSeparationAllowed && u.isArray(langConfig) && langConfig.len() > 1) {
      needAssert = false
      
      let sliceIdx = (langConfig.len() + 1) / 2
      res = sendLocalizedMessage(roomId, langConfig.slice(0, sliceIdx), false)
      res = res && sendLocalizedMessage(roomId, langConfig.slice(sliceIdx), false)
    }

    if (!res && needAssert) {
      let partsAmount = u.isArray(langConfig) ? langConfig.len() : 1
      script_net_assert_once("too long json message", $"Too long json message to chat. partsAmount = {partsAmount}")
    }
    return res
  }

  gchat_chat_message(gchat_escape_target(roomId), "".concat(LOCALIZED_MESSAGE_PREFIX, message))
  return true
}

return {
  MAX_MSG_LEN
  LOCALIZED_MESSAGE_PREFIX
  validateChatMessage
  sendLocalizedMessage
}
