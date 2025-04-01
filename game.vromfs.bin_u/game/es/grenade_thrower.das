require ecs
require ecs.common
require %game.events


require %appGame.es.grenade_thrower_common
require %appGame.es.human_weap_common
require Weapon

require DngWeapon
require DngHuman
require Weapon
require DaWeapons


require HumanPhys
require AnimV20
require DagorSystem
require WeapHelpers



require Weapon
require DagorSystem
require DagorRandom
require DaWeapons
require DagorMath
require DaWeaponProps
require BallisticsProps

def is_in_range(val : float; min : float; max : float)
  return val > min && val <= max


[es(REQUIRE=grenade_thrower, on_appear)]
def grenade_thrower_on_gun_owner_changed(evt : Event;
                                         eid : EntityId;
                                         gun__owner : EntityId)
  query(gun__owner) <| $ [es] (var multiple_guns_slots__additionalGunsEids : EidList&)
    multiple_guns_slots__additionalGunsEids |> push(eid)

[es]
def grenade_thrower_phys_es(evt : CmdWeapPhysUpdate;
                            eid : EntityId;
                            human_gun_attached : bool;
                            grenade_throw__drawTime : float;
                            grenade_throw__throwTime : float;
                            grenade_throw__cookProgressTime : float;
                            grenade_throw__throwProgressTime : float;
                            grenade_throw__fastThrowCookProgressTime : float;
                            grenade_throw__fastThrowProgressTime : float;
                            grenade_thrower__projectileEntity : EntityId = INVALID_ENTITY_ID;
                            var grenade_thrower : GrenadeThrower&)
  let isForReal = evt.isForReal
  if !isForReal
    return

  let ownerEid = evt.owner
  let atTime = evt.atTime
  let dt = evt.dt
  var gctrl = evt.gctrl
  assume gloc = evt.gloc

  query(ownerEid) <| $ [es] (var human_weap__quickThrowLastWeaponSlot : int&;
                             isInVehicle : bool = false;
                             human_vehicle__isHoldingGunPassenger : bool = false;
                             human_weap__fastThrowExclusive : bool = true;
                             human_inventory__entityUseEnd : float = -1.0;
                             var human_net_phys : HumanActor&;
                             var human_weap__throwMode : bool&)
    if !human_gun_attached && (!isInVehicle || human_vehicle__isHoldingGunPassenger) && evt.atTime > human_inventory__entityUseEnd
      sendEvent(eid, [[CmdWeapAttach toEid=ownerEid, isAttached=true, slotId=int(HUWeaponSlots EWS_GRENADE)]])

    
    if grenade_thrower.state == GrenadeThrowState GTS_READY
      verify(grenade_thrower.throwProgress == 0.0)
      if gctrl.shoot
        
        grenade_thrower.state = GrenadeThrowState GTS_DRAW
        grenade_thrower.stateStart = atTime
        grenade_thrower.stateEnd = atTime + grenade_throw__drawTime
      
      
      
    elif grenade_thrower.state == GrenadeThrowState GTS_DRAW
      if atTime > grenade_thrower.stateEnd
        
        
        verify(grenade_thrower.throwProgress <= 0.5)
        if !gctrl.shoot 
          
          grenade_thrower.state = GrenadeThrowState GTS_THROW
          grenade_thrower.stateStart = atTime
          grenade_thrower.stateEnd = atTime + grenade_throw__throwTime
        
        
        
      else
        
        
        
        verify(grenade_thrower.throwProgress >= 0.0 && grenade_thrower.throwProgress <= 0.5)
    elif grenade_thrower.state == GrenadeThrowState GTS_THROW
      if atTime > grenade_thrower.stateEnd
        
        
        verify(grenade_thrower.throwProgress <= 1.0)
        grenade_thrower.state = GrenadeThrowState GTS_READY
        if human_weap__quickThrowLastWeaponSlot >= 0
          human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(human_weap__quickThrowLastWeaponSlot))
          if human_net_phys.phys.producedCT.chosenWeapon != HUWeaponSlots EWS_GRENADE 
            human_weap__throwMode = false
          human_weap__quickThrowLastWeaponSlot = -1
      else
        
        
        
        verify(grenade_thrower.throwProgress >= 0.5 && grenade_thrower.throwProgress <= 1.0)

    let prevThrowProgress = grenade_thrower.throwProgress
    grenade_thrower.throwProgress = calc_grenade_throw_progress(grenade_thrower, atTime + dt)

    if grenade_thrower__projectileEntity != INVALID_ENTITY_ID
      let cookProgressTime = human_weap__fastThrowExclusive ? grenade_throw__fastThrowCookProgressTime : grenade_throw__cookProgressTime
      if is_in_range(cookProgressTime, prevThrowProgress, grenade_thrower.throwProgress)
        
        query(grenade_thrower__projectileEntity) <| $ [es] (
                                                            shell__explosionTimer : float;
                                                            var shell__explTime : float&;
                                                            var active : bool&)
          if active
            return
          active = true
          shell__explTime = atTime + shell__explosionTimer
          
          
          

    if !human_gun_attached
      return

    
    let throwProgressTime = human_weap__fastThrowExclusive ? grenade_throw__fastThrowProgressTime : grenade_throw__throwProgressTime
    let isThrow = (grenade_thrower.state == GrenadeThrowState GTS_THROW &&
                  is_in_range(throwProgressTime,
                              prevThrowProgress,
                              grenade_thrower.throwProgress))
    gctrl.shoot = isThrow

    let rndSeed = 0
    sendEventImmediate(eid, [[CmdGunUpdate atTime=atTime, isForReal=isForReal, seed=rndSeed, gctrl=gctrl, gloc=gloc]])

