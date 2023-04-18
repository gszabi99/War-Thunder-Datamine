from "%rGui/globals/ui_library.nut" import *

let { get_mission_time } = require("%rGui/globals/mission.nut")
let interopGet = require("interopGen.nut")
let { subscribe } = require("eventbus")
let { CHAT_MODE_ALL } = require("chat")

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

let { inputEnable, hasEnableChatMode } = hudChatState
let canWriteToChat = Computed(@() inputEnable.value && hasEnableChatMode.value)
hudChatState.canWriteToChat <- canWriteToChat

let function mpChatPushMessage(message) {
  hudChatState.hudLog.value.append(message)
  hudChatState.hudLog.trigger()
}

let mpChatClear = @() hudChatState.hudLog([])

let function mpChatInputChanged(_) {
  hudChatState.lastInputTime(get_mission_time())
}

subscribe("setHasEnableChatMode", @(v) hasEnableChatMode(v.hasEnableChatMode))
subscribe("setInputEnable", @(v) inputEnable(v.value))
subscribe("hudChatModeIdUpdate", @(v) hudChatState.modeId(v.modeId))
subscribe("mpChatPushMessage", mpChatPushMessage)
subscribe("mpChatInputChanged", mpChatInputChanged)
subscribe("mpChatClear", @(_) mpChatClear())

interopGet({
  stateTable = hudChatState
  prefix = "hudChat"
  postfix = "Update"
})

return hudChatState

