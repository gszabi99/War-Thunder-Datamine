from "%scripts/dagui_natives.nut" import gchat_is_enabled
from "%scripts/dagui_library.nut" import *

let { lastGamercardScenes } = require("%scripts/gamercard/gamercardState.nut")
let { invitesAmount } = require("%scripts/invites/invitesState.nut")
let { hasMenuChat } = require("%scripts/chat/chatStates.nut")
let { chatRooms } = require("%scripts/chat/chatStorage.nut")

function doWithAllGamercards(func) {
  foreach (scene in lastGamercardScenes)
    if (checkObj(scene))
      func(scene)
}

function getLastGamercardScene() {
  if (lastGamercardScenes.len() > 0)
    for (local i = lastGamercardScenes.len() - 1; i >= 0; i--)
      if (checkObj(lastGamercardScenes[i]))
        return lastGamercardScenes[i]
      else
        lastGamercardScenes.remove(i)
  return null
}

function addGamercardScene(scene) {
  for (local idx = lastGamercardScenes.len() - 1; idx >= 0; idx--) {
    let s = lastGamercardScenes[idx]
    if (!checkObj(s))
      lastGamercardScenes.remove(idx)
    else if (s.isEqual(scene))
      return
  }
  lastGamercardScenes.append(scene)
}

function updateGcButton(obj, isNew, tooltip = null) {
  if (!checkObj(obj))
    return

  if (tooltip)
    obj.tooltip = tooltip

  showObjectsByTable(obj, {
    icon    = !isNew
    iconNew = isNew
  })

  let objGlow = obj.findObject("iconGlow")
  if (checkObj(objGlow))
    objGlow.wink = isNew ? "yes" : "no"
}

function updateGcInvites(scene) {
  let haveNew = invitesAmount.get() > 0
  updateGcButton(scene.findObject("gc_invites_btn"), haveNew)
}

function countNewMessages(callback) {
  local newMessagesCount = 0
  local countInternal = null
  countInternal = function(rooms_, idx) {
    if (idx >= rooms_.len()) {
      callback?(newMessagesCount)
    }
    else {
      local room = rooms_[idx]
      room.concealed(function(isConcealed) {
        if (!room.hidden && !isConcealed)
          newMessagesCount += room.newImportantMessagesCount
        countInternal(rooms_, idx + 1)
      })
    }
  }
  countInternal(chatRooms, 0)
}

function updateGamercardsChatInfo(prefix = "gc_") {
  if (!gchat_is_enabled() || !hasMenuChat.value)
    return

  countNewMessages(function(newMessagesCount) {
    let haveNew = newMessagesCount > 0
    let tooltip = loc(haveNew ? "mainmenu/chat_new_messages" : "mainmenu/chat")

    let newMessagesText = newMessagesCount ? newMessagesCount.tostring() : ""

    doWithAllGamercards(function(scene) {
      let objBtn = scene.findObject($"{prefix}chat_btn")
      if (!checkObj(objBtn))
        return

      updateGcButton(objBtn, haveNew, tooltip)
      let newCountChatObj = objBtn.findObject($"{prefix}new_chat_messages")
      newCountChatObj.setValue(newMessagesText)
    })
  })
}

function getActiveGamercardPopupNestObj() {
  let gcScene = getLastGamercardScene()
  let nestObj = gcScene ? gcScene.findObject("chatPopupNest") : null
  return checkObj(nestObj) ? nestObj : null
}

function setLastGamercardSceneIfExist(scene) {
  foreach (idx, gcs in lastGamercardScenes)
    if (checkObj(gcs) && scene.isEqual(gcs)
        && idx < lastGamercardScenes.len() - 1) {
      lastGamercardScenes.remove(idx)
      lastGamercardScenes.append(scene)
      break
    }
}

return {
  doWithAllGamercards
  getLastGamercardScene
  addGamercardScene
  updateGcInvites
  updateGcButton
  updateGamercardsChatInfo
  getActiveGamercardPopupNestObj
  setLastGamercardSceneIfExist
}