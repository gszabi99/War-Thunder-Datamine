require ecs
require DagorMath
require math.base
require math.ang
require Dacoll
require PhysMat
require vehicle
require vehicleSoundProps
require danetlibs.renderer.includes.pufd_events
require vehicle_sounds.modules.vehicle_sounds_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(vehicle_phys_es, sound_control_update, sound_begin_update_es), before=(vehicle_engine_sound_update, sound_end_update_es))]
def ground_vehicle_engine_sound_update_state(evt : Event;
                                             eid : EntityId;
                                             vehicle_net_phys : VehiclePhysActor;
                                             vehicle__fuel : float = 0.0;
                                             vehicle__fuelUse : float = 0.0;
                                             isAlive : bool = true;
                                             var vehicle_engine_sound_state__rpm : float&;
                                             var vehicle_engine_sound_state__load : float&;
                                             var vehicle_engine_sound_state__isStarted : bool&;
                                             var vehicle_engine_sound_state__isInited : bool&)
  assume phys = vehicle_net_phys.phys
  let isOnGround = phys.currentState.leftTrack.isOnGround || phys.currentState.rightTrack.isOnGround
  let noFuel = (vehicle__fuelUse > 0.0 && vehicle__fuel <= 0.0)
  vehicle_engine_sound_state__rpm = phys.isAsleep ? 0. : cvt(phys.engineRPM, phys.engineMinRPM, phys.engineMaxRPM, 0., 100.)
  vehicle_engine_sound_state__load = isOnGround ? abs(phys.engineLoad) : 0.
  let isStarted = isAlive && phys.engineReadyness > 0. && phys.isICEWorking && !noFuel
  set_vehicle_engine_started(isStarted, eid, vehicle_engine_sound_state__isStarted, vehicle_engine_sound_state__isInited)


[es(tag=sound, after=(vehicle_phys_es, sound_control_update, sound_begin_update_es), before=(vehicle_collision_sound, sound_end_update_es))]
def ground_vehicle_sound_update_state(info : ParallelUpdateFrameDelayed;
                                      vehicle_net_phys : VehiclePhysActor;
                                      var vehicle_sound_phys_state__isOnGround : bool&;
                                      var vehicle_tracks_sound_state__slip : float&;
                                      vehicle_sound_speed_state__speed : float;
                                      var vehicle_sound_phys__prevSoundShockSummary : float&;
                                      var vehicle_sound_phys_state__deltaShock : float&;
                                      vehicle_sound_phys__noiseReductionDecayPeriod : float;
                                      vehicle_sound_phys__noiseDeltaShockThreshold : float;
                                      vehicle_sound_phys__noiseSpeedThreshold : float;
                                      var vehicle_sound_phys__noiseReductionTimer : float&;
                                      var vehicle_sound_phys_state__noiseReduction : float&;
                                      transform : float3x4)

  assume phys = vehicle_net_phys.phys
  assume currentState = phys.currentState
  vehicle_sound_phys_state__isOnGround = currentState.leftTrack.isOnGround || currentState.rightTrack.isOnGround
  vehicle_tracks_sound_state__slip = 0.

  vehicle_sound_phys_state__deltaShock = vehicle_sound_phys__prevSoundShockSummary >= 0. && currentState.soundShockSummary > vehicle_sound_phys__prevSoundShockSummary ? currentState.soundShockSummary - vehicle_sound_phys__prevSoundShockSummary : 0.
  vehicle_sound_phys__prevSoundShockSummary = currentState.soundShockSummary

  let loud = vehicle_sound_phys_state__deltaShock >= vehicle_sound_phys__noiseDeltaShockThreshold || vehicle_sound_speed_state__speed >= vehicle_sound_phys__noiseSpeedThreshold
  vehicle_sound_phys__noiseReductionTimer = loud ? 0. : min(vehicle_sound_phys__noiseReductionTimer + info.dt, vehicle_sound_phys__noiseReductionDecayPeriod)
  vehicle_sound_phys_state__noiseReduction = 1. - safediv(vehicle_sound_phys__noiseReductionTimer, vehicle_sound_phys__noiseReductionDecayPeriod)

  let speed = dot(float3(currentState.velocity), transform[0])
  if currentState.leftTrack.isOnGround
    let wheelSpeed = phys.currentState.leftTrack.speed * (1. - saturate(abs(currentState.leftSteeringBrake)))
    vehicle_tracks_sound_state__slip += abs(wheelSpeed - speed) * 0.5
  if currentState.rightTrack.isOnGround
    let wheelSpeed = phys.currentState.rightTrack.speed * (1. - saturate(abs(currentState.rightSteeringBrake)))
    vehicle_tracks_sound_state__slip += abs(wheelSpeed - speed) * 0.5


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=(vehicle_tracks_sound, sound_end_update_es))]
def ground_vehicle_sound_update_tracks(evt : Event;
                                       vehicle_net_phys : VehiclePhysActor;
                                       var vehicle_tracks_sound_state__concrete : float&;
                                       var vehicle_tracks_sound_state__water : float&;
                                       var vehicle_sound_update_surface__wheelIdx : int&;
                                       var vehicle_sound_update_surface__waterSurfaceMax : float&;
                                       var vehicle_sound_update_surface__concreteSurfaceMax : float&;
                                       isAlive : bool;
                                       transform : float3x4)
  if !isAlive || int(vehicle_net_phys.phys.currentState.wheelCount) <= 0 || vehicle_sound_update_surface__wheelIdx >= int(vehicle_net_phys.phys.currentState.wheelCount)
    vehicle_tracks_sound_state__concrete = 0.
    vehicle_tracks_sound_state__water = 0.
    vehicle_sound_update_surface__concreteSurfaceMax = 0.
    vehicle_sound_update_surface__waterSurfaceMax = 0.
    vehicle_sound_update_surface__wheelIdx = 0
  else
    let wheel = vehicle_phys_get_wheel(vehicle_net_phys.phys, vehicle_sound_update_surface__wheelIdx)
    if wheel != null
      let wpos = transform * float3((*wheel).pos)

      var waterLevel = 0.
      if traceht_water(wpos, waterLevel)
        vehicle_sound_update_surface__waterSurfaceMax = max(vehicle_sound_update_surface__waterSurfaceMax, waterLevel - wpos.y)

      if (*wheel).lastMatId != PHYSMAT_INVALID
        vehicle_physmat_sound_get_props((*wheel).lastMatId) <| $(props : SoundVehiclePhysMatProps)
          vehicle_sound_update_surface__concreteSurfaceMax = max(vehicle_sound_update_surface__concreteSurfaceMax, props.concrete)

      vehicle_sound_update_surface__wheelIdx += max(1, int(vehicle_net_phys.phys.currentState.wheelCount) / 32)
      if vehicle_sound_update_surface__wheelIdx >= int(vehicle_net_phys.phys.currentState.wheelCount)
        vehicle_sound_update_surface__wheelIdx = 0
        vehicle_tracks_sound_state__concrete = vehicle_sound_update_surface__concreteSurfaceMax
        vehicle_tracks_sound_state__water = vehicle_sound_update_surface__waterSurfaceMax
        vehicle_sound_update_surface__concreteSurfaceMax = 0.
        vehicle_sound_update_surface__waterSurfaceMax = 0.
