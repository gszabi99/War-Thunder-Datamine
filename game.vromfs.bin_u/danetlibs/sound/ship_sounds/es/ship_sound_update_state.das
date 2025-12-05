require ecs
require DagorMath
require math.base
require DngShip
require Dacoll
require CollRes
require danetlibs.renderer.includes.pufd_events
require vehicle_sounds.modules.vehicle_sounds_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(vehicle_phys_es, sound_control_update, sound_begin_update_es), before=sound_end_update_es)]
def ship_engine_sound_update_state(evt : Event;
                                   eid : EntityId;
                                   isAlive : bool;
                                   ship_net_phys : ShipActor;
                                   var vehicle_engine_sound_state__rpm : float&;
                                   var vehicle_engine_sound_state__load : float&;
                                   var vehicle_engine_sound_state__isStarted : bool&;
                                   var vehicle_engine_sound_state__isInited : bool&;
                                   ship_engine_sound_seat_start_stop : bool const?)
  vehicle_engine_sound_state__rpm = cvt(abs(ship_net_phys.phys.engineRPM), ship_net_phys.phys.engineRPMRange.x, ship_net_phys.phys.engineRPMRange.y, 0., 100.)
  vehicle_engine_sound_state__load = max(abs(ship_net_phys.phys.currentState.leftThrottle), abs(ship_net_phys.phys.currentState.rightThrottle))
  let isStarted = (ship_engine_sound_seat_start_stop != null && isAlive) ? (*ship_engine_sound_seat_start_stop) : (isAlive && ship_net_phys.phys.engineRPM != 0.)
  set_vehicle_engine_started(isStarted, eid, vehicle_engine_sound_state__isStarted, vehicle_engine_sound_state__isInited)


[es(tag=sound, on_appear, track=seat__ownerEid, REQUIRE=seats__isDriver)]
def ship_engine_sound_seat_start_stop(evt : Event; seat__vehicleEid, seat__ownerEid : EntityId)
  query(seat__vehicleEid) <| $ [es] (var ship_engine_sound_seat_start_stop : bool&)
    ship_engine_sound_seat_start_stop = seat__ownerEid != INVALID_ENTITY_ID


[es(tag=sound, after=(vehicle_phys_es, sound_control_update, sound_begin_update_es), before=(vehicle_tracks_sound, vehicle_collision_sound, sound_end_update_es))]
def ship_sound_update_state(info : ParallelUpdateFrameDelayed;
                            ship_net_phys : ShipActor;
                            var vehicle_tracks_sound_state__slip : float&;
                            vehicle_sound_speed_state__speed : float;
                            var vehicle_sound_phys__prevSoundShockSummary : float&;
                            var vehicle_sound_phys_state__deltaShock : float&;
                            vehicle_sound_phys__noiseReductionDecayPeriod : float;
                            vehicle_sound_phys__noiseDeltaShockThreshold : float;
                            vehicle_sound_phys__noiseSpeedThreshold : float;
                            var vehicle_sound_phys__noiseReductionTimer : float&;
                            var vehicle_sound_phys_state__noiseReduction : float&;
                            var ship_sound_phys_vars__waterTimer : float&;
                            var vehicle_tracks_sound_state__water : float&;
                            transform : float3x4)

  vehicle_tracks_sound_state__slip = length(ship_net_phys.phys.currentState.omega)

  vehicle_sound_phys_state__deltaShock = vehicle_sound_phys__prevSoundShockSummary >= 0. && ship_net_phys.phys.soundShockImpulse > vehicle_sound_phys__prevSoundShockSummary ? ship_net_phys.phys.soundShockImpulse - vehicle_sound_phys__prevSoundShockSummary : 0.
  vehicle_sound_phys__prevSoundShockSummary = ship_net_phys.phys.soundShockImpulse
  let loud = vehicle_sound_phys_state__deltaShock >= vehicle_sound_phys__noiseDeltaShockThreshold || vehicle_sound_speed_state__speed >= vehicle_sound_phys__noiseSpeedThreshold
  vehicle_sound_phys__noiseReductionTimer = loud ? 0. : min(vehicle_sound_phys__noiseReductionTimer + info.dt, vehicle_sound_phys__noiseReductionDecayPeriod)
  vehicle_sound_phys_state__noiseReduction = 1. - safediv(vehicle_sound_phys__noiseReductionTimer, vehicle_sound_phys__noiseReductionDecayPeriod)

  ship_sound_phys_vars__waterTimer += info.dt
  if ship_sound_phys_vars__waterTimer * (1. + vehicle_sound_speed_state__speed) > 1.
    ship_sound_phys_vars__waterTimer = 0.
    vehicle_tracks_sound_state__water = 0.
    var water = 0.
    if traceht_water(transform[3], water)
      let posXZ = transform[3].xz
      vehicle_tracks_sound_state__water = max(0., water - traceht_lmesh(posXZ))
