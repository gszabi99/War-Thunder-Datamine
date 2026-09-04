from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import gchat_is_enabled
from "%scripts/dagui_library.nut" import *

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

  broadcastEvent("UpdateGamercard")
}

function updateGamercardChatButton() {
  let canChat = gchat_is_enabled() && hasMenuChat.get()
  doWithAllGamercards(@(scene) showObjById("gc_chat_btn", canChat, scene))
}

hasMenuChat.subscribe(@(_) updateGamercardChatButton())

eventbus_subscribe("gamercard.openGameModeSelect", @(_) broadcastEvent("OpenGameModeSelect"))

addListenersWithoutEnv({
  RequestUpdateGamercards = @(_) updateGamercards()
})

return {
  updateGamercards
}