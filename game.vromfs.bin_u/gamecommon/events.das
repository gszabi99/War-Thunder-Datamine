module events shared
require ecs
require dm
require %game.player_events
require %game.dm.dm_events
require %game.dm.fire_system_events
require %game.unit.unit_events
require %game.unit.ammo_stowage_events
require %game.unit.repair_system_events
require %game.unit.extinguish_system_events
require %game.unit.aircraft_events
require %game.unit.ship_events
require %game.unit.unit_proximity_damage_events
require Weapon
require DaWeapons
require PropsManager




[cpp_event(broadcast)]
struct ParallelUpdateFrameDelayed
  curTime : float
  dt : float

[cpp_event(broadcast)]
struct ActUpdateAlways
  curTime : float
  dt : float

[cpp_event(broadcast)]
struct ActUpdateInput
  curTime : float
  dt : float

[cpp_event(broadcast)]
struct ActUpdatePausable
  curTime : float
  dt : float

[cpp_event(broadcast)]
struct ActUpdatePaused
  curTime : float
  dt : float



[cpp_event(unicast)]
struct EventOnStartShooting
  weaponIdx : int

[cpp_event(unicast)]
struct EventOnMetaPartDamage
  damage : uint16
  offender : EntityId

[cpp_event(unicast)]
struct EventRepairMetaPart
{}

[cpp_event(unicast)]
struct CmdStopBurn
{}

[cpp_event(unicast)]
struct CmdUpdateRelativeUnitHealth
{}

[cpp_event(unicast)]
struct CmdUnitFxStopAll
  immediately : bool

[cpp_event(unicast)]
struct CmdUnitFxHide
  hide : bool

[cpp_event(unicast)]
struct CmdCameraUpdate
  dt : float
  controlsDt : float

[cpp_event(unicast)]
struct CmdPostPhysUpdate
  tick : int
  dt : float
  isForReal : bool

[cpp_event(broadcast)]
struct EventOnPlayerConnected
  userId : uint64

[cpp_event(broadcast)]
struct EventOnPlayerDisconnected
  userId : uint64

[cpp_event(broadcast)]
struct EventOnSessionEnd
  winnerTeam : int

[cpp_event(broadcast)]
struct EventOnPlayerSpawn
  userId : uint64
  unitId : int

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventFinishAssist
{}

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventTeamKill
  victimEid : EntityId

[cpp_event(unicast, with_scheme)]
struct EventGunShot
  noise : float

[cpp_event(unicast)]
struct CmdDisableMove
  eid : EntityId
  name : string

[cpp_event(broadcast, with_scheme)]
struct EventOnSupportUnitSpawn
{}

[cpp_event(broadcast, with_scheme)]
struct EventFlightStart
{}

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventSandUnitDead
{}

[cpp_event(broadcast)]
struct EventOnPlayerModSpend
  userId : uint64
  modName : string
  count : int
  unitName : string

[event(broadcast)]
struct MatchingRoomExtraParams
  routeEvaluationChance : float
  ddosSimulationChance : float
  ddosSimulationAddRtt : int

[cpp_event(broadcast, with_scheme)]
struct ChangeServerRoute
  currentIsUnresponsive : bool

[cpp_event(broadcast)]
struct EventOnConnectedToServer {}

[cpp_event(unicast)]
struct CmdForceMusic
  name : das_string

[cpp_event(unicast)]
struct CmdHeroRespawn
{}

[cpp_event(broadcast)]
struct CmdLockHangarMusic
{}

[cpp_event(unicast, with_scheme)]
struct EventOnTrailerDead
{}

