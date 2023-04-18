module dm_events shared
require ecs
require DagorMath


[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventDamagePartRestored
  packedPartId : uint
  hp : float