[es(on_appear)]
def grenade_thrower_shoot_node_init(evt : Event;
                                    grenade_thrower__shootNode : string;
                                    var grenade_thrower__shootNodeId : int&)
  grenade_thrower__shootNodeId = animchar_getSlotId(grenade_thrower__shootNode)
  if grenade_thrower__shootNodeId < 0
    logerr("Failed to get node {grenade_thrower__shootNode} for grenade_thrower")

[es(on_appear, REQUIRE=grenade_thrower, track=gun__owner)]
def grenade_thrower_on_owner_changed(evt : Event;
                                     eid : EntityId;
                                     gun__owner : EntityId)
  query(gun__owner) <| $ [es] (var human_weap__grenadeThrower : EntityId&)
    human_weap__grenadeThrower = eid

[es(before=human_gun_attach_es)]
def grenade_thrower_attach_es(evt : CmdWeapAttach;
                              eid : EntityId;
                              grenade_thrower__projectileEntity : EntityId;
                              gun__ammo : int;
                              grenade_thrower__shootNodeId : int;
                              var gun : Gun;
                              var human_gun_attached : bool&;
                              var grenade_thrower__selectedGrenadeVarId : int&)
  let wasHumanGunAttached = human_gun_attached
  let ownerEid = evt.toEid
  let attachFlag = evt.isAttached
  if !attach_projectile(ownerEid, eid, grenade_thrower__projectileEntity, attachFlag, gun__ammo > 0)
    return

  query(grenade_thrower__projectileEntity) <| $ [es] (grenade__selectedWeaponVar : string)
    grenade_thrower__selectedGrenadeVarId = animV20_add_enum_value(grenade__selectedWeaponVar)

  if !wasHumanGunAttached
    query(ownerEid) <| $ [es] (animchar : AnimcharBaseComponent)
      let geomNodeTree = animchar.nodeTree
      if geomNodeTree != null && grenade_thrower__shootNodeId >= 0
        gun |> gun_loadShootNode(grenade_thrower__shootNodeId, *geomNodeTree)

  if !attachFlag
    human_gun_attached = false


[es]
def grenade_thrower_detach_es(evt : CmdWeapDetach;
                              grenade_thrower__projectileEntity : EntityId)
  if grenade_thrower__projectileEntity != INVALID_ENTITY_ID
    sendEvent(grenade_thrower__projectileEntity, [[CmdWeapDetach]])

[es(tag=server, on_disappear, after=human_weap_drop_grenade_es)]  
def grenade_thrower_destroy_projectile_es(evt : Event;
                                          var grenade_thrower__projectileEntity : EntityId&)
  query(grenade_thrower__projectileEntity) <| $ [es] (active : bool)
    if !active
      destroyEntity(grenade_thrower__projectileEntity)
      grenade_thrower__projectileEntity = INVALID_ENTITY_ID

