module extinguish_system_events shared
require ecs
require DagorMath
require WTDamageModel



[cpp_event(unicast, with_scheme, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventExtinguishSystemSetActive
  active : bool

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemSpendExtinguisher
{}

[cpp_event(unicast, with_scheme)]
struct EventExtinguishSystemStopBurnWithExtinguisher
  targetEid : EntityId
  hasMod : bool
  withPenalty : bool

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



[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventExtinguishSystemNetSync
  crewBusyRemainingTime : float
  extinguisherRemainingTime : float
  timeToNextExtinguisher : float
  extinguisherCount : int
