module events shared
require ecs
require dm
require %game.dm.dm_events
require %game.dm.fire_system_events
require %game.unit.unit_events
require %game.unit.ammo_stowage_events
require %game.unit.repair_system_events
require %game.unit.extinguish_system_events
require %game.unit.ship_events
require Weapon
require DaWeapons


[cpp_event(broadcast)]
struct ParallelUpdateFrameDelayed
  curTime : float
  dt : float

[cpp_event(unicast)]
struct EventOnStartShooting
  weaponIdx : int

[cpp_event(unicast)]
struct EventOnMetaPartDamage
  damage : uint16

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
struct EventOnKeyDown
  eventId : int
  dt : float

[cpp_event(broadcast)]
struct EventOnKeyState
  eventId : int
  isDown : bool
  dt : float
  timeMSec : int

[cpp_event(broadcast)]
struct EventOnKeyUp
  eventId : int
  dt : float

[cpp_event(broadcast)]
struct EventOnShortcutEnable
  shortcut : string
  enable : bool

[cpp_event(broadcast)]
struct EventOnAllShortcutsEnable
  enable : bool

[cpp_event(broadcast)]
struct EventOnAxisEnable
  axis : string
  enable : bool

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

[cpp_event(unicast)]
struct CmdEngineStartSound
{}

[cpp_event(unicast)]
struct CmdEngineStopSound
{}

[cpp_event(unicast)]
struct CmdEnginePlayStartSound
{}

[cpp_event(unicast)]
struct CmdEnginePlayStopSound
{}

[cpp_event(unicast)]
struct CmdEngineStealSound
{}

[cpp_event(unicast)]
struct CmdEngineUnstealSound
{}

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
