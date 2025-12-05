require ecs
require inventory
require %game.events
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.es.human_reload_common
require DngHuman
require WTPhysActor
require DagorSystem
require DagorMath
require DagorRandom
require PropsManager
require DaWeapons
require HumanPhys
require app

def interrupt_reload_immediately_impl(human_weap__reloadStartTime : float;
                                      var human_weap__reloadFinishTime : float&;
                                      var human_weap__reloadAtTime : float&;
                                      var human_weap__isReloadRequested : bool&)
  human_weap__reloadFinishTime = human_weap__reloadStartTime
  human_weap__reloadAtTime = human_weap__reloadStartTime
  human_weap__isReloadRequested = false


[es]
def human_weap_interrupt_reload_immediately_es(evt : CmdInterruptReloadImmediately;
                                               human_weap__reloadStartTime : float;
                                               var human_weap__reloadFinishTime : float&;
                                               var human_weap__reloadAtTime : float&;
                                               var human_weap__isReloadRequested : bool&)
  interrupt_reload_immediately_impl(human_weap__reloadStartTime,
                                    human_weap__reloadFinishTime,
                                    human_weap__reloadAtTime,
                                    human_weap__isReloadRequested)


def interrupt_single_reload(gun_eid : EntityId;
                            at_time : float;
                            entity_mods__reloadMult : float;
                            human_weap__reloadStartTime : float;
                            var human_weap__reloadFinishTime : float&;
                            var human_weap__reloadAtTime : float&;
                            var human_weap__isReloadRequested : bool&;
                            immediately : bool = false)
  var res = false
  query(gun_eid) <| $ [es] (gun_anim__reloadStyle : int;
                            single_reload__prepareTime : float = 0.1;
                            single_reload__loopTime : float = 1.0;
                            single_reload__postTime : float = 0.1;
                            single_reload__jammedPostTime : float = 1.0;
                            gun__reloadFinishMult : float = 0.9f;
                            gun__ammo : int = 0)
    if gun__ammo <= 0
      return

    if immediately
      interrupt_reload_immediately_impl(human_weap__reloadStartTime,
                                        human_weap__reloadFinishTime,
                                        human_weap__reloadAtTime,
                                        human_weap__isReloadRequested)
      res = true
      return

    var prepareTime = single_reload__prepareTime
    var loopTime = single_reload__loopTime
    var postTime = single_reload__postTime

    if gun_anim__reloadStyle == int(GunReloadStyle.RELOAD_STYLE_JAMMED)
      postTime = single_reload__jammedPostTime

    prepareTime *= entity_mods__reloadMult
    loopTime *= entity_mods__reloadMult
    postTime *= entity_mods__reloadMult

    let loopStart = human_weap__reloadStartTime + prepareTime
    let loopEnd = human_weap__reloadAtTime - postTime
    if at_time >= loopStart && at_time < loopEnd
      let finishMult = gun__reloadFinishMult
      let loopCur = at_time - loopStart
      let loop = safediv(loopCur, loopTime)
      let restTime = (ceil(loop) - loop) * loopTime + postTime
      human_weap__reloadFinishTime = at_time + restTime * finishMult
      human_weap__reloadAtTime = at_time + restTime
      res = true

  return res


[es(after=gun_init_es)]
def unload_ammo_es(evt : CmdUnloadAmmo;
                   gun__shell_prop_ids : PropsIdList&;
                   gun__saveAmmoInChamberOnReload : bool = false;
                   var gun__ammo : int&;
                   var gun__ammoToReloadCount : int&;
                   var gun__curShellId : PropsId&;
                   var gun : Gun&;
                   var gun__manuallyUnloaded : bool&)
  let addChamberAmmo = gun__saveAmmoInChamberOnReload && gun__ammo > 0
  gun__ammo = addChamberAmmo ? 1 : 0
  gun__ammoToReloadCount = 0
  gun__curShellId = gun__shell_prop_ids[0]
  gun.curState.loaded = addChamberAmmo
  gun__manuallyUnloaded = evt.unloadManually


