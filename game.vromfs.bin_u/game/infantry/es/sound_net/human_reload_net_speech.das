require ecs
require human_net_speech.modules.human_net_speech_request_common


[es(tag=server, on_event=EventHumanStartedReload, REQUIRE=human_speech__speeches)]
def human_net_speech_reload(evt : Event; eid : EntityId; human_weap__currentGunEid : EntityId)
  if !has(human_weap__currentGunEid, "disableReloadSpeech")
    request_net_speech(eid, "reload")
