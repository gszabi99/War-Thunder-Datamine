require ecs
require app
require DagorMath
require %appGame.infantry.es.human_reload_common
require %appGame.infantry.es.gun_reload_common
require %appGame.infantry.es.human_weap_common
require %game.events



def gun_reload_try_enable_state(gun_eid : EntityId;
                                state : int;
                                length : float;
                                flags : GunReloadStateFlags = bitfield(0);
                                state_specific_check : block<() : bool> = $ () => true)
  var isEnabled = false
  query(gun_eid) <| $ [es] (gun_reload__isReloading : bool;
                            var gun_reload__stateStartTime : float&;
                            var gun_reload__stateEndTime : float&;
                            var gun_reload__state : int&;
                            var gun_reload__isNextStateSelected : bool&;
                            var gun_reload__stateAcceptsInterruptRequest : bool&)
    if (!gun_reload__isReloading ||
        gun_reload__isNextStateSelected ||
        gun_reload__state > state ||
        (gun_reload__state == state && !flags.CanLoop))
      return

    if !(state_specific_check |> invoke())
      return

    let currentTime = get_sync_time()
    gun_reload__stateStartTime = currentTime
    gun_reload__stateEndTime = currentTime + length
    gun_reload__state = state
    isEnabled = true
    gun_reload__isNextStateSelected = true
    gun_reload__stateAcceptsInterruptRequest = flags.CanInterrupt

  return isEnabled


[es]
def gun_reload_reset_next_state_selected(evt : CmdStartNextReloadState;
                                         var gun_reload__isNextStateSelected : bool&)
  gun_reload__isNextStateSelected = false


[es(after=gun_reload_reset_next_state_selected)]
def gun_reload_state_empty_chamber_load(evt : CmdStartNextReloadState;
                                        eid : EntityId;
                                        gun_reload__state : int;
                                        gun__owner : EntityId;
                                        gun_reload_state__emptyChamberCount : int = 1)
  if gun_reload__state == int(GunReloadState.LOOP_EMPTY_CHAMBER)
    query(gun__owner) <| $ [es] (var itemContainer : EidList&)
      reload_with_bullets(gun__owner, itemContainer, eid, gun_reload_state__emptyChamberCount, ReloadAmmoMode.CONSUME)


[es(after=gun_reload_state_empty_chamber_load)]
def gun_reload_state_empty_chamber(evt : CmdStartNextReloadState;
                                   eid : EntityId;
                                   gun__owner : EntityId;
                                   gun__ammo : int;
                                   gun__maxAmmo : int;
                                   gun__ammoHolderIds : IntList;
                                   gun__wishAmmoItemType : int;
                                   gun_reload_state__emptyChamberTime : float;
                                   gun_reload_state__emptyChamberCount : int = 1)
  let reloadSpeedMult = get_float(gun__owner, "entity_mods__reloadMult") ?? 1.0
  let stateTime = gun_reload_state__emptyChamberTime * reloadSpeedMult
  gun_reload_try_enable_state(eid,
                              int(GunReloadState.LOOP_EMPTY_CHAMBER),
                              stateTime,
                              GunReloadStateFlags.CanInterrupt) <| $()
    assume bulletsToInsert = gun_reload_state__emptyChamberCount
    let hasCapacityToInsert = gun__maxAmmo - gun__ammo >= bulletsToInsert
    let magazineIsEmpty = gun__ammo == 0
    if !hasCapacityToInsert || !magazineIsEmpty
      return false

    return has_holder_with_enough_bullets(gun__owner, bulletsToInsert, gun__wishAmmoItemType, gun__ammoHolderIds, gun__maxAmmo)


[es(after=gun_reload_state_empty_chamber)]
def gun_reload_state_prepare(evt : CmdStartNextReloadState;
                             eid : EntityId;
                             gun__owner : EntityId;
                             gun_reload_state__prepareTime : float)
  let reloadSpeedMult = get_float(gun__owner, "entity_mods__reloadMult") ?? 1.0
  let stateTime = gun_reload_state__prepareTime * reloadSpeedMult
  gun_reload_try_enable_state(eid, int(GunReloadState.LOOP_PREPARE), stateTime)


[es(after=gun_reload_state_prepare)]
def gun_reload_state_bullet_multiple_load(evt : CmdStartNextReloadState;
                                          eid : EntityId;
                                          gun_reload__state : int;
                                          gun__owner : EntityId;
                                          gun_reload_state__bulletMultipleCount : int)
  if gun_reload__state == int(GunReloadState.LOOP_BULLET_MULTIPLE)
    query(gun__owner) <| $ [es] (var itemContainer : EidList&)
      reload_with_bullets(gun__owner, itemContainer, eid, gun_reload_state__bulletMultipleCount, ReloadAmmoMode.CONSUME)