[es]
def load_ammo_es(evt : CmdLoadAmmo;
                 gun__saveAmmoInChamberOnReload : bool = false;
                 var gun : Gun;
                 var gun__ammo : int&;
                 var gun__manuallyUnloaded : bool&)
  let addChamberAmmo = gun__saveAmmoInChamberOnReload && gun__ammo > 0
  gun__ammo = evt.ammoNum + (addChamberAmmo ? 1 : 0)
  gun.curState.loaded = (gun__ammo > 0)
  gun__manuallyUnloaded = false


[es]
def human_weap_interrupt_single_reload_es(info : ParallelUpdateFrameDelayed;
                                          human_attached_gun__attachedGunEid : EntityId;
                                          human_weap__currentGunEid : EntityId;
                                          entity_mods__reloadMult : float = 1.0;
                                          human_weap__singleReload : bool;
                                          human_net_phys : HumanActor&;
                                          human_weap__reloadStartTime : float;
                                          var human_weap__reloadFinishTime : float&;
                                          var human_weap__reloadAtTime : float&;
                                          var human_weap__isReloadRequested : bool&)
  if !human_weap__singleReload
    return

  let isShootControlBit = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT)
  if human_weap__reloadFinishTime > info.curTime && isShootControlBit
    let gunEid = (human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
                 ? human_attached_gun__attachedGunEid
                 : human_weap__currentGunEid)
    if gunEid != INVALID_ENTITY_ID
      let immediately = has(gunEid, "reload__shootImmediatelyInterruptSingleReload")
      interrupt_single_reload(gunEid, info.curTime,
                              entity_mods__reloadMult, human_weap__reloadStartTime,
                              human_weap__reloadFinishTime, human_weap__reloadAtTime,
                              human_weap__isReloadRequested, immediately)


struct GunReloadData
  reloadStyle : GunReloadStyle
  prereq : bool
  reloadTime : float

[es(tag=server, REQUIRE=human, REQUIRE_NOT=deadEntity, on_appear)]
def human_inspect_on_spawn_init(evt : Event;
                                eid : EntityId)
  addSubTemplate(eid, "inspect_on_spawn")

[es(tag=server, REQUIRE=inspectOnSpawn, on_event=ParallelUpdateFrameDelayed)]
def human_inspect_on_spawn(evt : Event;
                           eid : EntityId;
                           active : bool;
                           human_weap__currentGunEid : EntityId;
                           human_net_phys : HumanActor&)
  if !active
    return
  assume phys = human_net_phys.phys
  assume currentState = phys.currentState
  assume weapEquipState = currentState.weapEquipState
  if weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED && !!human_weap__currentGunEid
    sendEvent(eid, CmdGunRequestInspect(atTime = get_sync_time(), gunEid = human_weap__currentGunEid))
    removeSubTemplate(eid, "inspect_on_spawn")

[es(tag=server)]
def human_weap_request_inspection_es(evt : CmdGunRequestInspect;
                                     eid : EntityId;
                                     human_weap__reloadStartTime : float;
                                     var human_weap__reloadFinishTime : float&;
                                     var human_weap__reloadAtTime : float&;
                                     var human_weap__isReloadRequested : bool&;
                                     var human_weap__inspectStartTime : float&;
                                     var human_weap__inspectEndTime : float&;
                                     var human_weap__singleReload : bool&)
  let atTime = evt.atTime
  let gunEid = evt.gunEid

  if human_weap__inspectEndTime > atTime
    return

  if !human_weap_can_reload(eid, gunEid)
    return

  query(gunEid) <| $ [es] (gun__inspectTime : float;
                           var gun_anim__reloadStyle : int&)
    let isReloading = atTime < human_weap__reloadFinishTime
    if isReloading
      interrupt_reload_immediately_impl(human_weap__reloadStartTime, human_weap__reloadFinishTime, human_weap__reloadAtTime, human_weap__isReloadRequested)
    human_weap__inspectStartTime = isReloading ? human_weap__reloadStartTime : atTime
    human_weap__inspectEndTime = atTime + gun__inspectTime
    
    
    
    human_weap__singleReload = false
    gun_anim__reloadStyle = int(GunReloadStyle.RELOAD_STYLE_INSPECT)

