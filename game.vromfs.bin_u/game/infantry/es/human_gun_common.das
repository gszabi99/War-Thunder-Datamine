module human_gun_common shared
require ecs
require net
require ecs.extra_set
require %game.events
require PropsManager
require DaWeapons


def try_reload_empty_gun(gun : Gun;
                         gun_eid : EntityId;
                         gun__autoReload : bool;
                         gun__manuallyUnloaded : bool;
                         shoot : bool;
                         is_for_real : bool;
                         gun_ammo : int;
                         gun_owner : EntityId;
                         at_time : float)
  if get_bool(gun_eid, "gun_reload__isReloading") ?? false
    return

  if is_server() && is_for_real && gun_ammo == 0
    let reloadOnShoot = get_bool(gun_owner, "human_weap__reloadOnShoot") ?? true
    let reloadOnEmptyMag = get_bool(gun_owner, "human_weap__reloadOnEmptyMag") ?? true
    var shouldReload = false

    if reloadOnShoot
      shouldReload ||= !gun.appliedControls.shoot && shoot

    if reloadOnEmptyMag && gun__autoReload && !gun__manuallyUnloaded
      shouldReload ||= !shoot

    let isAI = get_bool(gun_owner, "beh_tree__enabled") ?? false
    if isAI
      let reloadBlockedForAI = get_bool(gun_owner, "human_weap__reloadBlockedForAI") ?? false
      if reloadBlockedForAI
        shouldReload = false

    if shouldReload
      sendEventImmediate(gun_owner, CmdRequestReload(atTime = at_time, gunEid = gun_eid, isQuick = false))

def create_shell_entity(templ_name : string; in_tm : float3x4; start_vel : float3;
                        owner_eid : EntityId; shell_id : PropsId | #; gun_props_id : PropsId | #;
                        launch_time : float; expl_time : float; in_active : bool;
                        client_side : bool; rethrower_eid : EntityId; gun_eid : EntityId = INVALID_ENTITY_ID;
                        turn_dir : bool = true)
  var resultTm = in_tm
  if turn_dir
    resultTm[0] = in_tm[2]
    resultTm[2] = -in_tm[0]
  return createEntity("{templ_name}+{client_side ? "client_side" : "replicating+projectile_client_entity"}") <| $(var init)
    init |> set("transform", resultTm)
    init |> set("start_vel", start_vel)
    init |> set("shell__shell_id__shell_id", shell_id)
    init |> set("shell__gun_props_id", gun_props_id)
    init |> set("shell__owner", owner_eid)
    init |> set("shell__rethrower", rethrower_eid)
    init |> set("shell__launchAtTime", launch_time)
    init |> set("shell__explTime", expl_time)
    init |> set("animchar_render__enabled", in_active)
    init |> set("active", in_active)
    init |> set("shell__gunEid", gun_eid)
    if !!owner_eid
      init |> set("ignoreObjs__time", 0.01f)
      init |> set("ignoreObjs__eids", [owner_eid])
