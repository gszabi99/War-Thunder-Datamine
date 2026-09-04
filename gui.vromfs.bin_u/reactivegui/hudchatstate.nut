import "%rGui/interopGen.nut" as interopGet
from "mission" import get_mission_time
from "eventbus" import eventbus_subscribe
from "chat" import CHAT_MODE_ALL
from "%rGui/globals/ui_library.nut" import *

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
let canWriteToChat = Computed(@() inputEnable.get() && hasEnableChatMode.get())
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
  hudChatState.hudLog.get().append(message)
  hudChatState.hudLog.trigger()
}

let mpChatClear = @() hudChatState.hudLog.set([])

function mpChatInputChanged(_) {
  hudChatState.lastInputTime.set(get_mission_time())
}

eventbus_subscribe("setHasEnableChatMode", @(v) hasEnableChatMode.set(v.hasEnableChatMode))
eventbus_subscribe("setInputEnable", @(v) inputEnable.set(v.value))
eventbus_subscribe("hudChatModeIdUpdate", @(v) hudChatState.modeId.set(v.modeId))
eventbus_subscribe("mpChatPushMessage", mpChatPushMessage)
eventbus_subscribe("mpChatInputChanged", mpChatInputChanged)
eventbus_subscribe("mpChatClear", @(_) mpChatClear())

interopGet({
  stateTable = hudChatState
  prefix = "hudChat"
  postfix = "Update"
})

return hudChatState.__merge({pushSystemMessage})
