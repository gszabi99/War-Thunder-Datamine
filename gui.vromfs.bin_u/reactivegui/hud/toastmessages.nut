from "%rGui/globals/ui_library.nut" import *
let { setTimeout } = require("dagor.workcycle")
let { isArray } = require("%sqstd/underscore.nut")

const MAX_SHOWING_MESSAGES = 6
const MESSAGE_SHOW_TIMEOUT = 4
const NEW_MESSAGE_ANIM_DURATION = 0.25
let NEW_MESSAGE_ANIM_EASING = OutQuad

let showingMessages = Watched([])










function showMessage(msg) {
  let msgStringsArr = isArray(msg) ? msg : [msg]

  if (showingMessages.get().len() >= MAX_SHOWING_MESSAGES)
    showingMessages.mutate(@(v) v.remove(0))

  showingMessages.mutate(@(v) v.append(msgStringsArr))
  setTimeout(MESSAGE_SHOW_TIMEOUT, function() {
    let updated = showingMessages.get().filter(@(m) m != msgStringsArr)
    showingMessages.set(updated)
  })
}

let mkMessageLine = @(message)  @() {
  watch = showingMessages
  flow = FLOW_HORIZONTAL
  children = message.map(@(m)  {
    rendObj = ROBJ_TEXT
    text = m.text
    fontSize = hdpx(28)
    color= 0xFFFFFFFF
    fontFx = FFT_SHADOW
    fontFxColor = 0xFF000000
    fontFxFactor = 20
    fontFxOffsX = hdpx(1)
    fontFxOffsY = hdpx(1)
  }.__update(m?.ovr ?? {}))

  transform = {}
  opacity = showingMessages.get().top() == message ? 1 : 0.6
  animations = showingMessages.get().top() == message
    ? [
        {
          prop = AnimProp.scale
          from = [0.5, 0.5]
          to = [1, 1]
          duration = NEW_MESSAGE_ANIM_DURATION
          easing = NEW_MESSAGE_ANIM_EASING
          play = true
          loop = false
        }
        {
          prop = AnimProp.opacity
          from = 0.5
          to = 1
          duration = NEW_MESSAGE_ANIM_DURATION
          easing = NEW_MESSAGE_ANIM_EASING
          play = true
          loop = false
        }
      ]
    : []
}

let toastMessagesComp = @() {
  watch = showingMessages
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = showingMessages.get().map(@(message) mkMessageLine(message))
}

return {
  showMessage
  toastMessagesComp
}