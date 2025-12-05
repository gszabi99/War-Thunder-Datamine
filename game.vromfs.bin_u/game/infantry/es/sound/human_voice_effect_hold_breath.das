require ecs
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sounds_events
require DngHuman


[es(tag=sound, on_appear, track=human_net_phys__isHoldBreath)]
def human_voice_effect_hold_breath(evt : Event;
                                   eid : EntityId;
                                   human_net_phys : HumanActor&;
                                   human_net_phys__isHoldBreath : bool;
                                   var human_voice_effect__activeEffects : Object&;
                                   @shared_comp human_voice_effect__allOrderedEffects : StringList)

  set_human_voice_effect("holdBreath", human_net_phys__isHoldBreath, human_voice_effect__activeEffects, human_voice_effect__allOrderedEffects)
  if !human_net_phys__isHoldBreath && human_net_phys.phys.currentState.breathShortness > 0.
    sendEvent(eid, CmdHumanVoiceEffect(phrase = "holdBreathEnd", varName = "noairtime", varValue = human_net_phys.phys.currentState.breathShortness))
