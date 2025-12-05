
require ecs
require soundEvent
require soundSystem
require DagorSystem
require %game.events
require DagorConsole
require DagorRandom
require WTDamageModel

[es(tag=sound, track=isAlive, REQUIRE=trenchBot)]
def human_sound_on_death(evt : Event;
                         isAlive : bool;
                         transform : float3x4;
                         var human_sound__attackEvent : SoundEvent&;
                         human_sound__deathEventPath : string)
  if !isAlive
    oneshot(human_sound__deathEventPath, transform[3])
    abandon(human_sound__attackEvent)


[es(tag=sound, track=mainOffender, REQUIRE=trenchBot)]
def human_sound_on_kill(evt : Event;
                        mainOffender : OffenderData)
  if mainOffender.eid != INVALID_ENTITY_ID
    query(mainOffender.eid) <| $ [es] (human_sound__killEventPath : string;
                                       transform : float3x4;
                                       isAlive : bool)
      if isAlive && !empty(human_sound__killEventPath)
        oneshot(human_sound__killEventPath, transform[3])


[es(tag=sound, no_order, REQUIRE=trenchBot)]
def trench_bot_sound_update_es(info : ParallelUpdateFrameDelayed;
                               transform : float3x4;
                               isAlive : bool;
                               trench_bot__generalState : int;
                               human_sound__attackEventPath : string;
                               var human_sound__attackCurTime : float&;
                               var human_sound__attackEvent : SoundEvent&;
                               human_sound__attackTime : float)
  if trench_bot__generalState == 1 && human_sound__attackEventPath != "" && isAlive
    if human_sound__attackCurTime < 0. && !is_playing(human_sound__attackEvent)
      human_sound__attackCurTime = human_sound__attackTime * rnd_float(0., 1.0)
      human_sound__attackEvent |> play(human_sound__attackEventPath, transform[3])
    else
      human_sound__attackCurTime -= info.dt
      set_pos(human_sound__attackEvent, transform[3])
  if !is_playing(human_sound__attackEvent)
    abandon(human_sound__attackEvent)


[es(tag=sound, track=trench_bot__generalState)]
def human_sound_on_start_attack(evt : Event;
                                transform : float3x4;
                                trench_bot__generalState : int;
                                human_sound__startAttackEventPath : string)
  let START_SOUND_PROBABILITY = 0.1
  if trench_bot__generalState == 1 && rnd_float(0., 1.0) < START_SOUND_PROBABILITY
    oneshot(human_sound__startAttackEventPath, transform[3])