[es(tag=gameClient, track=human_weap__inspectStartTime, REQUIRE=(hero, human_weap__inspectStartTime))]
def show_weapons_ui_on_inspection_anim(evt : Event)
  broadcastEvent(CmdUIShowWeaponsBlock())

[es(tag=server)]
def human_weap_request_reload_es(evt : CmdRequestReload;
                                 eid : EntityId;
                                 itemContainer : EidList;
                                 human_weap__infiniteAmmoHolders : bool;
                                 var human_weap__reloadGunEid : EntityId&;
                                 var human_weap__reloadAtTime : float&;
                                 var human_weap__reloadFinishTime : float&;
                                 var human_weap__reloadStartTime : float&;
                                 var human_weap__reloadMode : int&;
                                 var human_weap__singleReload : bool&;
                                 var human_weap__singleReloadAmmoCount : int&;
                                 var human_weap__reloadPrevTime : float&;
                                 var human_weap__isReloadRequested : bool&;
                                 var human_weap__isDualMagReload : bool&;
                                 var human_weap__isQuickReload : bool&;
                                 entity_mods__jamChanceMult : float = 1.0;
                                 entity_mods__reloadMult : float = 1.0)
  let atTime = evt.atTime
  let gunEid = evt.gunEid
  let isQuickReloadRequested = evt.isQuick

  var shouldExit = false
  query(gunEid) <| $ [es(REQUIRE=multiStateReloadSystem)] ()
    shouldExit = true
  if shouldExit
    return

  if !human_weap_can_reload(eid, gunEid)
    return

  if human_weap__reloadAtTime > atTime
    if human_weap__singleReload
      interrupt_single_reload(gunEid, atTime,
                              entity_mods__reloadMult, human_weap__reloadStartTime,
                              human_weap__reloadFinishTime, human_weap__reloadAtTime,
                              human_weap__isReloadRequested)
    
    
    
    
    
    
    elif isQuickReloadRequested && !human_weap__isQuickReload
      query(gunEid) <| $ [es] (gun__quickReloadTime : float;
                               gun__reloadFinishMult : float = 0.9;
                               var gun_anim__reloadStyle : int&)
        gun_anim__reloadStyle = int(GunReloadStyle.RELOAD_STYLE_QUICK)
        human_weap__reloadAtTime = human_weap__reloadStartTime + gun__quickReloadTime
        human_weap__reloadFinishTime = human_weap__reloadStartTime + gun__quickReloadTime * gun__reloadFinishMult
        human_weap__isQuickReload = true
    return

  query(gunEid) <| $ [es] (gun__ammo : int;
                           gun__maxAmmo : int;
                           gun__reloadTime : float;
                           gun__quickReloadTime : float = -1.0;
                           gun__jammedReloadTime : float = -1.0;
                           gun__altReloadTime : float = -1.0;
                           gun__altJammedReloadTime : float = -1.0;
                           gun__dualMagReloadTime : float = -1.0;
                           gun__jamChance : float = 0.0;
                           gun__reloadFinishMult : float = 0.9;
                           gun__isDualMagReady : bool = false;
                           gun__saveAmmoInChamberOnReload : bool = false;
                           gun__forceFiniteAmmo : bool = false;
                           var gun__ammoOnSwitch : int&;
                           var gun__ammoToReloadCount : int&;
                           var gun_anim__reloadStyle : int&)
    
    let maxAmmo = gun__maxAmmo + (gun__saveAmmoInChamberOnReload ? 1 : 0)
    if gun__ammo >= maxAmmo && gun__ammo > 0
      return

    human_weap__reloadMode = int(human_weap__infiniteAmmoHolders && !gun__forceFiniteAmmo ? ReloadAmmoMode.INFINITE : ReloadAmmoMode.CONSUME)
    if human_weap__infiniteAmmoHolders && gun__ammoOnSwitch == 0
      
      gun__ammoOnSwitch = gun__maxAmmo
      human_weap__reloadMode = int(ReloadAmmoMode.CONSUME)

    find_ammo_for_gun(gunEid, itemContainer, INVALID_ITEM_ID, gun__ammo) <| $(ammoForGun : AmmoItemForGunResult)
      if ammoForGun.itemIndex < 0
        return

      gun_anim__reloadStyle = int(GunReloadStyle.RELOAD_STYLE_SIMPLE)
      let isDualMagReload = (gun__isDualMagReady && gun__ammo == 0)

      var reloadTime = 0.0

      var forceJam = false
      var forceAlt = false
      find_query() <| $ [es(REQUIRE=human_weap_reload_force_params)] (human_weap_reload_force_params__force_jam : bool;
                                                                      human_weap_reload_force_params__force_alt : bool)
        forceJam = human_weap_reload_force_params__force_jam
        forceAlt = human_weap_reload_force_params__force_alt
        return true

      if !ammoForGun.singleReload
        let haveAmmoInChamber = gun__saveAmmoInChamberOnReload && gun__ammo > 0
        let ammoLeftInMag = max(0, gun__ammo - (haveAmmoInChamber ? 1 : 0))
        let storeMagOnSoldier = ammoLeftInMag > 0 || forceAlt
        let shouldJam = (gfrnd() < (gun__jamChance * entity_mods__jamChanceMult)) || forceJam

        let gunReload = fixed_array<GunReloadData>(
          GunReloadData(reloadStyle = GunReloadStyle.RELOAD_STYLE_DUAL_MAG,
                          prereq = isDualMagReload,
                          reloadTime = gun__dualMagReloadTime),
          GunReloadData(reloadStyle = GunReloadStyle.RELOAD_STYLE_QUICK,
                          prereq = (isQuickReloadRequested || haveAmmoInChamber && ammoLeftInMag == 0),
                          reloadTime = gun__quickReloadTime),
          GunReloadData(reloadStyle = GunReloadStyle.RELOAD_STYLE_ALT_JAMMED,
                          prereq = (storeMagOnSoldier && shouldJam),
                          reloadTime = gun__altJammedReloadTime),
          GunReloadData(reloadStyle = GunReloadStyle.RELOAD_STYLE_ALT,
                          prereq = storeMagOnSoldier,
                          reloadTime = gun__altReloadTime),
          GunReloadData(reloadStyle = GunReloadStyle.RELOAD_STYLE_JAMMED,
                          prereq = shouldJam,
                          reloadTime = gun__jammedReloadTime),
          GunReloadData(reloadStyle = GunReloadStyle.RELOAD_STYLE_SIMPLE,
                          prereq = true,
                          reloadTime = gun__reloadTime),
          GunReloadData(reloadStyle = GunReloadStyle.RELOAD_STYLE_INSPECT,
                          prereq = false,
                          reloadTime = -1.0))

        for r in gunReload
          if r.prereq && (r.reloadTime >= 0.0)
            reloadTime = r.reloadTime
            gun_anim__reloadStyle = int(r.reloadStyle)
            break
      else
        query(gunEid) <| $ [es] (single_reload__prepareTime : float = 0.1;
                                 single_reload__loopTime : float = 1.0;
                                 single_reload__postTime : float = 0.1;
                                 single_reload__jammedPostTime : float = -1.0)
          var postTime = single_reload__postTime
          let shouldJam = gfrnd() < gun__jamChance * entity_mods__jamChanceMult || forceJam
          if single_reload__jammedPostTime >= 0.0 && shouldJam
            gun_anim__reloadStyle = int(GunReloadStyle.RELOAD_STYLE_JAMMED)
            postTime = single_reload__jammedPostTime

          let singleReloadAmmoCount = float(ammoForGun.singleReloadAmmoCount)
          let maxReqBullets = int(ceil(safediv(float(gun__maxAmmo - gun__ammo), singleReloadAmmoCount)))
          reloadTime = single_reload__prepareTime + single_reload__loopTime * float(maxReqBullets) + postTime

      reloadTime *= entity_mods__reloadMult
      human_weap__reloadGunEid = gunEid

      human_weap__reloadStartTime = atTime
      human_weap__reloadAtTime = human_weap__reloadStartTime + reloadTime
      human_weap__reloadFinishTime = human_weap__reloadStartTime + reloadTime * gun__reloadFinishMult
      human_weap__isDualMagReload = isDualMagReload
      human_weap__isQuickReload = gun_anim__reloadStyle == int(GunReloadStyle.RELOAD_STYLE_QUICK)
      human_weap__singleReload = ammoForGun.singleReload
      human_weap__singleReloadAmmoCount = ammoForGun.singleReloadAmmoCount
      human_weap__reloadPrevTime = atTime
      human_weap__isReloadRequested = true
      gun__ammoToReloadCount = ammoForGun.ammoCount

      sendEvent(eid, EventHumanStartedReload())


