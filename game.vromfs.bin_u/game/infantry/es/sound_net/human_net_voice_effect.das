require ecs
require app
require net
require human_sounds_net.modules.human_sounds_net_events
require %game.utils.net_utils


[es(tag=server)]
def human_net_voice_effect_request(evt : CmdRequestHumanVoiceEffect;
                                   eid : EntityId;
                                   var human_net_voice_effect__nextTime : float&;
                                   human_net_voice_effect__cooldown : float;
                                   human_net_voice_effect__range : float;
                                   isAlive = true)
  if isAlive && get_sync_time() >= human_net_voice_effect__nextTime
    human_net_voice_effect__nextTime = get_sync_time() + human_net_voice_effect__cooldown
    send_net_event(eid, CmdNetHumanVoiceEffect(phrase = evt.phrase, time = get_sync_time()), enum_connections_near_entity(eid, human_net_voice_effect__range))
