from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let u = require("%sqStdLibs/helpers/u.nut")
let { setTimeout } = require("dagor.workcycle")
let { get_time_msec } = require("dagor.time")
let { frnd } = require("dagor.random")
let { register_command } = require("console")
let { myClanInfo } = require("%scripts/clans/clanState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

local isChatOn = false
local avgEventPerSec = 10
local lastStepTime = 0

function imitateUserSpeaking(uid, isSpeaking) {
  broadcastEvent("ChatCallback", { event = GCHAT_EVENT_VOICE, taskId = null, db = { uid = uid, type = "update", is_speaking = isSpeaking } })
}

function immitateVoiceChat() {
  let curStepTime = get_time_msec()
  let dt = curStepTime - lastStepTime
  lastStepTime = curStepTime

  if (frnd() * 1000 > dt * avgEventPerSec)
    return

  let members = g_squad_manager.isInSquad() ? g_squad_manager.getOnlineMembers()
    : myClanInfo.get()?.members ?? []

  if (members.len() <= 1)
    return

  imitateUserSpeaking(u.chooseRandom(members).uid, u.chooseRandom([true, false]))
}

function stop() {
  foreach (uid, _member in g_squad_manager.getMembers())
    imitateUserSpeaking(uid, false)

  foreach (member in myClanInfo.get()?.members ?? [])
    imitateUserSpeaking(member.uid, false)

  isChatOn = false
}

function runVoiceChatStep() {
  if (!g_squad_manager.isInSquad() && !myClanInfo.get())
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

function start(newAvgEventPerSec = 10) {
  isChatOn = !isChatOn
  avgEventPerSec = newAvgEventPerSec
  runVoiceChatStep()
}

register_command(start, "debug.voice_chat.start")
register_command(stop, "debug.voice_chat.stop")
