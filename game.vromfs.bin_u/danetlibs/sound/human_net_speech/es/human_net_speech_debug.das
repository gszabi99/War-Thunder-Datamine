options no_aot
require ecs
require human_net_speech.modules.human_net_speech_request_common
require DagorConsole





[console_cmd(name="snd.human_net_speech")]
def human_net_speech_debug_console_cmd(phrase : string; human_index_in_query : int)
  var idx = -1
  query() <| $ [es(REQUIRE=(isAlive, humanNetSpeech))] (eid : EntityId)
    if ++idx == human_index_in_query
      request_net_speech(eid, phrase)
