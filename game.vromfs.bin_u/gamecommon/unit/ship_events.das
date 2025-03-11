module ship_events shared
require ecs
require dm
require DagorDataBlock
require WTDamageModel

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

[cpp_event(unicast)]
struct EventShipOnGotBreach
  breachId : int
  localPos : float3
  offender : OffenderData

[cpp_event(unicast)]
struct EventShipAddFatalBreach
  localPos : float3
  localNormal : float3
  partId : PartId
  offender : OffenderData

[cpp_event(unicast)]
struct EventShipAddBreach
  id : int
  partId : PartId
  localPos : float3
  localNormal : float3
  size : float
  offender : OffenderData

[cpp_event(unicast, with_scheme)]
struct EventShipPartDrowned
  packedPartId : uint

[cpp_event(unicast, with_scheme)]
struct EventShipDrownedPartRestored
  packedPartId : uint

[cpp_event(unicast, with_scheme, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventShipStartDamageControl
  priorities : uint

[event(unicast)]
struct EventShipSyncWater
{}

[event(unicast)]
struct EventShipSyncBreaches
{}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventShipRequestNetSync
{}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventShipWaterNetSync
  unitVersion : uint8
  coverPartsWaterAndBalance : FloatList const?

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventShipBreachesNetSync
  unitVersion : uint8
  breachesPosAndSize : Point4List const? 
  breachesIds : IntList const? 
  breachesRepairProgress : FloatList const?  

