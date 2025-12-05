require ecs
require app
require net
require %game.events

require %appGame.wt_events
require DaWeapons
require PropsManager
require inventory
require %appGame.infantry.es.human_gun_common
require %appGame.infantry.es.human_reload_common

[es]
def subsidiary_gun_phys_es(evt : CmdWeapPhysUpdate; eid, subsidiaryGunEid : EntityId)
  if !evt.isForReal
    return

  var subsidaryActive = false
  query(subsidiaryGunEid) <| $ [es] (gun : Gun; gun__autoReload : bool; gun__manuallyUnloaded : bool; gun__ammo : int; weapon_mod__active : bool; weapon_mod__wantActiveState : bool)
    if weapon_mod__wantActiveState
      try_reload_empty_gun(gun, subsidiaryGunEid, gun__autoReload, gun__manuallyUnloaded, evt.gctrl.shoot, evt.isForReal, gun__ammo, evt.owner, (evt.atTime - evt.dt))
    subsidaryActive = weapon_mod__active

  let gctrl = GunControls(shoot = false, wishShoot = false, boltActionMult = evt.gctrl.boltActionMult, timeStep = evt.gctrl.timeStep)
  sendEventImmediate(eid, CmdGunUpdate(atTime = evt.atTime, isForReal = evt.isForReal, seed = phys_time_to_seed(evt.atTime), gctrl = gctrl, gloc = evt.gloc))

  
  
  
  
  if subsidaryActive
    sendEventImmediate(subsidiaryGunEid, CmdGunUpdate(atTime = evt.atTime, isForReal = evt.isForReal, seed = phys_time_to_seed(evt.atTime), gctrl = evt.gctrl, gloc = evt.gloc))

[es(tag=server, after=subsidiary_gun_phys_es)]
def ramrod_subsidiary_gun_server_reload_es(evt : CmdWeapPhysUpdate;
                                           eid : EntityId;
                                           subsidiaryGunEid : EntityId;
                                           gun__owner : EntityId;
                                           var gun : Gun)
  query(subsidiaryGunEid) <| $ [es(REQUIRE=ramrodGun)] (var weapon_mod__active : bool&;
                                                        var gun__totalAmmo : int&;
                                                        var gun__serverAmmo : int&;
                                                        gun__shell_prop_ids : PropsIdList;
                                                        var gun__ammoHolderEid : EntityId&;
                                                        var gun__curShellId : PropsId;
                                                        var gun__ammoToReloadCount : int&;
                                                        var gun__isAmmoLoaded : bool&;
                                                        gun__ammo : int)
    if evt.gctrl.shoot
      gun.curState.loaded = false
      weapon_mod__active = false
      if gun__ammo == 0 && gun__totalAmmo > 0
        query(gun__owner) <| $ [es] (var itemContainer : EidList)
          find_ammo_for_gun(subsidiaryGunEid, itemContainer, INVALID_ITEM_ID, 0) <| $(ammoForGun : AmmoItemForGunResult)
            if ammoForGun.itemIndex < 0
              return
            gun__curShellId = gun__shell_prop_ids[0]
            gun__ammoHolderEid = itemContainer[ammoForGun.itemIndex]
            itemContainer |> erase(ammoForGun.itemIndex)
            gun__ammoToReloadCount = ammoForGun.ammoCount
            gun__isAmmoLoaded = true
            gun__totalAmmo -= gun__ammoToReloadCount
            gun__serverAmmo = gun__ammoToReloadCount
            sendEventImmediate(subsidiaryGunEid, CmdLoadAmmo(ammoNum = gun__ammoToReloadCount))
            send_net_event(eid, CmdServerLoadAmmo(ammoNum = gun__ammoToReloadCount))

[es(tag=netClient)]
def ramrod_subsidiary_gun_client_reload_es(evt : CmdServerLoadAmmo;
                                           subsidiaryGunEid : EntityId;
                                           var gun : Gun)
  query(subsidiaryGunEid) <| $ [es] (var gun__ammo : int&;
                                     gun__serverAmmo : int)
    gun.curState.loaded = false
    gun__ammo = gun__serverAmmo

