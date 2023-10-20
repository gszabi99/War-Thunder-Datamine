from "%rGui/globals/ui_library.nut" import *

let { get_mission_time } = require("%rGui/globals/mission.nut")
let interopGet = require("interopGen.nut")
let { subscribe } = require("eventbus")
let { CHAT_MODE_ALL } = require("chat")

let hudChatState = {
  inputEnable = false
  //her for now, but it's more common state then chat
  mouseEnabled = false
  hudLog = []
  input = ""
  lastInputTime = 0
  inputChatVisible = false
  modeId = 0
  hasEnableChatMode = false
}.map(@(val, key) mkWatched(persist, key, val))

let { inputEnable, hasEnableChatMode, hudLog } = hudChatState
let canWriteToChat = Computed(@() inputEnable.value && hasEnableChatMode.value)
hudChatState.canWriteToChat <- canWriteToChat

function pushSystemMessage(text) {
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

return hudChatState.__merge({pushSystemMessage})

