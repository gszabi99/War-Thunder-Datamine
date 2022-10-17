let interopGet = require("interopGen.nut")

let hudChatState = persist("hudChatState", @() {
  inputEnable = Watched(false)

  //her for now, but it's more common state then chat
  mouseEnabled = Watched(false)

  log = Watched([])
  input = Watched("")
  lastInputTime = Watched(0)
  inputChatVisible = Watched(false)
  modeId = Watched(0)
  hasEnableChatMode = Watched(false)

  pushSystemMessage = function (text) {
   log.value.append({
      sender = ""
      text = text
      isMyself = false
      isBlocked = false
      isAutomatic = true
      mode = CHAT_MODE_ALL
      team = 0
      time = ::get_mission_time()
    })
   log.trigger()
  }
})

let {inputEnable, hasEnableChatMode} = hudChatState
let canWriteToChat = Computed(@() inputEnable.value && hasEnableChatMode.value)
hudChatState.canWriteToChat <- canWriteToChat

::interop.mpChatPushMessage <- function (message) {
  hudChatState.log.value.append(message)
  hudChatState.log.trigger()
}

::interop.mpChatClear <- function () {
  hudChatState.log([])
}

::interop.mpChatInputChanged <- function (_new_chat_input_text) {
  hudChatState.lastInputTime(::get_mission_time())
}

interopGet({
  stateTable = hudChatState
  prefix = "hudChat"
  postfix = "Update"
})

return hudChatState