[es(tag=server, on_disappear, REQUIRE=shell__explTime)]
def grenade_thrower_on_destroy_es(evt : Event;
                                  eid : EntityId)
  find_query() <| $ [es] (var grenade_thrower__projectileEntity : EntityId&)
    if grenade_thrower__projectileEntity != eid
      return false
    grenade_thrower__projectileEntity = INVALID_ENTITY_ID
    return true


[es(tag=server, track=(gun__totalAmmo, gun__wishAmmoItemType), REQUIRE=grenade_thrower)]
def mark_slot_on_grenades(evt : Event;
                          eid, gun__owner : EntityId;
                          gun__totalAmmo, gun__wishAmmoItemType : int)
  if gun__totalAmmo == 0
    return
  query(gun__owner) <| $ [es] (itemContainer : EidList; human_weap__gunEids : EidList)
    let slotIdx = human_weap__gunEids |> find_index(eid)
    var isMarkGrenade = false
    for itemEid in itemContainer
      query(itemEid) <| $ [es(REQUIRE=item__grenadeType)] (item__id : int; var slot_attach__weaponSlotIdx : int&)
        slot_attach__weaponSlotIdx = -1
        if !isMarkGrenade && item__id == gun__wishAmmoItemType
          slot_attach__weaponSlotIdx = slotIdx
          isMarkGrenade = true


[es(tag=server, track=item__ownerEid, REQUIRE=item__grenadeType)]
def mark_slot_on_dropped_grenades(evt : Event;
                                  item__ownerEid : EntityId;
                                  var slot_attach__weaponSlotIdx : int&)
  if item__ownerEid == INVALID_ENTITY_ID
    slot_attach__weaponSlotIdx = -1


[es(tag=server, after=(human_weap_created_server_es, human_weap_reinit_guns_es, multiple_guns_slot_init), track=itemContainer, on_event=CmdReinitWeapons, on_appear)]
def grenade_thrower_init_grenade_types(evt : Event;
                                       human_weap__grenadeThrower : EntityId;
                                       itemContainer : EidList)
  query(human_weap__grenadeThrower) <| $ [es(REQUIRE=grenade_thrower)] (gun__ammoHolderIds : IntList&;
                                                                        gun__shell_prop_ids : PropsIdList&;
                                                                        gun__wishAmmoItemType : int;
                                                                        var grenade_thrower__grenadeTypesCount : int&;
                                                                        var grenade_thrower__currentGrenadeTypeIndex : int&)
    gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(grenadeItems)
      grenade_thrower__grenadeTypesCount = length(grenadeItems)
      grenade_thrower__currentGrenadeTypeIndex = grenadeItems |> find_index(gun__wishAmmoItemType)

[es(tag=server, REQUIRE=grenade_thrower, track=gun__wishAmmoItemType)]
def grenade_thrower_update_current_grenade_index(evt : Event;
                                                 gun__owner : EntityId;
                                                 gun__ammoHolderIds : IntList&;
                                                 gun__shell_prop_ids : PropsIdList&;
                                                 gun__wishAmmoItemType : int;
                                                 var grenade_thrower__currentGrenadeTypeIndex : int&)
  query(gun__owner) <| $ [es] (itemContainer : EidList)
    gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(grenadeItems)
      grenade_thrower__currentGrenadeTypeIndex = grenadeItems |> find_index(gun__wishAmmoItemType)

[es(track=grenade_thrower__grenadeTypesCount)]
def grenade_thrower_hide_on_zero_grenades(evt : Event;
                                          eid : EntityId;
                                          grenade_thrower__grenadeTypesCount : int;
                                          multiple_guns_slot_gun_hidden : Tag const?)
  if multiple_guns_slot_gun_hidden != null && grenade_thrower__grenadeTypesCount > 0
    removeSubTemplate(eid, "multiple_guns_slot_gun_hidden")
  elif multiple_guns_slot_gun_hidden == null && grenade_thrower__grenadeTypesCount <= 0
    addSubTemplate(eid, "multiple_guns_slot_gun_hidden")
