require ecs
require AnimV20
require soundEvent
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sound_geomtree_nodes_common
require %appGame.wt_events


def human_death_sound(evt : EventEntityDied;
                      @shared_comp human_voice_sound__path : Object;
                      @shared_comp human_voice_sound__descs : Object;
                      var human_death_sound__event : SoundEvent&;
                      human_speech__locale = "";
                      is_watched_sound : bool = false;
                      human_sound_geomtree_nodes__headNodeId = -1;
                      animchar : AnimcharBaseComponent const? = null;
                      human_weap__currentGunEid :  EntityId;
                      human_suicide_sound__path : string;
                      transform : float3x4;
                      sound_tags : Object;
                      sound_preset__isLoaded : bool;
                      human_sound__prefix : string = "")

  release(human_death_sound__event)

  if sound_preset__isLoaded

    let voicePos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
    human_death_sound__event |> reset(play_voice("death", human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, voicePos, human_speech__locale, false))
    human_death_sound__event.abandonOnReset = true

    query(human_weap__currentGunEid) <| $ [es] (gun_sound__event : SoundEvent)
      if (is_playing(gun_sound__event))
        set_var_optional(gun_sound__event, "on_shot", 0.)

    if evt.offender == evt.victim
      let playerStr = is_watched_sound ? "player/" : "enemy/"
      oneshot("{human_sound__prefix}{playerStr}{human_suicide_sound__path}", voicePos)

[es(tag=sound, on_event=ParallelUpdateFrameDelayed, REQUIRE=deadEntity, REQUIRE_NOT=shootingRangeDummy)]
def human_death_sound_update(evt : Event;
                             var human_death_sound__event : SoundEvent&;
                             is_watched_sound : bool = false;
                             human_sound_geomtree_nodes__headNodeId = -1;
                             animchar : AnimcharBaseComponent const? = null;
                             transform : float3x4)
  if is_valid_handle_value(human_death_sound__event)
    if is_playing(human_death_sound__event)
      let voicePos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
      set_pos(human_death_sound__event, voicePos)
    else
      release(human_death_sound__event)
