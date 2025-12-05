require ecs
require DagorMath
require soundEvent
require soundHash
require sound_utils.modules.sound_player_common
require vehicle_sounds.modules.vehicle_sounds_events


[es(tag=sound, on_appear, track=(is_watched_sound, vehicle_engine_sound_state__isStarted))]
def vehicle_engine_sound_toggle(evt : Event;
                                is_watched_sound : bool;
                                vehicle_engine_sound_state__isStarted : bool;
                                var vehicle_engine_sound__event : SoundEvent&;
                                @shared_comp vehicle_engine_sound__path : Object;
                                sound_tags : Object;
                                transform : float3x4)
  assume event = vehicle_engine_sound__event
  abandon(event)
  event.enabled = vehicle_engine_sound_state__isStarted
  if event.enabled
    event |> reset(sound_player_common::play_path(vehicle_engine_sound__path, sound_tags, is_watched_sound, transform[3], false))


[es(tag=sound)]
def vehicle_engine_sound_startstop_oneshot(evt : EventVehicleEngineSoundStarted;
                                           is_watched_sound : bool;
                                           @shared_comp vehicle_engine_sound__startPath : Object;
                                           @shared_comp vehicle_engine_sound__stopPath : Object;
                                           var sound_event_group : SoundEventGroup&;
                                           sound_tags : Object;
                                           transform : float3x4)
  if evt.started
    sound_player_common::play_path(vehicle_engine_sound__startPath, sound_tags, is_watched_sound, transform[3], sound_hash("startstop"), sound_event_group)
  else
    sound_player_common::play_path(vehicle_engine_sound__stopPath, sound_tags, is_watched_sound, transform[3], sound_hash("startstop"), sound_event_group)

[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def vehicle_engine_sound_update(evt : Event;
                                vehicle_sound_speed_state__speed : float;
                                vehicle_engine_sound__speedToVar : float2;
                                vehicle_engine_sound_state__rpm : float;
                                vehicle_engine_sound_state__load : float;
                                vehicle_engine_sound__event : SoundEvent;
                                vehicle_engine_sound__rpmMul : float;
                                transform : float3x4)
  assume event = vehicle_engine_sound__event
  if event.enabled
    let rpm = vehicle_engine_sound_state__rpm + (100. - vehicle_engine_sound_state__rpm) * vehicle_engine_sound_state__load * vehicle_engine_sound__rpmMul
    set_var(event, "rpm", rpm)
    set_var_optional(event, "speed", cvt(vehicle_sound_speed_state__speed, vehicle_engine_sound__speedToVar.x, vehicle_engine_sound__speedToVar.y, 0., 100.))
    set_var(event, "load", vehicle_engine_sound_state__load)
    set_pos(event, transform[3])
