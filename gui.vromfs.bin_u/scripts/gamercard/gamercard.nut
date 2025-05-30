from "%scripts/dagui_natives.nut" import gchat_is_enabled
from "%scripts/dagui_library.nut" import *

let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { lastGamercardScenes } = require("%scripts/gamercard/gamercardState.nut")
let { doWithAllGamercards } = require("%scripts/gamercard/gamercardHelpers.nut")
let { fillGamercard } = require("%scripts/gamercard/fillGamercard.nut")
let { hasMenuChat } = require("%scripts/chat/chatStates.nut")

function updateGamercards() {
  let info = getProfileInfo()
  local needUpdateGamerCard = false
  for (local idx = lastGamercardScenes.len() - 1; idx >= 0; idx--) {
    let s = lastGamercardScenes[idx]
    if (!s || !s.isValid())
      lastGamercardScenes.remove(idx)
    else if (s.isVisible()) {
      needUpdateGamerCard = true
      fillGamercard(info, "gc_", s, false)
    }
  }
  if (!needUpdateGamerCard)
    return

  ::checkNewNotificationUserlogs()
  broadcastEvent("UpdateGamercard")
}
::update_gamercards <- updateGamercards 

function updateGamercardChatButton() {
  let canChat = gchat_is_enabled() && hasMenuChat.value
  doWithAllGamercards(@(scene) showObjById("gc_chat_btn", canChat, scene))
}

hasMenuChat.subscribe(@(_) updateGamercardChatButton())

globalCallbacks.addTypes({
  onOpenGameModeSelect = {
    onCb = @(_obj, _params) broadcastEvent("OpenGameModeSelect")
  }
})


return {
  updateGamercards
}