from "%rGui/globals/ui_library.nut" import *

let {interop} = require("%rGui/globals/interop.nut")
let {get_mission_time} = require("%rGui/globals/mission.nut")
let interopGet = require("interopGen.nut")

let hudLog = Watched([])

let hudChatState = persist("hudChatState", @() {
  inputEnable = Watched(false)

  //her for now, but it's more common state then chat
  mouseEnabled = Watched(false)

  hudLog
  input = Watched("")
  lastInputTime = Watched(0)
  inputChatVisible = Watched(false)
  modeId = Watched(0)
  hasEnableChatMode = Watched(false)

  pushSystemMessage = function (text) {
    hudLog.mutate(@(v) v.append({
      sender = ""
      text = text
      isMyself = false
      isBlocked = false
      isAutomatic = true
      mode = CHAT_MODE_ALL
      team = 0
      time = get_mission_time()
    }))
  }
})

let {inputEnable, hasEnableChatMode} = hudChatState
let canWriteToChat = Computed(@() inputEnable.value && hasEnableChatMode.value)
hudChatState.canWriteToChat <- canWriteToChat

interop.mpChatPushMessage <- function (message) {
  hudChatState.hudLog.value.append(message)
  hudChatState.hudLog.trigger()
}

interop.mpChatClear <- function () {
  hudChatState.hudLog([])
}

interop.mpChatInputChanged <- function (_new_chat_input_text) {
  hudChatState.lastInputTime(get_mission_time())
}

interopGet({
  stateTable = hudChatState
  prefix = "hudChat"
  postfix = "Update"
})

return hudChatState

