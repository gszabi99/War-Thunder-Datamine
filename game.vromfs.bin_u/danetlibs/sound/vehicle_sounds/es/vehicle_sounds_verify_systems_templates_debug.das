options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro
require vehicle
require CollRes
require soundEvent
require vehicle_sounds_net.modules.vehicle_sounds_net_events


[req_template] 
struct GroundVehiclePhysSoundState
  vehicle_net_phys : VehiclePhysActor
  vehicle_sound_phys__noiseReductionDecayPeriod : float
  vehicle_sound_phys__noiseDeltaShockThreshold : float
  vehicle_sound_phys__noiseSpeedThreshold : float
  collres : CollisionResource
  transform : float3x4
  isAlive : bool


[req_template] 
struct GroundVehicleBrakesSound
  vehicle_net_phys : VehiclePhysActor
  ground_vehicle_brakes_sound__brakesStart : float
  ground_vehicle_brakes_sound__speedFadeInOut : float2
  is_watched_sound : bool
  ground_vehicle_brakes_sound__path : SharedObject
  sound_tags : Object
  transform : float3x4


[req_template] 
struct GroundVehicleGearSound
  vehicle_net_phys : VehiclePhysActor
  ground_vehicle_gear_sound__path : SharedObject
  is_watched_sound : bool
  sound_tags : Object
  transform : float3x4


[req_template] 
struct VehicleTracksSound
  vehicle_tracks_sound__speedThreshold : float
  vehicle_tracks_sound__speedToTurnMul : float4
  is_watched_sound : bool
  vehicle_tracks_sound__path : SharedObject
  sound_tags : Object
  transform : float3x4


[req_template] 
struct GroundVehicleSuspensionSound
  vehicle_net_phys : VehiclePhysActor
  ground_vehicle_suspension_sound__hitToVar : float2
  ground_vehicle_suspension_sound__path : SharedObject
  sound_tags : Object
  transform : float3x4


[req_template] 
struct VehicleEngineSound
  vehicle_engine_sound__rpmMul : float
  vehicle_engine_sound__path : SharedObject
  vehicle_engine_sound__startPath : SharedObject
  vehicle_engine_sound__stopPath : SharedObject
  sound_tags : Object
  is_watched_sound : bool
  transform : float3x4


[req_template]
struct VehicleWithSeats
  vehicle_seats__seatEids : ecs::EidList


[es(on_event=VerifyEcsTemplates)]
def vehicle_sounds_verify_ecs_templates(evt : Event)
  
  req_template({
    "vehicle_horn_sound__note" => ecs_type_hash(type<int>),
    "vehicle_horn_sound__path" => ecs_type_hash(type<SharedObject>),
    "sound_tags" => ecs_type_hash(type<Object>),
    "is_watched_sound" => ecs_type_hash(type<bool>),
    "transform" => ecs_type_hash(type<float3x4>)
  })