[es(tag=server, on_appear, after=gun_mod_custom_props_init_es, before=subsidiary_gun_activation_es, REQUIRE=subsidiaryGun)]
def subsidiary_gun_load_on_create_es(evt : Event;
                                     eid : EntityId;
                                     gun__owner : EntityId;
                                     gun__ammo : int;
                                     gun__shell_prop_ids : PropsIdList;
                                     var gun__curShellId : PropsId;
                                     var gun__isAmmoLoaded : bool&;
                                     var gun__ammoToReloadCount : int&;
                                     var gun__ammoHolderEid : EntityId&;
                                     var gun__totalAmmo : int&)
  if gun__ammo == 0 && gun__totalAmmo > 0
    query(gun__owner) <| $ [es] (var itemContainer : EidList)
      find_ammo_for_gun(eid, itemContainer, INVALID_ITEM_ID, 0) <| $(ammoForGun : AmmoItemForGunResult)
        if ammoForGun.itemIndex < 0
          return
        gun__curShellId = gun__shell_prop_ids[0]
        gun__ammoHolderEid = itemContainer[ammoForGun.itemIndex]
        itemContainer |> erase(ammoForGun.itemIndex)
        gun__ammoToReloadCount = ammoForGun.ammoCount
        gun__isAmmoLoaded = true
        gun__totalAmmo -= gun__ammoToReloadCount
        sendEventImmediate(eid, CmdLoadAmmo(ammoNum = gun__ammoToReloadCount))

[es(tag=input, track=(gun__ammo, gun__serverAmmo), REQUIRE=subsidiaryGun, REQUIRE_NOT=ramrodGun)]
def weapon_mod_no_ammo_es(evt : Event;
                          gun__serverAmmo : int;
                          gun__ammo : int;
                          gun__totalAmmo : int;
                          gun__owner : EntityId;
                          animchar_attach__attachedTo : EntityId)
  if gun__totalAmmo == 0 && gun__ammo == 0 && gun__serverAmmo == 0
    query(gun__owner) <| $ [es(REQUIRE=hero)] (human_weap__currentGunEid : EntityId;
                                               human_weap__currentGunSlot : int)
      if human_weap__currentGunEid == animchar_attach__attachedTo
        sendEvent(gun__owner, CmdWeapModToggle(slotId = human_weap__currentGunSlot))

[es(tag=server, on_appear, track=weapon_mod__active, REQUIRE=subsidiaryGun)]
def subsidiary_gun_activation_es(evt : Event; eid : EntityId; animchar_attach__attachedTo : EntityId;
                                 weapon_mod__active : bool)
  let tpl = getEntityTemplateName(animchar_attach__attachedTo)
  let subEid = animchar_attach__attachedTo
  if weapon_mod__active
    remote_recreate_entity_from(subEid, "{tpl}+gun_with_subsidiary") <| $(var init)
      set(init, "subsidiaryGunEid", eid)
      set(init, "oldTemplateName", tpl)
  else
    query(animchar_attach__attachedTo) <| $ [es] (oldTemplateName : string)
      remote_recreate_entity_from(animchar_attach__attachedTo, oldTemplateName)

[es(tag=server, on_disappear, REQUIRE=subsidiaryGun)]
def subsidiary_gun_destroyed_es(evt : Event; animchar_attach__attachedTo : EntityId; oldTemplateName : string)
  remote_recreate_entity_from(animchar_attach__attachedTo, oldTemplateName)

[es(REQUIRE=subsidiaryGun, REQUIRE_NOT=weapon_mod__alwaysVisible, no_order)]
def subsidiary_gun_visibility_es(act : UpdateStageInfoAct;
                                 gun__owner : EntityId;
                                 weapon_mod__active : bool;
                                 ramrodGun : Tag const?;
                                 var gun__visible : bool&;
                                 var animchar_render__enabled : bool&)
  query(gun__owner) <| $ [es] (human_weap__weapModActivateStartTime : float; menuChar : bool = false)
    gun__visible = ramrodGun == null && (
      weapon_mod__active || human_weap__weapModActivateStartTime > 0.0f || menuChar)

    animchar_render__enabled = gun__visible
