require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require %appGame.wt_events


[es(tag=sound, REQUIRE_NOT=shootingRangeDummy)]
def human_death_sound(evt : EventEntityDied;
                      @shared_comp human_voice_sound__path : Object;
                      @shared_comp human_voice_sound__descs : Object;
                      var human_death_sound__event : SoundEvent&;
                      human_suicide_sound__path : string;
                      transform : float3x4;
                      sound_tags : Object;
                      sound_preset__isLoaded : bool;
                      is_watched_sound : bool = false)

  release(human_death_sound__event)

  if sound_preset__isLoaded

    human_death_sound__event |> reset(play("death", human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, transform[3], false))
    human_death_sound__event.abandonOnReset = true

    if evt.offender == evt.victim
      oneshot(human_suicide_sound__path, transform[3])

[es(tag=sound, on_event=ParallelUpdateFrameDelayed, REQUIRE=deadEntity, REQUIRE_NOT=shootingRangeDummy)]
def human_death_sound_update(evt : Event;
                             var human_death_sound__event : SoundEvent&;
                             transform : float3x4)
  if is_valid_handle_value(human_death_sound__event)
    if is_playing(human_death_sound__event)
      set_pos(human_death_sound__event, transform[3])
    else
      release(human_death_sound__event)
