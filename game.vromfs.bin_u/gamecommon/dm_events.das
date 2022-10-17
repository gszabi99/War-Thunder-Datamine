module dm_events shared
require ecs

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventDamagePartRestored
  partId : int
  hp : float
