require ecs
require DagorMath
require soundEvent
require sound_utils.modules.sound_player_common
require danetlibs.renderer.includes.pufd_events


[es(tag=sound, track=is_watched_sound, REQUIRE=is_watched_sound)]
def vehicle_tracks_sound_reset(evt : Event;
                               var vehicle_tracks_sound__event : SoundEvent&;
                               var vehicle_tracks_sound__delay : float&)
  vehicle_tracks_sound__delay = 0.
  vehicle_tracks_sound__event.enabled = false
  abandon(vehicle_tracks_sound__event)


[es(tag=sound, on_appear, REQUIRE=deadEntity)]
def vehicle_tracks_sound_abandon(evt : Event;
                                 var vehicle_tracks_sound__event : SoundEvent&;
                                 var vehicle_tracks_sound__delay : float&)
  vehicle_tracks_sound__delay = 0.
  vehicle_tracks_sound__event.enabled = false
  abandon(vehicle_tracks_sound__event)


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE_NOT=deadEntity)]
def vehicle_tracks_sound(info : ParallelUpdateFrameDelayed;
                         var vehicle_tracks_sound__event : SoundEvent&;
                         var vehicle_tracks_sound__delay : float&;
                         vehicle_tracks_sound__speedThreshold : float;
                         vehicle_tracks_sound__speedMul : float;
                         vehicle_tracks_sound__speedToTurnMul : float4;
                         vehicle_tracks_sound__surfaceWaterToVar : float;
                         vehicle_tracks_sound__surfaceConcreteToVar : float;

                         vehicle_sound_speed_state__linearVelocity : float3;
                         vehicle_sound_phys_state__noiseReduction : float;
                         vehicle_tracks_sound_state__slip : float;
                         vehicle_tracks_sound_state__water : float;
                         vehicle_tracks_sound_state__concrete : float;

                         is_watched_sound : bool;
                         @shared_comp vehicle_tracks_sound__path : Object;
                         sound_tags : Object;
                         transform : float3x4)

  vehicle_tracks_sound__delay -= info.dt
  if vehicle_tracks_sound__delay <= 0.

    let forwardSpeed = abs(dot(vehicle_sound_speed_state__linearVelocity, transform[0]))
    let speed = forwardSpeed * vehicle_tracks_sound__speedMul * vehicle_sound_phys_state__noiseReduction
    if speed >= vehicle_tracks_sound__speedThreshold
      vehicle_tracks_sound__delay = 0.
      if !vehicle_tracks_sound__event.enabled
        vehicle_tracks_sound__event.enabled = true
        abandon(vehicle_tracks_sound__event)
        vehicle_tracks_sound__event |> reset(sound_player_common::play_path(vehicle_tracks_sound__path, sound_tags, is_watched_sound, transform[3], false))
    elif vehicle_tracks_sound__delay <= -3.
      vehicle_tracks_sound__delay = 1.
      if vehicle_tracks_sound__event.enabled
        vehicle_tracks_sound__event.enabled = false
        abandon(vehicle_tracks_sound__event)

    if vehicle_tracks_sound__event.enabled
      set_var(vehicle_tracks_sound__event, "speed", speed)
      let surfaceWater = vehicle_tracks_sound_state__water * vehicle_tracks_sound__surfaceWaterToVar
      let turn = vehicle_tracks_sound_state__slip * cvt(forwardSpeed * vehicle_tracks_sound__speedMul,
                                                vehicle_tracks_sound__speedToTurnMul.x, vehicle_tracks_sound__speedToTurnMul.y,
                                                vehicle_tracks_sound__speedToTurnMul.z, vehicle_tracks_sound__speedToTurnMul.w)
      set_var(vehicle_tracks_sound__event, "turn", saturate(1. - surfaceWater) * turn)
      set_var(vehicle_tracks_sound__event, "surface_water", surfaceWater)
      set_var(vehicle_tracks_sound__event, "surface_concrete", vehicle_tracks_sound_state__concrete * vehicle_tracks_sound__surfaceConcreteToVar)
      set_pos(vehicle_tracks_sound__event, transform[3])
