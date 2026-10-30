require ecs
require DagorMath
require gameLibs.pufd_events.pufd_events





[es(tag=sound, after=(sound_begin_update_es, sound_control_update, vehicle_sound_speed_update), before=(vehicle_collision_sound, vehicle_tracks_sound, ground_vehicle_suspension_sound, sound_end_update_es), REQUIRE=vehicleSoundPhysState)]
def vehicle_sound_phys_state_update_es(evt : ParallelUpdateFrameDelayed;
                                       vehicle_sound_phys_state__deltaShock : float;
                                       vehicle_sound_phys__noiseDeltaShockThreshold : float;
                                       vehicle_sound_speed_state__speed : float;
                                       vehicle_sound_phys__noiseSpeedThreshold : float;
                                       var vehicle_sound_phys__noiseReductionTimer : float&;
                                       vehicle_sound_phys__noiseReductionDecayPeriod : float;
                                       var vehicle_sound_phys_state__noiseReduction : float&)
  let loud = vehicle_sound_phys_state__deltaShock >= vehicle_sound_phys__noiseDeltaShockThreshold || vehicle_sound_speed_state__speed >= vehicle_sound_phys__noiseSpeedThreshold
  vehicle_sound_phys__noiseReductionTimer = loud ? 0. : min(vehicle_sound_phys__noiseReductionTimer + evt.dt, vehicle_sound_phys__noiseReductionDecayPeriod)
  vehicle_sound_phys_state__noiseReduction = 1. - safediv(vehicle_sound_phys__noiseReductionTimer, vehicle_sound_phys__noiseReductionDecayPeriod)