[es(after=gun_reload_state_bullet_multiple_load)]
def gun_reload_state_bullet_multiple(evt : CmdStartNextReloadState;
                                     eid : EntityId;
                                     gun__owner : EntityId;
                                     gun__ammo : int;
                                     gun__maxAmmo : int;
                                     gun__ammoHolderIds : IntList;
                                     gun__wishAmmoItemType : int;
                                     gun_reload__shouldInterrupt : bool;
                                     gun_reload_state__bulletMultipleTime : float;
                                     gun_reload_state__bulletMultipleCount : int)
  let reloadSpeedMult = get_float(gun__owner, "entity_mods__reloadMult") ?? 1.0
  let stateTime = gun_reload_state__bulletMultipleTime * reloadSpeedMult
  gun_reload_try_enable_state(eid,
                              int(GunReloadState.LOOP_BULLET_MULTIPLE),
                              stateTime,
                              GunReloadStateFlags.CanLoop | GunReloadStateFlags.CanInterrupt) <| $()
    assume bulletsToInsert = gun_reload_state__bulletMultipleCount
    let hasCapacityToInsert = gun__maxAmmo - gun__ammo >= bulletsToInsert

    
    let shouldInterrupt = gun_reload__shouldInterrupt && gun__ammo > 0
    
    if !hasCapacityToInsert || shouldInterrupt
      return false

    return has_holder_with_enough_bullets(gun__owner, bulletsToInsert, gun__wishAmmoItemType, gun__ammoHolderIds, gun__maxAmmo)


[es(after=gun_reload_state_bullet_multiple)]
def gun_reload_state_bullet_single_load(evt : CmdStartNextReloadState;
                                        eid : EntityId;
                                        gun__owner : EntityId;
                                        gun_reload__state : int)
  if gun_reload__state == int(GunReloadState.LOOP_BULLET_SINGLE)
    query(gun__owner) <| $ [es] (var itemContainer : EidList&)
      reload_with_bullets(gun__owner, itemContainer, eid, 1, ReloadAmmoMode.CONSUME)


[es(after=gun_reload_state_bullet_single_load)]
def gun_reload_state_bullet_single(evt : CmdStartNextReloadState;
                                   eid : EntityId;
                                   gun__owner : EntityId;
                                   gun__ammo : int;
                                   gun__maxAmmo : int;
                                   gun__ammoHolderIds : IntList;
                                   gun__wishAmmoItemType : int;
                                   gun_reload__shouldInterrupt : bool;
                                   gun_reload_state__bulletSingleTime : float)
  let reloadSpeedMult = get_float(gun__owner, "entity_mods__reloadMult") ?? 1.0
  let stateTime = gun_reload_state__bulletSingleTime * reloadSpeedMult
  gun_reload_try_enable_state(eid,
                              int(GunReloadState.LOOP_BULLET_SINGLE),
                              stateTime,
                              GunReloadStateFlags.CanLoop | GunReloadStateFlags.CanInterrupt) <| $()
    let bulletsToInsert = 1
    let hasCapacityToInsert = gun__maxAmmo - gun__ammo >= bulletsToInsert

    
    let shouldInterrupt = gun_reload__shouldInterrupt && gun__ammo > 0
    
    if !hasCapacityToInsert || shouldInterrupt
      return false

    return has_holder_with_enough_bullets(gun__owner, bulletsToInsert, gun__wishAmmoItemType, gun__ammoHolderIds, gun__maxAmmo)


[es]
def gun_reload_state_post(evt : CmdStartNextReloadState;
                          eid : EntityId;
                          gun__owner : EntityId;
                          gun_reload_state__postTime : float)
  let reloadSpeedMult = get_float(gun__owner, "entity_mods__reloadMult") ?? 1.0
  let stateTime = gun_reload_state__postTime * reloadSpeedMult
  gun_reload_try_enable_state(eid, int(GunReloadState.LOOP_POST), stateTime)


def gun_reload_finish(eid)
  query(eid) <| $ [es] (var gun_reload__isReloading : bool&;
                        var gun_reload__shouldInterrupt : bool&;
                        var gun_reload__state : int&;
                        var gun_reload__stateAcceptsInterruptRequest : bool&;
                        var gun_anim__reloadProgress : float&)
    gun_reload__shouldInterrupt = false
    gun_reload__state = int(GunReloadState.NONE)
    gun_reload__isReloading = false
    gun_reload__stateAcceptsInterruptRequest = false
    gun_anim__reloadProgress = 0.0