[es(tag=server, no_order, track=gun__ammo, on_appear)]
def server_update_is_ammo_loaded_es(evt : Event;
                                    gun__ammo : int;
                                    var gun__isAmmoLoaded : bool&)
  
  
  
  
  gun__isAmmoLoaded = (gun__ammo > 0)


[es(tag=server, after=gun_init_es, on_appear)]
def init_gun_cur_shell_id_es(evt : Event;
                             eid : EntityId;
                             gun__shell_prop_ids : PropsIdList;
                             shell_props : PropsId;
                             gun__shells : Array const?;
                             var gun__curShellId : PropsId&)
  if shell_props.valid
    gun__curShellId = shell_props
  elif length(gun__shell_prop_ids) > 0
    gun__curShellId = gun__shell_prop_ids[0]
  else
    gun__curShellId = PropsId()
    logerr("{getEntityTemplateName(eid)} has empty gun__shell_prop_ids. gun__shells: {gun__shells}")


[es(tag=gameClient, after=gun_init_es, track=gun__isAmmoLoaded, on_appear)]
def client_track_ammo_holder_es(evt : Event;
                                gun__owner : EntityId;
                                gun__ammo : int;
                                gun__isAmmoLoaded : bool;
                                var gun : Gun&)
  var isRemoteShadow = false
  query(gun__owner) <| $ [es] (human_net_phys : HumanActor)
    isRemoteShadow = human_net_phys.role == NetRole.ROLE_REMOTELY_CONTROLLED_SHADOW
  
  
  
  
  if isRemoteShadow
    gun.curState.loaded = gun__isAmmoLoaded
  else
    
    gun.curState.loaded = (gun__ammo > 0)