[cpp_event(broadcast, with_scheme, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventTryControlBurav
  eid : EntityId
  target : float2

[cpp_event(unicast, with_scheme)]
struct EventKilledByBurav
  killerEid : EntityId

[cpp_event(unicast)]
struct CmdSetOperatorCountry
  country : das_string

[cpp_event(broadcast)]
struct EventOnPlayerUnlockStreak
  userId : uint64
  unitName : string
  unlockName : string
  statIdName : string
  amountWp : int
  stage : int
  isExcludeFromRating : bool

[event(broadcast)]
struct EventSoundAreaInit
{}

[cpp_event(broadcast)]
struct EventOnPlayerStat
  userId : uint64
  statIdName : string

[event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventPickUpLoot
  loot_type : int
  count : int

[cpp_event(unicast, with_scheme)]
struct EventOnUnitDead
  killer_eid : EntityId

[cpp_event(broadcast, with_scheme)]
struct EventRendInstDestroyed
  pos : float3
  riType : uint

[cpp_event(unicast, with_scheme, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdActionInRespawn {}

[cpp_event(unicast, with_scheme)]
struct EventTryBuildObject {}

[cpp_event(unicast, with_scheme)]
struct EventToggleArtilleryView
  enable : bool

[cpp_event(unicast, with_scheme)]
struct EventToggleBuildingPreview
  enable : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdBuildObject
  tm : float3x4
  objectTemplate : string
  triggerGroup : WeaponTriggerGroups

[cpp_event(unicast, with_scheme)]
struct EventRearmFromAmmoBox
  count : int

[cpp_event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT, filter=target_entity_conn)]
struct EventCantReloadingFromBox


[cpp_event(unicast, with_scheme, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventGmEngineOnOff
  value : bool

[cpp_event(unicast, with_scheme)]
struct EventTryToggleGMEngine
{}

[cpp_event(unicast, with_scheme)]
struct EventTryEnableEngine
{}

[event(unicast)]
struct EventTankEngineStageChanged
  newStage : uint8


[event(unicast)]
struct CmdUnloadAmmo
  unloadManually : bool


[event(unicast)]
struct CmdLoadAmmo
  ammoNum : int


[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestMultipleGunsSlotEquipGun
  gunEid : EntityId
  slot : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestMultipleGunsSlotSelectGun
  gunEid : EntityId
  slot : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestMultipleGunsSlotEquipNextGun
  slot : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdSelectWeaponSlot
  slot : uint8

[cpp_event(unicast)]
struct CmdNetUnitShot
  pos : float3
  vel : float3
  shellId : PropsId

[cpp_event(unicast)]
struct CmdNetShot
  shellId : int16
  damageId : int16
  ballisticsId : int16
  gunPropsId : int16
  atTime : float
  initialLifeTime : float
  tm : float3x4
  vel : float3
  firingMode : uint
  bombBayHeight : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanWeapThrowBackAbort {}

[event(unicast)]
struct EventOnSelectWeap
  curr_gun_slot_id : int

[event(broadcast)]
struct EventOnGunBlocksShoot
  reason : string

[event(unicast)]
struct CmdWeapModToggle
  slotId : int

[cpp_event(unicast)]
struct CmdWeapPhysUpdate
  owner : ecs::EntityId
  atTime : float
  dt : float
  isForReal : bool
  slotId : int
  gctrl : GunControls
  gloc : GunLocation


[cpp_event(unicast)]
struct CmdGunUpdate
  atTime : float
  isForReal : bool
  seed : int
  gctrl : GunControls
  gloc : GunLocation

[event(unicast)]
struct CmdRequestReload
  atTime : float
  gunEid : ecs::EntityId
  isQuick : bool

[event(unicast)]
struct CmdGunRequestInspect
  atTime : float
  gunEid : EntityId

[cpp_event(unicast)]
struct EventOnParentLoaded
  eid : ecs::EntityId
  slotId : int

[cpp_event(unicast)]
struct CmdWeapAttach
  toEid : EntityId
  isAttached : bool
  slotId : int


[event(unicast)]
struct CmdWeapDetach {}

[cpp_event(unicast)]
struct EventItemAttached
  attach_to : EntityId

[cpp_event(unicast)]
struct EventItemDetached
  detach_from : EntityId

[event(unicast)]
struct CmdSlotDetach {}

[cpp_event(unicast)]
struct CmdInitSkeletonAttach {}

[cpp_event(unicast)]
struct EventShotDry {}

[cpp_event(unicast)]
struct CmdGuidanceLockSwitch
  on : bool

[cpp_event(unicast)]
struct CmdLaunchShell
  launchDesc : LaunchDesc
  gunEid : EntityId

[cpp_event(unicast)]
struct CmdLaunchProjectile
  launchDesc : LaunchDesc
  gunEid : EntityId

[cpp_event(unicast)]
struct EventShot
  launchDesc : LaunchDesc

[event(unicast)]
struct CmdInterruptReloadImmediately {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdTurnOffSingleReloadInterruptByHold {}

[event(unicast)]
struct EventHumanStartedReload {}

[event(broadcast)]
struct CmdUIShowWeaponsBlock {}

[cpp_event(unicast)]
struct CmdApplyRagdollParameters
  cur_time : float

[event(unicast)]
struct CmdReinitWeapons {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRequestSetWishAmmoItemType
  slot_id : int
  item_id : int
  is_grenade_slot_current : bool

[event(unicast)]
struct EventOnGrenadeThrow
  gun_props_id : uint

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRequestUnloadAmmo
  slotId : int

[cpp_event(unicast)]
struct CmdSetWishAmmoItemType
  slot_id : int
  item_id : int

[event(unicast)]
struct CmdToggleWishAmmoItemType
  slot_id : int

[event(unicast)]
struct CmdStartNextReloadState {}

[event(unicast)]
struct EventUpdatedItemContainer {}

[cpp_event(broadcast, with_scheme)]
struct EventZoneCaptured
  areaId : int
  wasArmy : uint8
  army : uint8

[cpp_event(broadcast, with_scheme)]
struct EventBattleAreaStatusChanged
  active : bool
  areaId : int

[cpp_event(unicast, with_scheme)]
struct EventUnitToUnitCollision
  toUnit : EntityId
  lPos : float3
  fullImpulse : float
  damage : float
  isFriction : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdShowHitMark
  victim : EntityId
  collNodeId : int
  armorEfficiency : float
  damageToArmorPercent : float
  hitResult : int

[cpp_event(unicast, with_scheme)]
struct CmdTrySpawnSlave {}

[cpp_event(broadcast)]
struct EventEntityManagerBeforeClear {}

[cpp_event(broadcast)]
struct EventGameObjectsCreated
  game_objects : EntityId
