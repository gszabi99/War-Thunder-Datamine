from "%scripts/dagui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")

enum chatUpdateState {
  OUTDATED
  IN_PROGRESS
  UPDATED
}

enum voiceChatStats {
  online
  offline
  talking
  muted
}

let langsList = ["en", "ru"]

let globalChatRooms = [
  { name = "general", langs = ["en", "ru", "de", "zh", "vn"] },
  { name = "radio", langs = ["ru"], hideInOtherLangs = true },
  { name = "lfg" },
  { name = "historical" },
  { name = "realistic" }
]

let lastChatSceneShow = Watched(null)

eventbus_subscribe("on_sign_out", @(_p) lastChatSceneShow.set(false))

return {
  chatUpdateState
  voiceChatStats
  langsList
  globalChatRooms
  lastChatSceneShow
}