[es(REQUIRE_NOT=deadEntity)]
def human_weap_reload_es(info : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         human_weap__currentGunEid : EntityId;
                         var human_weap__reloadAtTime : float&;
                         var human_weap__reloadStartTime : float&;
                         var human_weap__reloadFinishTime : float&;
                         var human_weap__reloadDelayTime : float&)
  let canReloadGun = human_weap_can_reload(eid, human_weap__currentGunEid)
  if !canReloadGun && human_weap__reloadFinishTime > info.curTime
    human_weap__reloadDelayTime += info.dt
  elif human_weap__reloadDelayTime > 0.0
    human_weap__reloadAtTime = human_weap__reloadAtTime + human_weap__reloadDelayTime
    human_weap__reloadStartTime = human_weap__reloadStartTime + human_weap__reloadDelayTime
    human_weap__reloadFinishTime = human_weap__reloadFinishTime + human_weap__reloadDelayTime
    human_weap__reloadDelayTime = canReloadGun ? 0.0 : info.dt



[es(tag=server)]
def human_weap_reload_on_select_es(evt : EventOnSelectWeap;
                                   var human_weap__reloadAtTime : float&;
                                   var human_weap__reloadFinishTime : float&;
                                   var human_weap__reloadStartTime : float&;
                                   var human_weap__isReloadRequested : bool&)
  human_weap__reloadAtTime = -1.0
  human_weap__reloadFinishTime = -1.0
  human_weap__reloadStartTime = -1.0
  human_weap__isReloadRequested = false


[es(tag=server, on_event=(EventOnSelectWeap))]
def human_weap_reset_inspection_time(evt : Event;
                                     var human_weap__inspectStartTime : float&;
                                     var human_weap__inspectEndTime : float&)
  human_weap__inspectStartTime = -1.0
  human_weap__inspectEndTime = -1.0


[es(tag=server, track=human_net_phys__isClimbing)]
def human_weap_reload_interrupt_on_climbing(evt : Event; eid : EntityId; human_net_phys__isClimbing : bool)
  if human_net_phys__isClimbing
    sendEvent(eid, CmdInterruptReloadImmediately())
