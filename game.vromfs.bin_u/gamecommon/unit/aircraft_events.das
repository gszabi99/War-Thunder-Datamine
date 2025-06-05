module aircraft_events shared
require ecs


[cpp_event(unicast, with_scheme)]
struct EventAicraftCrash
  crashType : uint8
  exploded : bool
  lPos : float3
  lNorm : float3

[cpp_event(unicast, with_scheme)]
struct EventAicraftGearPartsCut
  mask : uint16

[cpp_event(unicast, with_scheme)]
struct EventAicraftCollisionObjectsCut
  mask : uint64
