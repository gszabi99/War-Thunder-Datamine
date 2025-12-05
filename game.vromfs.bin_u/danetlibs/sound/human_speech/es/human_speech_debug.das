options no_aot
require ecs
require DagorConsole
require soundSystem
require human_net_speech.modules.human_net_speech_events


[console_cmd(name="snd.human_speech")]
def human_speech_debug_console_cmd(phrase : string)
  find_query() <| $ [es(REQUIRE=hero)] (eid : EntityId; human_speech__locale : string; human_speech__voices : Array)
    sendEvent(eid, CmdClientHumanSpeech(phrase = phrase))
    sound_debug("locale={human_speech__locale};  voices={human_speech__voices}")
    return true





