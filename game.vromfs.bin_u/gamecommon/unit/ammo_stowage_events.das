module ammo_stowage_events shared
require ecs
require dm
require WTDamageModel
require AmmoStowage
require BitStream


[cpp_event(unicast, with_scheme)]
struct EventBulletsAmountChanged
  
  isRefill : bool

[cpp_event(unicast)]
struct EventAmmoStowageApplySlotEffect
  partId : PartId
  effect : AmmoSlotEffectType

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageDoFireFx
  ammoLeft : float

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageResetReplenishment
{}

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageSendExplosionFatal
  ammoLeft : float
  seed : int
  fullExpl : bool

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventDoAmmoExplode
  isFatal : bool
  fullExpl : bool
  localPos : float3
  packedPartId : uint
  rndSeed : int
  splashRadius : float2
  splashPenetration : float
  splashDamage : float
  splashDamageTypeId : int
  shatterRadius : float
  shatterCount : float
  shatterPenetration : float
  shatterDamage : float
  shatterDamageTypeId : int

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageDoDelayedExplosionEffects
  packedPartId : uint
  stowageId : int
  clusterId : int
  pos : float3
  strengthEquivalent : float
  brisanceEquivalent : float
  shellMass : float
  splashDamageTypeId : int
  shatterDamageTypeId : int

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageDoDelayedFireEffects
  packedPartId : uint
  stowageId : int
  clusterId : int
  innerRadius : float
  outerRadius : float
  penetration : float
  damage : float
  damageTypeId : int
  pos : float3

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageDoImmediateExplosionEffects
  packedPartId : uint
  stowageId : int
  clusterId : int

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageDoImmediateFireEffects
  packedPartId : uint
  stowageId : int
  clusterId : int

[cpp_event(unicast)]
struct EventAmmoStowageDoFatalFire
  stowageId : int
  clusterId : int
  partId : PartId
  ammoLeft : float
  offender : OffenderData

[cpp_event(unicast)]
struct EventAmmoStowageDoFatalExplosion
  stowageId : int
  clusterId : int
  partId : PartId
  ammoLeft : float
  offender : OffenderData
  seed : int
  fullExpl : bool

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageOnEndAmmoFire
  doKillEffect : bool

[cpp_event(unicast, with_scheme)]
struct EventAmmoStowageInvalidateRenderer
{}

[event(unicast)]
struct EventAmmoStowageSetup
  netSyncIfRequired : bool
  initNum : bool
  isRefill : bool

[event(unicast, version=0, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventAmmoStowageNetSync
  bs : BitStream const?

[event(unicast, version=0, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventAmmoStowageNetSyncReplanishmentReset
  stowageId : int
  endTime : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventAmmoStowageForceReloadGun
  stowageId : int