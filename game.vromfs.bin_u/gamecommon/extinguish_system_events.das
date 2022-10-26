module extinguish_system_events shared
require ecs


// hanled in das
[cpp_event(unicast, with_scheme)]
struct EventFireSystemStopSingleBurn
  fireId : int

[cpp_event(unicast, with_scheme, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventExtinguishSystemSetActive
  active : bool

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemStopBurnWithExtinguisher
  modRequired : bool

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemActivateExtinguisher
  assisteeId : EntityId

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemExtinguishByAlly
  assistantId : EntityId

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemAddExtinguisherCount
  count : int

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemTurnOffExtinguisher
{}

[cpp_event(unicast)]
struct EventFireSystemNetSync
  isBurning : bool
  crewBusyRemainingTime : float
  extinguisherRemainingTime : float
  timeToNextExtinguisher : float
  extinguisherCount : int
  partIds : UInt16List
  fireParamsIds : IntList
  partsBurning : BoolList

// handled in cpp

[cpp_event(unicast, with_scheme)]
struct EventFireSystemStopBurn
{}

[cpp_event(unicast, with_scheme)]
struct EventFireSystemOnStartBurnNoOffender
{}

[cpp_event(unicast, with_scheme)]
struct EventFireSystemStartSingleBurn
  partId : int
  fireParamsId : int

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemOnExtinguisherActivate
  active : bool

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemNotifyCrewBusy
  busy : bool

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemNotifyExtinghuished
{}

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemNotifyCantExtinguish
{}