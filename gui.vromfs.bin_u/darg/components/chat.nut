local scrollableData = require("scrollableData.nut")


local function makeInputField(form_state, send_function) {
  local function send () {
    send_function(form_state.value)
    form_state.update("")
  }
  return function (text_input_ctor) {
    return text_input_ctor(form_state, send)
  }
}


local function makeChatBlock(log_state, send_message_fn) {
  local chatMessageState = ::Watched("")
  local logInstance = scrollableData.make(log_state)

  return {
    form = chatMessageState
    state = log_state
    inputField = makeInputField(chatMessageState, send_message_fn)
    data = logInstance.data
    scrollHandler = logInstance.scrollHandler
  }
}


return makeChatBlock
