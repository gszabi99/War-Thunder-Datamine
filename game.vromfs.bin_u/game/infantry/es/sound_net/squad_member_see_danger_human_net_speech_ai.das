require ecs
require %appGame.infantry.es.sound_net.squad_member_see_danger_human_net_speech_common
require danetlibs.renderer.includes.pufd_events
require walkerai


[es(no_order, tag=server)]
def squad_member_see_danger_human_net_speech_ai__lookup_dangers(evt : ParallelUpdateFrameDelayed;
                                                                eid aka agent_eid : EntityId;
                                                                agent_dangers : AgentDangers;
                                                                squad_member_see_danger_human_net_speech_ai__traceableDangerThreshold : float;
                                                                squad_member_see_danger_human_net_speech_ai__lookupInterval : float;
                                                                var squad_member_see_danger_human_net_speech_ai__nextLookupAfter : float&)

  if evt.curTime >= squad_member_see_danger_human_net_speech_ai__nextLookupAfter
    squad_member_see_danger_human_net_speech_ai__nextLookupAfter = evt.curTime + squad_member_see_danger_human_net_speech_ai__lookupInterval

    for danger in agent_dangers.dangers
      if danger.traceable && danger.dangerMeter >= squad_member_see_danger_human_net_speech_ai__traceableDangerThreshold
        query(danger.eid) <| $ [es(REQUIRE=ai_target)] (ai_target : Target const?; transform : float3x4)
          if ai_target != null
            on_squad_member_see_danger_human_net_speech(agent_eid, danger.eid, transform[3]) 
