from "%scripts/dagui_library.nut" import *

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

return {
  chatUpdateState
  voiceChatStats
  langsList
  globalChatRooms
}