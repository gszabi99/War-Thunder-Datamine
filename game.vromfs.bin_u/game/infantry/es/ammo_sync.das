require app
require ecs
require %game.events


[es(tag=net, tag=server, track=gun__ammo)]
def update_server_ammo_for_gun_es(evt : Event; var gun__serverAmmo : int&; gun__ammo : int)
  gun__serverAmmo = gun__ammo


[es(tag=net, tag=gameClient)]
def load_client_ammo_es(evt : CmdLoadAmmo;
                        var gun__delayedAmmoSyncTime : float&;
                        var gun__ammoSyncReloadLock : bool&;
                        gun__ammoSyncDelay : float = 0.6)
  gun__delayedAmmoSyncTime = get_sync_time() + gun__ammoSyncDelay
  gun__ammoSyncReloadLock = true


[es(tag=net, tag=gameClient, on_event=CmdUnloadAmmo)]
def unload_client_ammo_es(evt : Event; var gun__delayedAmmoSyncTime : float&; gun__ammoSyncDelay : float = 0.6)
  gun__delayedAmmoSyncTime = get_sync_time() + gun__ammoSyncDelay


[es(tag=net, tag=gameClient, track=gun__serverAmmo, REQUIRE_NOT=skip_common_weap_phys_update)]
def sync_ammo_with_server_es(evt : Event;
                             gun__owner : EntityId;
                             var gun__ammo : int&;
                             gun__maxAmmo : int;
                             var gun__delayedAmmoSyncTime : float&;
                             var gun__ammoSyncReloadLock : bool&;
                             gun__serverAmmo : int;
                             gun__ammoSyncDelay : float = 0.6)
  if has(gun__owner, "hero")
    if gun__serverAmmo == gun__maxAmmo
      gun__ammoSyncReloadLock = false
    if gun__serverAmmo <= gun__ammo && !gun__ammoSyncReloadLock
      gun__ammo = gun__serverAmmo
      gun__delayedAmmoSyncTime = -1.0
    else
      gun__delayedAmmoSyncTime = get_sync_time() + gun__ammoSyncDelay
  else
    gun__ammo = gun__serverAmmo


[es(tag=net, tag=gameClient, track=gun__serverAmmo, REQUIRE=skip_common_weap_phys_update)]
def sync_ammo_with_server_custom_es(evt : Event; var gun__ammo : int&; gun__serverAmmo : int)
  gun__ammo = gun__serverAmmo


[es(tag=net, tag=gameClient, after=update_phys_es, REQUIRE_NOT=skip_common_weap_phys_update)]
def delayed_sync_ammo_with_server_es(info : ParallelUpdateFrameDelayed;
                                     eid : EntityId;
                                     gun__ammo : int;
                                     var gun__delayedAmmoSyncTime : float&;
                                     gun__serverAmmo : int)
  if gun__ammo != gun__serverAmmo && gun__delayedAmmoSyncTime >= 0.0 && info.curTime >= gun__delayedAmmoSyncTime
    gun__delayedAmmoSyncTime = -1.0
    set(eid, "gun__ammo", gun__serverAmmo) 
