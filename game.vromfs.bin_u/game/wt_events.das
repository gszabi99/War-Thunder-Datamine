module wt_events shared

require ecs
require RiDestr
require RendInst
require %appGame.squad_order_enums




[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventAnyEntityDied
  victim : EntityId
  offender : EntityId
  offenderPlayer : EntityId
  victimPlayer : EntityId
  damageType : int
  
  
  collNodeId : int
  victimTeam : int
  offenderTeam : int


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventSquadTargetsAddEid
  targetEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventSquadTargetsRemoveEid
  targetEid : EntityId

[event(unicast)]
struct EventEntityEnemyKilledToPart
  collNodeId : int
  damageType : int

[event(unicast)]
struct EventEntityWasKilledToPart
  collNodeId : int
  damageType : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventHeadShotKill {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdHumanHitNetSound
  offender : EntityId
  damageType : int
  actionPropsId : int
  collNodeId : int
  shatterCount : int
  time : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayLootSoundForEnemy
  hash : uint
  time : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayLootSound
  hash : uint
  time : float

[cpp_event(unicast)]
struct EventAnimIrq
  irqType : int

[cpp_event(unicast)]
struct CmdSoundIrq
  irq : string
  irqType : uint

[cpp_event(unicast)]
struct CmdPrePhysUpdate
  tick : int
  dt : float
  isForReal : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestBipodPlacing
  enabled : bool
  isCrawl : bool
  anchorPos : float3
  anchorDir : float3
  anchorHeight : float
  anchorOffset : float3
  anchorNormal : float3
  anchorYawLimit : float2
  recoilMult : float

[cpp_event(unicast, with_scheme)]
struct EventToggleHydrophoneMode
{}

[cpp_event(broadcast, with_scheme)]
struct EventOnVisualExplosion
  pos : float3
  explosion_radius : float
  props_id : uint
  offender_eid : EntityId

[cpp_event(unicast, with_scheme)]
struct EventProjectilePhysContact
  pos : float3
  vel : float3
  norm : float3

[event(unicast)]
struct EventSetHydrophoneMode
  isActive : bool

[cpp_event(unicast, with_scheme)]
struct EventIdentifyHydrophoneTarget
{}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStartPlantingMineOnWall
  pos : float3
  norm : float3
  wallEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStopPlantingMineOnWall {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStartReassemblingWall
  wallEid : EntityId
  position : float3

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStopReassemblingWall
  reassembled : bool

[event(unicast)]
struct CmdPlantMineOnWall {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStartLockingDoor
  doorEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStopLockingDoor {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStartBreakingDoor
  doorEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStopBreakingDoor {}

[event(broadcast)]
struct EventResetDoorToInitialState {}

[event(unicast)]
struct EventDoorControllerInited {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventResetDeathCooldown {}

[event(unicast)]
struct EventDoorChangeStateRequest
  target_door_state : int

[event(unicast)]
struct RotatingRendinstSimplePhysFixedUpdate
  dt : float

[event(unicast)]
struct RotatingRendinstSimplePhysUpdateFinished
  accRatio : float

[event(unicast)]
struct RotatingRendinstSimplePhysClampAngleReached
  angle : float

[cpp_event(unicast, with_scheme)]
struct EventRendinstOnProjectileHit
  projectile_eid : EntityId
  pos : float3
  impulse : float3
  time : float

[cpp_event(unicast, with_scheme)]
struct EventRiExtraDestroyed
  offenderEid : ecs::EntityId

[cpp_event(unicast)]
struct EventRendinstImpulse
  impulse : float
  impulseDir : float3
  impulsePos : float3
  collisionNormal : float3
  userData : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestRendinstDamage
  handle : riex_handle_t
  damage : float
  pos : float3
  impulse : float3
  time : float

[cpp_event(unicast)]
struct CmdRendinstDamage
  handle : riex_handle_t
  damage : float
  pos : float3
  impulse : float3
  time : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestRendinstEntityDamage
  eid : EntityId
  damage : float
  pos : float3
  impulse : float3
  time : float

[event(unicast)]
struct CmdWeapSwitchSight
  toNext : bool

[event(unicast)]
struct CmdWeapModActivate
  slotId : int
  activate : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanWeapRequestSwitchFiringMode
  slotId : uint8
  modeId : uint8

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdServerLoadAmmo
  ammoNum : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct LaserToggle
  slotId : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct FlashLightToggle
  slotId : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventSetBuildingTarget
  target : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventDismantleBuilding
  target : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdHeroLogEvent
  event : string
  text : string
  sound : string
  ttl : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdPutOutFireStart {}

[cpp_event(unicast, with_scheme)]
struct CmdRequestSuicide {}

[cpp_event(unicast, with_scheme)]
struct CmdUse
  requesterEid : EntityId

[event(unicast)]
struct CmdUseAlt
  requesterEid : EntityId

[cpp_event(unicast)]
struct HumanUseObjectRequest
  objectEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanUseAltObjectRequest
  objectEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct RunActionCmd
  id : int
  overridePropsId : uint
  overrideTime : float
  overrideAt : float
  actionPeriod : float
  progress : float
  timeMult : float

[event(unicast)]
struct CmdMedkitUse {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMedkitUseRequest {}

[event(unicast)]
struct CmdMedkitUseCancel {}

[event(unicast)]
struct CmdInitScaleSkeletonAttach {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanUseItemRequest
  item : EntityId
  target : EntityId

[event(unicast)]
struct EventOnItemStartUse
  target : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdRestoreEntityHp
  restoreHp : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdRestoreEntityDamageOverTime
  restoreDot : float

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdPutOutFireStop {}

[cpp_event(unicast, with_scheme)] 
struct CmdRequestHumanVoiceEffect
  phrase : string

[event(unicast)]
struct CmdOpenSquadOrdersMenu {}

[event(unicast)]
struct CmdCloseSquadOrdersMenu {}

[event(unicast)]
struct RqContextCommand{}

[cpp_event(unicast, with_scheme)]
struct RqCancelContextCommand
  include_personal_orders : bool

[event(unicast)]
struct RqPersonalContextCommand{}

[cpp_event(unicast, with_scheme)]
struct RqCancelPersonalContextCommand{}

[event(unicast)]
struct RqContextCommandPointOrder
  pointOrderStrID : string

[event(unicast)]
struct RqMenuContextCommandPointOrder
  pointOrderStrID : string

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestSquadOrder
  orderType : SquadOrder
  orderPosition : float3
  orderUseEntity : ecs::EntityId
  orderDirection : float3
  orderAltPosition : float3

[event(unicast)]
struct CmdCollisionDamage
  damage : float
  pos : float3
  offender : ecs::EntityId

[event(unicast)]
struct NextVariableZoomGunScope {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestSquadMateOrder
  orderType : SquadMateOrder
  orderPosition : float3
  orderUseEntity : ecs::EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestPersonalSquadMateOrder
  orderType : int
  orderPosition : float3
  orderByDirection : float3
  orderToPosition : float3
  orderToDirection : float3
  orderUseEntity : ecs::EntityId

[event(unicast)]
struct EventTakeDroneLauncherOrDroneTacticalPhone
  atTime : float
  weaponSlot : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdRequestDestroyDrone
  droneEid : EntityId

[cpp_event(unicast, with_scheme)]
struct CmdDestroyDrone {}

[event(unicast)]
struct CmdDroneAcquireControls {}

[event(unicast)]
struct CmdDroneReleaseControls {}

[event(unicast)]
struct CmdDroneLaunchOrAcquireControlsFromPhone {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseDroneLauncherFailLaunch {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestDroneLauncherInstantLaunch
  droneLauncherEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestDroneLauncherStartLaunch
  droneLauncherEid : EntityId
  atTime : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventSetTactialPhoneMode
  tacticalPhoneEid : EntityId
  mode : int

[event(unicast)]
struct EventRequestSwitchTactialPhoneMode
  ownerEid : EntityId
  mode : int

[event(unicast)]
struct EventRequestTakeTactialPhone
  ownerEid : EntityId
  mode : int

[cpp_event(unicast)]
struct EventOnInstallWeapMod
  slotTag : string
  gunSlotId : int
  withSfx : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRequestModActivate
  slotId : int
  activate : bool

[cpp_event(unicast)]
struct EventFlashExploded
  pos : float3
  tinnitusRad : float2
  flashRad : float2
  tinnitusPower : float2
  flashPower : float2
  flashDistExp : float
  tinnitusDistExp : float
  ignoreEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventShellExplodeNetClient
  pos : float3
  shellId : uint
  shellOwner : EntityId

[event(unicast)]
struct EventShellExplodedServer
  pos : float3
  vel : float3

[cpp_event(broadcast)]
struct EventOnEntityHit
  victim : EntityId
  offender : EntityId
  damageType : int
  collNodeId : int
  deltaHp : float
  hitPos : float3
  hitDir : float3
  hitResult : int

[event(unicast)]
struct CmdOnHeroHit
  damageType : int
  hitDir : float3
  collNodeId : int

[event(unicast)]
struct EventDamageOverTimeFinished {}

[event(unicast)]
struct CmdApplyDamage
  offender : EntityId
  damageType : int
  shellId : uint
  gunPropsId : uint
  deltaHp : float
  hitPos : float3

[cpp_event(unicast)]
struct EventUseItem
  item : EntityId
  target : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanStopUseItemRequest {}

[event(unicast)]
struct EventOnLootItemUsed
  target : ecs::EntityId

[event(unicast)]
struct EventOnLootUse
  itemEid : ecs::EntityId

[event(unicast)]
struct EventInterruptItemUse {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEntityDied
  victim : EntityId
  offender : EntityId
  victimTeam : int
  offenderTeam : int
  collNodeId : int

[event(unicast)]
struct CmdBodyCleanup
  time : float

[event(unicast)]
struct CmdInventoryPickup
  itemEid : EntityId
  usefulOnly : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdInventoryPickupGunMod
  item : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRemoveItemFromWeapRequest
  slotId : int
  slotName : string
  toGround : bool

[event(unicast)]
struct CmdInventoryDropGun
  slotId : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanDropWeapRequest
  slotId : int

[cpp_event(unicast)]
struct EventOnLootDrop
  itemEid : EntityId

[event(unicast)]
struct EventOnActionDisabled
  action : string

[event(unicast)]
struct CmdPickupSpecialItem
  pickuperEid : EntityId
  usefulOnly : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanPickupItemRequest
  itemEid : EntityId
  usefulOnly : bool

[event(unicast)]
struct CmdEquipItem
  itemEid : EntityId
  slotName : string

[cpp_event(unicast)]
struct CmdEquipItemDirect
  itemEid : EntityId
  slot : string
  allowReorderSlots : bool
  dropPrevItem : bool

[event(unicast)]
struct EventOnWeapSlotItemPickup
  itemEid : EntityId
  slotId : int

[cpp_event(unicast)]
struct HumanWeapSetCurrentGun
  slot : uint8

[cpp_event(unicast)]
struct CmdSwapEquipSlots
  item : EntityId
  fromSlotName : string
  toSlotName : string

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdTacticalDeviceMode
  mode : int

[event(unicast)]
struct CmdUseUsefulBox
  requesterEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT, net_liable=ignore)]
struct CmdUsefulBoxCompleteUse {}

[event(unicast)]
struct EventOnUsefulBoxSuccessfulUse
  requester : EntityId

[event(unicast)]
struct EventApplyCustomAnimcharVars {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStartPlacePlaceableItem
  itemEid : EntityId
  tm : float3x4
  vehicleEid : EntityId
  vehicleNodeId : int

[event(unicast)]
struct CmdFinishPlacePlaceableItem
  tm : float3x4
  newTemplate : string
  itemEid : EntityId
  vehicleEid : EntityId
  vehicleNodeId : int

[cpp_event(unicast)]
struct EventEntityRecreated {}

[event(unicast)]
struct EventPlayerBlindness
  position : float3
  radius : float2
  power : float2
  distExponent : float

[event(unicast)]
struct EventFlashBlindEffect
  power : float

[event(unicast)]
struct EventRetinalDamageEffect
  position : float3
  distance : float

[event(unicast)]
struct EventPlayerTinnitus
  position : float3
  radius : float2
  power : float2
  distExponent : float

[event(unicast)]
struct CmdStartTinnitusSfx
  pos : float3
  power : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestThrowableLauncherStartThrow
  throwableLauncherEid : EntityId
  atTime : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestThrowableLauncherDirectThrow
  throwableLauncherEid : EntityId
  direction : float3

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseThrowableLauncherFailThrow {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestTntBlockExploderStartExplode
  tntExploderEid : EntityId
  atTime : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseTntExploderFailExplode {}

[event(unicast)]
struct GameEffectStateChanged 
  attachedTo : EntityId
  activated : bool

[cpp_event(broadcast, with_scheme)]
struct EventHangarCameraRotated
  anglesDiff : float2

[cpp_event(broadcast, with_scheme)]
struct EventHangarCameraZoom
  zoomDelta : float

[cpp_event(unicast, with_scheme)]
struct CmdHangarRaiseWeapon {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestQuickThrowGrenade
  grenade_ammo_id : int

[event(broadcast)]
struct EventArmorInfoChanged {}

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct CmdCreateHudTacticalMapDangerIcon
  worldPos : float3
  blinkTime : float

[event(unicast)]
struct ReplayTrackAttachToWeapon {}

[cpp_event(unicast)]
struct EventStopShoot {}

[event(unicast)]
struct ReplayPostProdSaveEntity
  templateName : string
  tm : float3x4
  time : float

[event(unicast)]
struct ReplayPostProdSaveFile {}

[event(unicast)]
struct ReplayPostProdLoadFile {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayItemUseSound
  requesterEid : EntityId

[event(broadcast)]
struct EventToggleWeaponryWnd
  isOpen : bool

[event(broadcast)]
struct EventToggleDemonstratedShellOpt
  enable : bool