//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { setTimeout } = require("dagor.workcycle")
let { get_time_msec } = require("dagor.time")
let { frnd } = require("dagor.random")
let { register_command } = require("console")

local isChatOn = false
local avgEventPerSec = 10
local lastStepTime = 0

let function imitateUserSpeaking(uid, isSpeaking) {
  ::menuChatCb(GCHAT_EVENT_VOICE, null, { uid = uid, type = "update", is_speaking = isSpeaking })
}

let function immitateVoiceChat() {
  let curStepTime = get_time_msec()
  let dt = curStepTime - lastStepTime
  lastStepTime = curStepTime

  if (frnd() * 1000 > dt * avgEventPerSec)
    return

  let members = ::g_squad_manager.isInSquad() ? ::g_squad_manager.getOnlineMembers()
    : ::my_clan_info ? ::my_clan_info.members
    : []
  if (members.len() <= 1)
    return

  imitateUserSpeaking(::u.chooseRandom(members).uid, ::u.chooseRandom([true, false]))
}

let function stop() {
  foreach (uid, _member in ::g_squad_manager.getMembers())
    imitateUserSpeaking(uid, false)

  foreach (member in ::my_clan_info?.members ?? [])
    imitateUserSpeaking(member.uid, false)

  isChatOn = false
}

let function runVoiceChatStep() {
  if (!::g_squad_manager.isInSquad() && !::my_clan_info)
    return stop()

  if (!isChatOn)
    return stop()

  let self = callee()
  setTimeout(0.1, function() {
    if (!isChatOn)
      return

    immitateVoiceChat()
    self()
  })
}

let function start(newAvgEventPerSec = 10) {
  isChatOn = !isChatOn
  avgEventPerSec = newAvgEventPerSec
  runVoiceChatStep()
}

register_command(start, "debug.voice_chat.start")
register_command(stop, "debug.voice_chat.stop")
