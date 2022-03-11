::g_voice_chat <- {
  isChatOn = false
  avgEventPerSec = 10
  lastStepTime = 0
}

g_voice_chat.start <- function start(newAvgEventPerSec = 10)
{
  isChatOn = !isChatOn
  avgEventPerSec = newAvgEventPerSec

  runVoiceChatStep()
}

g_voice_chat.stop <- function stop()
{
  foreach (uid, member in ::g_squad_manager.getMembers())
    imitateUserSpeaking(uid, false)

  foreach (member in ::my_clan_info?.members ?? [])
    imitateUserSpeaking(member.uid, false)

  isChatOn = false
}

g_voice_chat.runVoiceChatStep <- function runVoiceChatStep()
{
  if (!::g_squad_manager.isInSquad() && !::my_clan_info)
    return stop()

  if (!isChatOn)
    return stop()

  ::handlersManager.doDelayed(function() {
    if (!isChatOn)
      return

    immitateVoiceChat()
    runVoiceChatStep()
  }.bindenv(this))
}

g_voice_chat.immitateVoiceChat <- function immitateVoiceChat()
{
  local curStepTime = ::dagor.getCurTime()
  local dt = curStepTime - lastStepTime
  lastStepTime = curStepTime

  if (::math.frnd() * 1000 > dt * avgEventPerSec)
    return

  local members = ::g_squad_manager.isInSquad() ? ::g_squad_manager.getOnlineMembers()
    : ::my_clan_info ? ::my_clan_info.members
    : []
  if (members.len() <= 1)
    return

  imitateUserSpeaking(::u.chooseRandom(members).uid, ::u.chooseRandom([true, false]))
}

g_voice_chat.imitateUserSpeaking <- function imitateUserSpeaking(uid, isSpeaking)
{
  menuChatCb(::GCHAT_EVENT_VOICE, null, { uid = uid, type = "update", is_speaking = isSpeaking })
}
