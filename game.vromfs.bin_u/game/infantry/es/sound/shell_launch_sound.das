require ecs
require %game.events
require soundEvent
require net

def play_launch_sound(prefix, name : string;
                      pos : float3;
                      has_grains : bool;
                      var event : SoundEvent&;
                      var ttl : float&;
                      abandon_on_reset : bool)
  if has_grains
    event |> play("{prefix}/{name}/shot_grains", pos)
    set_var_optional(event, "on_shot", 1.)
    ttl = 2.
    event.abandonOnReset = abandon_on_reset
  else
    oneshot("{prefix}/{name}/shot_single", pos)


[es(tag=sound, on_appear, REQUIRE_NOT=clientSide)]
def shell_launch_sound(evt : Event;
                       shell_launch_sound__name : string;
                       var shell_launch_sound__event : SoundEvent&;
                       var shell_launch_sound__ttl : float&;
                       var shell_launch_sound__hasGrains : bool&;
                       shell__owner : EntityId;
                       transform : float3x4)
  shell_launch_sound__hasGrains = has("infantry/player/{shell_launch_sound__name}/shot_grains", "")

  query(shell__owner) <| $ [es] (is_watched_sound : bool)
    if is_watched_sound && !is_server()
      return
    let prefix = is_watched_sound ? "infantry/player" : "infantry/enemy"
    play_launch_sound(prefix, shell_launch_sound__name, transform[3],
                      shell_launch_sound__hasGrains, shell_launch_sound__event,
                      shell_launch_sound__ttl, false)


[es(tag=sound, on_appear, REQUIRE=clientSide)]
def shell_launch_sound_client_side(evt : Event;
                                   shell_launch_sound__name : string;
                                   var shell_launch_sound__event : SoundEvent&;
                                   var shell_launch_sound__ttl : float&;
                                   var shell_launch_sound__hasGrains : bool&;
                                   shell__owner : EntityId;
                                   transform : float3x4)
  shell_launch_sound__hasGrains = has("infantry/player/{shell_launch_sound__name}/shot_grains", "")

  query(shell__owner) <| $ [es(REQUIRE=watchedByPlr)] ()
    play_launch_sound("infantry/player", shell_launch_sound__name, transform[3],
                      shell_launch_sound__hasGrains, shell_launch_sound__event,
                      shell_launch_sound__ttl, true)


[es(tag=sound)]
def shell_launch_sound_update(info : ParallelUpdateFrameDelayed;
                              var shell_launch_sound__ttl : float&;
                              var shell_launch_sound__event : SoundEvent&)
  shell_launch_sound__ttl -= info.dt
  if shell_launch_sound__ttl < 0.
    shell_launch_sound__event |> abandon()