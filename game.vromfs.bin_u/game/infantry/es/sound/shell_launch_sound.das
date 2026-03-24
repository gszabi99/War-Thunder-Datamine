require ecs
require %game.events
require soundEvent

[es(tag=sound, on_appear, REQUIRE_NOT=clientSide)]
def shell_launch_sound(evt : Event;
                       shell_launch_sound__name : string;
                       var shell_launch_sound__event : SoundEvent&;
                       var shell_launch_sound__ttl : float&;
                       var shell_launch_sound__hasGrains : bool&;
                       shell__owner : EntityId;
                       transform : float3x4)
  let path = "infantry/player/{shell_launch_sound__name}/shot_grains"
  shell_launch_sound__hasGrains = has(path, "")

  query(shell__owner) <| $ [es] (is_watched_sound : bool)
    if shell_launch_sound__hasGrains
      shell_launch_sound__event |> play(is_watched_sound ? "infantry/player/{shell_launch_sound__name}/shot_grains" : "infantry/enemy/{shell_launch_sound__name}/shot_grains", transform[3])
      set_var_optional(shell_launch_sound__event, "on_shot", 1.)
      shell_launch_sound__ttl = 2.
    else
      oneshot(is_watched_sound ? "infantry/player/{shell_launch_sound__name}/shot_single" : "infantry/enemy/{shell_launch_sound__name}/shot_single", transform[3])




[es(tag=sound)]
def shell_launch_sound_update(info : ParallelUpdateFrameDelayed;
                              var shell_launch_sound__ttl : float&;
                              var shell_launch_sound__event : SoundEvent&)
  shell_launch_sound__ttl -= info.dt
  if shell_launch_sound__ttl < 0.
    shell_launch_sound__event |> abandon()