from "%rGui/globals/ui_library.nut" import *
let { clearTimer, setTimeout } = require("dagor.workcycle")
let { subscribe } = require("eventbus")

let VOICE_CHAT_MEMBER_PARAMS = {
  id = ""
  name = ""
  animTime = 0.4
  visibleIdx = -1
}

let voiceChatMembers = Watched([])
local counter = 0 //for voice chat key

let function removeVoiceChatMember(id) { //name (string) or id (int)
  foreach (idx, member in voiceChatMembers.value)
    if ((member.name == id || member.id == id)
        && !member.needShow.value) {
        voiceChatMembers.value.remove(idx)
        voiceChatMembers.trigger()
        break
    }
}

let function showVoiceChatMember(config) {
  local voiceChatMember = null
  foreach (member in voiceChatMembers.value)
    if (member.name == config.name) {
      voiceChatMember = member
      voiceChatMember.needShow(true)
      break
    }

  if (voiceChatMember)
    return

  voiceChatMember = VOICE_CHAT_MEMBER_PARAMS.__merge(config)
  voiceChatMember.id <- counter++

  let removeMember = @() removeVoiceChatMember(voiceChatMember.id)

  voiceChatMember.needShow <- Watched(true)
  voiceChatMember.needShow.subscribe(function(newVal) {
    clearTimer(removeMember)
    if (newVal)
      return

    setTimeout(voiceChatMember.animTime, removeMember)
  })

  voiceChatMembers.value.append(voiceChatMember)
  voiceChatMembers.trigger()
}

let function hideVoiceChatMember(config) {
  foreach (member in voiceChatMembers.value)
    if (member.name == config.name) {
      member.needShow(false)
      break
    }
}

let function updateVoiceChatStatus(config) {
  if (config.isTalking)
    showVoiceChatMember(config)
  else
    hideVoiceChatMember(config)
}

subscribe("updateVoiceChatStatus", updateVoiceChatStatus)

return {
  voiceChatMembers
}
