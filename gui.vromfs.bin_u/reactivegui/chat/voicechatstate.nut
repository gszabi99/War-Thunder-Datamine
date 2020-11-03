local VOICE_CHAT_MEMBER_PARAMS = {
  id = ""
  name = ""
  animTime = 0.4
  visibleIdx = -1
}

local voiceChatMembers = Watched([])
local counter = 0 //for voice chat key

local function removeVoiceChatMember(id) { //name (string) or id (int)
  foreach(idx, member in voiceChatMembers.value)
    if ((member.name == id || member.id == id)
        && !member.needShow.value) {
        voiceChatMembers.value.remove(idx)
        voiceChatMembers.trigger()
        break
    }
}

local function showVoiceChatMember(config) {
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

  voiceChatMember.needShow <- Watched(true)
  voiceChatMember.needShow.subscribe(function(newVal) {
    if (newVal)
      return

    ::gui_scene.setInterval(voiceChatMember.animTime,
      function() {
        ::gui_scene.clearTimer(callee())
        removeVoiceChatMember(voiceChatMember.id)
      })
  })

  voiceChatMembers.value.append(voiceChatMember)
  voiceChatMembers.trigger()
}

local function hideVoiceChatMember(config) {
  foreach (member in voiceChatMembers.value)
    if (member.name == config.name) {
      member.needShow(false)
      break
    }
}

::interop.updateVoiceChatStatus <- function(config) {
  if (config.isTalking)
    showVoiceChatMember(config)
  else
    hideVoiceChatMember(config)
}

return {
  voiceChatMembers = voiceChatMembers
  removeVoiceChatMember = removeVoiceChatMember
}
