module unit_proximity_damage_events shared
require ecs
require dm
require BitStream

[cpp_event(unicast, with_scheme)]
struct EventOnPartDamagedByProximityExplosion
  pos : float3
  partId : uint

[cpp_event(unicast, with_scheme)]
struct CmdCreateProximityVisialDamage
  explosionPos : float3
  projectilePropsId : uint

[event(unicast, version=0, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventProximityVisualDamageNetSync
  explosionPos : float3
  projectilePropsId : uint
  bs : BitStream const?
