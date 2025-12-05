require ecs
require %appGame.infantry.es.walker_common
require pathfinder
require %appGame.infantry.es.team_common
require DngWalkerai
require DngHuman
require DngWeapon
require DagorMath
require DaWeapons
require HumanPhys
require BehNodes
require %game.events


def interp_dir(prev : float3;
               cur : float3;
               interpK : float)
  return slerp(dir_to_quat(prev), dir_to_quat(cur), interpK) |> quat_get_forward()


def update_entity_agent(var ent : EntityAgent;
                        phys : HumanPhys;
                        cur_time : float;
                        tm : float3x4;
                        is_alive : bool;
                        reload_progress : float;
                        gun_eid : EntityId)
  ent.pos = tm[3]
  ent.isAlive = is_alive

  var readyToShoot = true
  query(gun_eid) <| $ [es] (gun__isOverheat : bool = false;
                            gun__isReady : bool = true;
                            gun__ammo : int = -1)
    if gun__isOverheat || !gun__isReady || gun__ammo == 0
      readyToShoot = false

  let interpK = get_phys_interpk_clamped(phys, cur_time)
  ent.reloading = reload_progress > 0.0
  ent.readyToShoot = readyToShoot
  ent.shootDir = interp_dir(phys.previousState.gunDir, phys.currentState.gunDir, interpK)
  let gunEid = get_human_gun_eid(ent.eid)
  ent.shootRayMat = get_int(gunEid, "gun__aimRayMatId") ?? -1


[es(on_appear, before=load_beh_tree_es)]
def walker_agent_finish_init_es(evt : Event;
                                var walker_agent : EntityAgent?;
                                var beh_tree : BehaviourTree)
  beh_tree |> beh_tree_set_user_ptr(walker_agent)


[es(before=(after_net_phys_sync, beh_tree_update_es))]
def walker_agent_es(info : UpdateStageInfoAct;
                    human_net_phys : HumanActor;
                    transform : float3x4;
                    reloadProgress : float = 0.0;
                    human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                    isAlive : bool = true;
                    walker_agent__crawlShootLocalPos : float3 = float3(0.0, 0.3, 0.0);
                    walker_agent__crouchShootLocalPos : float3 = float3(0.0, 0.6, 0.0);
                    walker_agent__standShootLocalPos : float3 = float3(0.0, 1.4, 0.0);
                    beh_tree__enabled : bool;
                    team : int = TEAM_UNASSIGNED;
                    var walker_agent : EntityAgent;
                    var beh_tree__usingLadders : bool?;
                    var agent_dangers__standShootPos : float3&;
                    var agent_dangers__standShootDir : float3&)
  if beh_tree__usingLadders != null
    *beh_tree__usingLadders = walker_agent.usingLadders
  if !beh_tree__enabled
    return

  assume phys = human_net_phys.phys
  update_entity_agent(walker_agent, phys, info.curTime, transform, isAlive, reloadProgress, human_weap__currentGunEid)
  walker_agent.shootFrom[STANCE_CRAWL] = transform * walker_agent__crawlShootLocalPos
  if phys.precompWeaponPos != null && phys.precompWeaponPos.isLoaded
    assume curState = phys.currentState
    let crouchPos = phys |> human_phys_calcGunPos(PrecomputedPresetMode.TPV, transform,
                                                  curState.gunAngles.y, curState.leanPosition, 0.0)
    walker_agent.shootFrom[STANCE_CROUCH] = crouchPos
    let standPos = phys |> human_phys_calcGunPos(PrecomputedPresetMode.TPV, transform,
                                                 curState.gunAngles.y, curState.leanPosition, 1.0)
    walker_agent.shootFrom[STANCE_STAND] = standPos
  else
    walker_agent.shootFrom[STANCE_CROUCH] = transform * walker_agent__crouchShootLocalPos
    walker_agent.shootFrom[STANCE_STAND] = transform * walker_agent__standShootLocalPos
  agent_dangers__standShootPos = walker_agent.shootFrom[STANCE_STAND]
  agent_dangers__standShootDir = walker_agent.shootDir
  walker_agent.teamId = team


[es(tag=server, after=after_guns_update_sync, before=clear_gun_launch_events_es)]
def walker_agent_track_shots_es(info : ParallelUpdateFrameDelayed;
                                gun__owner : EntityId;
                                gun_launch_events : GunLaunchEvents)
  query(gun__owner) <| $ [es] (beh_tree__enabled : bool;
                               isAlive : bool;
                               var walker_agent : EntityAgent)
    if !beh_tree__enabled || !isAlive
      return

    
    if walker_agent.aiming.lastTarget.id >= 0
      walker_agent.aiming.lastTarget.shotsCount += (length(gun_launch_events.launchEvents) == 0) ? 0 : 1










[es(tag=(dev, render), after=beh_tree_update_es, REQUIRE=customNavDebug)]
def walker_agent_debug_custom_nav_es(info : UpdateStageInfoAct)
  query() <| $ [es] (walker_agent : EntityAgent)
    if walker_agent.customNav != null
      *walker_agent.customNav |> drawDebug()
