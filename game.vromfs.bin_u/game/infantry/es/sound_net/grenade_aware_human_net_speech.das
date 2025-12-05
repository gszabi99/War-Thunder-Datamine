require ecs
require human_net_speech.modules.human_net_speech_request_common
require human_net_speech.modules.human_net_speech_events
require strings


[es(tag=server, REQUIRE_NOT=deadEntity, REQUIRE=human_speech__speeches)]
def grenade_aware_human_net_speech(evt : CmdRequestHumanSpeechAbout;
                                   eid : EntityId)

  if evt.phrase != "grenadeAware"
    return

  query(evt.aboutEid) <| $ [es(REQUIRE=phys_vars)] (grenade_aware_phrase : string = "")
    let phrase = !empty(grenade_aware_phrase) ? grenade_aware_phrase : evt.phrase
    request_net_speech(eid, phrase)
