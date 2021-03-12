local hudChatState = persist("hudChatState", @() {
  inputEnabled = Watched(false)

  //her for now, but it's more common state then chat
  mouseEnabled = Watched(false)

  log = Watched([])
  input = Watched("")
  lastInputTime = Watched(0)
  inputChatVisible = Watched(false)
  modeId = Watched(0)

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

::interop.mpChatPushMessage <- function (message) {
  hudChatState.log.value.append(message)
  hudChatState.log.trigger()
}


::interop.mpChatClear <- function () {
  hudChatState.log([])
}


::interop.mpChatModeChange <- function (new_mode_id) {
  hudChatState.modeId(new_mode_id)
}


::interop.hudChatInputEnableUpdate <- function (enable) {
  hudChatState.inputEnabled(enable)
}


::interop.mpChatInputChanged <- function (new_chat_input_text) {
  hudChatState.lastInputTime(::get_mission_time())
}


return hudChatState
