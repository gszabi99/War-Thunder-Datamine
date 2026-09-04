import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "dagor.workcycle" import setTimeout
from "dagor.time" import get_time_msec
from "dagor.random" import frnd
from "console" import register_command
from "%scripts/dagui_library.nut" import *
from "%globalScripts/gchatEventConsts.nut" import *

let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { myClanInfo } = require("%scripts/clans/clanState.nut")

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