[es(after=gun_reload_state_post)]
def gun_reload_state_finished(evt : CmdStartNextReloadState;
                              eid : EntityId;
                              gun_reload__isNextStateSelected : bool)
  if gun_reload__isNextStateSelected
    return

  gun_reload_finish(eid)


[es(tag=server, track=gun_reload__isRequesting)]
def gun_reload_request_interrupt(evt : Event;
                                 gun_reload__isReloading : bool;
                                 gun_reload__isRequesting : bool;
                                 gun_reload__stateAcceptsInterruptRequest : bool;
                                 var gun_reload__shouldInterrupt : bool&)
  if gun_reload__isReloading && !gun_reload__isRequesting && gun_reload__stateAcceptsInterruptRequest
    gun_reload__shouldInterrupt = true


[es(after=human_weap_anim_es, before=gun_anim_updater_es, REQUIRE=multiStateReloadSystem)]
def gun_reload_calc_progress(info : ParallelUpdateFrameDelayed;
                             eid : EntityId;
                             gun_reload__state : int;
                             gun_reload__stateStartTime : float;
                             gun_reload__stateEndTime : float;
                             var gun_anim__reloadProgress : float&)
  if gun_reload__state == int(GunReloadState.NONE)
    return

  gun_anim__reloadProgress = cvt(info.curTime,
                                 gun_reload__stateStartTime,
                                 gun_reload__stateEndTime,
                                 0.0, 1.0)

  if info.curTime > gun_reload__stateEndTime
    sendEvent(eid, CmdStartNextReloadState())



[es(tag=server)]
def on_human_requested_reload(evt : CmdRequestReload;
                              eid : EntityId;
                              var human_weap__reloadMode : int&;
                              human_weap__infiniteAmmoHolders = false)
  let gunEid = evt.gunEid

  human_weap__reloadMode = int(human_weap__infiniteAmmoHolders ? ReloadAmmoMode.INFINITE : ReloadAmmoMode.CONSUME)

  var shouldExit = true
  query(gunEid) <| $ [es(REQUIRE=multiStateReloadSystem)] ()
    shouldExit = false
  if shouldExit
    return

  if !human_weap_can_reload(eid, gunEid)
    return

  query(gunEid) <| $ [es] (gun__ammo : int;
                           gun__maxAmmo : int;
                           gun__wishAmmoItemType : int;
                           gun__ammoHolderIds : IntList;
                           var gun_reload__isReloading : bool&)

    
    var minBulletsToInsert = 1
    query(gunEid) <| $ [es] (gun_reload_state__bulletSingleTime : float = -1.0;
                             gun_reload_state__bulletMultipleCount : int)
      let singleReloadIsAvailable = gun_reload_state__bulletSingleTime >= 0.0
      if !singleReloadIsAvailable
        minBulletsToInsert = gun_reload_state__bulletMultipleCount

    
    if (gun__ammo + minBulletsToInsert) > gun__maxAmmo && gun__ammo > 0
      return

    
    
    if !has_holder_with_enough_bullets(eid, minBulletsToInsert, gun__wishAmmoItemType, gun__ammoHolderIds, gun__maxAmmo)
      return

    
    gun_reload__isReloading = true
    sendEvent(eid, EventHumanStartedReload())


[es(track=gun_reload__isReloading)]
def start_reload(evt : Event; eid : EntityId; gun_reload__isReloading : bool)
  if gun_reload__isReloading
    sendEvent(eid, CmdStartNextReloadState())


[es(tag=gameClient, track=gun_reload__shouldInterrupt)]
def gun_reload_ignore_interrupt_when_not_reloading(evt : Event;
                                                   gun_reload__isReloading : bool;
                                                   var gun_reload__shouldInterrupt : bool&)
  if !gun_reload__isReloading
    gun_reload__shouldInterrupt = false

[es(on_appear, track=gun_reload__isReloading)]
def gun_reload_set_human_reload(evt : Event;
                                eid : EntityId;
                                gun_reload__isReloading : bool;
                                gun__owner : EntityId)
  query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId;
                               var human_weap__isReloading : bool&)
    if eid == human_weap__currentGunEid
      human_weap__isReloading = gun_reload__isReloading

[es]
def gun_reload_reset_human_reload_on_weap_switch(evt : EventOnSelectWeap;
                                                 human_weap__gunEids : EidList;
                                                 var human_weap__isReloading : bool&)
  
  for gunEid in human_weap__gunEids
    gun_reload_finish(gunEid)
  human_weap__isReloading = false

[es]
def gun_reload_interrupt_immediately(evt : CmdInterruptReloadImmediately; human_weap__currentGunEid : EntityId)
  gun_reload_finish(human_weap__currentGunEid)
