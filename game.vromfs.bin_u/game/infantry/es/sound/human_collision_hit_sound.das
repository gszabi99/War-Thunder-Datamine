require ecs
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common
require DngHuman
require DagorMath
require math.base
require %game.events
require HumanPhys


[es(tag=sound, REQUIRE=watchedByPlr)]
def human_collision_hit_sound(evt : CmdPostPhysUpdate;
                              human_net_phys : HumanActor;
                              human_net_phys__isClimbing : bool;
                              sound_preset__isLoaded : bool;
                              var human_collision_hit_sound__forceMax : float&;
                              human_collision_hit_sound__spdSummaryToForce : float4;
                              human_collision_hit_sound__vertSpeedThreshold : float;
                              sound_tags : Object;
                              var sound_event_group : SoundEventGroup&;
                              @shared_comp human_collision_hit_sound__path : Object;
                              is_watched_sound : bool;
                              transform : float3x4;
                              human_sound__prefix : string = "infantry/")
  if !evt.isForReal || !sound_preset__isLoaded
    return
  assume currentState = human_net_phys.phys.currentState
  if !human_net_phys__isClimbing && !currentState.isAttachedToLadder
    assume spdToForce = human_collision_hit_sound__spdSummaryToForce
    if (length_sq(currentState.spdSummaryDiff) > square(spdToForce.x) && abs(normalize(currentState.spdSummaryDiff).y) < human_collision_hit_sound__vertSpeedThreshold)
      let force = cvt(length(currentState.spdSummaryDiff), spdToForce.x, spdToForce.y, spdToForce.z, spdToForce.w)
      var handle = get_sound(sound_event_group, sound_hash("collision"))
      if !is_playing(handle)
        reject_sound(sound_event_group, sound_hash("collision"))
        handle = sound_player_common::play_path(human_collision_hit_sound__path, sound_tags, is_watched_sound, transform[3], sound_hash("collision"), sound_event_group, 0.f, human_sound__prefix)
        if read_sound_tag("armored", sound_tags)
          set_var_optional(handle, "armored", 1.)
        human_collision_hit_sound__forceMax = force
      human_collision_hit_sound__forceMax = max(human_collision_hit_sound__forceMax, force)
      set_var_optional(handle, "force", human_collision_hit_sound__forceMax)
