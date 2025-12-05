options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro
require DngShip


[req_template]
struct ShipSoundUpdateVarsES
  sound_control__state : int
  ship_net_phys : ShipActor
  vehicle_sound_phys__noiseReductionDecayPeriod : float
  vehicle_sound_phys__noiseDeltaShockThreshold : float
  vehicle_sound_phys__noiseSpeedThreshold : float
  ship_sound_phys_vars__waterTimer : float
  transform : float3x4
