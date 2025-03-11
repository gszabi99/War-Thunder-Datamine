module repair_system_events shared
require ecs



[cpp_event(unicast, with_scheme)]
struct EventRepairSystemRequestRepair
  repair : bool

[cpp_event(unicast, with_scheme)]
struct EventRepairSystemSendRequestingRepair
  isButtonDown : bool
  forceSpendToolkit : bool

[cpp_event(unicast, with_scheme)]
struct EventRepairSystemStartBotRepairTimer
{}

[cpp_event(unicast, with_scheme)]
struct EventRepairSystemAllowPartRepair
  packedPartId : uint
  allow : bool

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventRepairSystemNetSync
  toolkitCount : int
  delayToRepair : float
  remainingRepiarTime : float
  repairWithoutModsOnly : bool

[cpp_event(unicast, with_scheme)]
struct EventRepairSystemStopRepair
{}

[cpp_event(unicast, with_scheme)]
struct EventRepairSystemSpendToolkit
{}



[cpp_event(unicast, with_scheme)]
struct EventRepairSystemOnRequestedRepair
{}

[cpp_event(unicast, with_scheme)]
struct EventRepairSystemOnStartRepair
{}

[cpp_event(unicast, with_scheme)]
struct EventRepairSystemOnStopRepair
  notFinished : bool
