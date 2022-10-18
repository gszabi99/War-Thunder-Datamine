module ship_events shared
require ecs
require DagorDataBlock

[cpp_event(unicast)]
struct EventShipInitDamageParts
  pumps : IntList

[cpp_event(unicast, with_scheme)]
struct EventShipCopyFrom
  eid : EntityId

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventShipRemoveBreach
  breachId : int

[cpp_event(unicast, with_scheme)]
struct EventShipOnRemoveBreach
  localPos : float3

[cpp_event(unicast, with_scheme, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventShipRequestRepairBreaches
  repair : bool

[cpp_event(unicast, with_scheme)]
struct EventShipOnGotBreach
  breachId : int
  localPos : float3
  offenderUnitId : int
  offenderBulletId : int

[cpp_event(unicast, with_scheme)]
struct EventShipAddFatalBreach
  localPos : float3
  localNormal : float3
  partId : int
  offenderUnitId : int
  offenderBulletId : int

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventShipAddBreach
  id : int
  partId : int
  localPos : float3
  localNormal : float3
  size : float
  offenderUnitId : int
  offenderBulletId : int

[cpp_event(unicast, with_scheme)]
struct EventShipPartDrowned
  partId : int

[cpp_event(unicast, with_scheme)]
struct EventShipDrownedPartRestored
  partId : int