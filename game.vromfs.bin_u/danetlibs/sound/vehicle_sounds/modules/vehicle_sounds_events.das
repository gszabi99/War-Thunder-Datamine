module vehicle_sounds_events shared
require ecs

[event(unicast)]
struct EventVehicleEngineSoundStarted
  started : bool
