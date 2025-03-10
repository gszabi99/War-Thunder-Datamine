from "%rGui/globals/ui_library.nut" import *

let { get_mission_time } = require("mission")
let interopGet = require("interopGen.nut")
let { eventbus_subscribe } = require("eventbus")
let { CHAT_MODE_ALL } = require("chat")

let hudChatState = {
  inputEnable = false
  
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
    fullName = ""
    text = text
    isMyself = false
    isBlocked = false
    isAutomatic = true
    mode = CHAT_MODE_ALL
    team = 0
    time = get_mission_time()
  }))
}

function mpChatPushMessage(message) {
  hudChatState.hudLog.value.append(message)
  hudChatState.hudLog.trigger()
}

let mpChatClear = @() hudChatState.hudLog([])

function mpChatInputChanged(_) {
  hudChatState.lastInputTime(get_mission_time())
}

eventbus_subscribe("setHasEnableChatMode", @(v) hasEnableChatMode(v.hasEnableChatMode))
eventbus_subscribe("setInputEnable", @(v) inputEnable(v.value))
eventbus_subscribe("hudChatModeIdUpdate", @(v) hudChatState.modeId(v.modeId))
eventbus_subscribe("mpChatPushMessage", mpChatPushMessage)
eventbus_subscribe("mpChatInputChanged", mpChatInputChanged)
eventbus_subscribe("mpChatClear", @(_) mpChatClear())

interopGet({
  stateTable = hudChatState
  prefix = "hudChat"
  postfix = "Update"
})

return hudChatState.__merge({pushSystemMessage})

