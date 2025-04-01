require ecs
require app
require net
require DaWeaponProps
require DngHuman
require %game.events
require AnimV20
require math.ang
require Dacoll
require math.base
require %appGame.es.human_gun_common
require %appGame.es.multiple_guns_slot_common
require GeomNodeTree
require DagorSystem
require DagorMath
require %appGame.es.human_weap_common
require PropsManager
require Weapon



[es(on_appear)]
def projectile_trajectory_init_es(evt : Event;
                                  eid : EntityId;
                                  animchar : AnimcharBaseComponent;
                                  trajectory__startNodeName : string = "Bip01 Spine1";
                                  var trajectory__startNodeIdx : int&)
  trajectory__startNodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(trajectory__startNodeName)
  if trajectory__startNodeIdx < 0
    logerr("{eid} <{getEntityTemplateName(eid)}>: Can't find startNodeName node <{trajectory__startNodeName}>")

[es]
def launch_shell_es(evt : CmdLaunchShell;
                    eid : EntityId;
                    animchar : AnimcharBaseComponent;
                    trajectory__startNodeIdx : int;
                    human_weap__throwMode : bool;
                    human_weap__grenadeThrowDirection : float;
                    human_phys__grenadeThrowDirectionAngle : float;
                    human_phys__grenadeThrowOffset : float;
                    human_net_phys__aimDir : float3;
                    human_net_phys : HumanActor const?;
                    var human_weap__localProjectileEid : EntityId?;
                    var human_weap__lastShotGunEid : EntityId?;
                    var human_weap__lastShotAtTime : float?)
  assume launchDesc = evt.launchDesc
  let gunEid = evt.gunEid
  shell_entity_get_props(launchDesc.shellId) <| $(entProps : ShellEntityTypeProps)
    let entPropsPhysTemplName = entProps.physTemplName

    let projectileEntity = obtain_owned_projectile_entity(gunEid)
    if human_weap__lastShotAtTime != null
      *human_weap__lastShotAtTime = get_sync_time()
    if human_weap__lastShotGunEid != null
      *human_weap__lastShotGunEid = gunEid

    var explTime = 0.f
    var grenadeOwner = eid
    var grenadeRethrower = INVALID_ENTITY_ID

    
    if projectileEntity != INVALID_ENTITY_ID
      query(projectileEntity) <| $ [es] (shell__owner : EntityId const?;
                                         shell__rethrower : EntityId const?;
                                         shell__explTime : float const?)
        if shell__owner != null
          grenadeOwner = *shell__owner
        if shell__rethrower != null
          grenadeRethrower = *shell__rethrower
        if shell__explTime != null
          explTime = *shell__explTime

      if is_server()
        destroyEntity(projectileEntity)
      elif human_weap__localProjectileEid != null
        destroyEntity(*human_weap__localProjectileEid)
        *human_weap__localProjectileEid = INVALID_ENTITY_ID

    var launchTm = launchDesc.tm

    if human_weap__throwMode && human_net_phys != null
      assume curState = human_net_phys.phys.currentState
      let baseThrowPoint = human_net_phys.phys |> human_phys_calcGunPos(PrecomputedPresetMode FPV,
                                                                        curState.location |> location_makeTM(),
                                                                        curState.gunAngles.y,
                                                                        curState.leanPosition,
                                                                        curState.height)
      let throwPoint = baseThrowPoint + human_net_phys__aimDir * human_phys__grenadeThrowOffset
      let inBodyPoint = *animchar.nodeTree |> geomtree_getNodeWpos(trajectory__startNodeIdx)

      let throwAngle = -human_weap__grenadeThrowDirection * human_phys__grenadeThrowDirectionAngle
      let rotTm = make_rot_cw_zyx(float3(0.0, deg_to_rad(throwAngle), 0.0))

      let throwPointOffset = throwPoint - inBodyPoint
      var offsetLength = length(throwPointOffset)
      let throwDir = throwPointOffset * safeinv(offsetLength)
      
      offsetLength += 0.1
      var norm = float3()
      traceray_normalized(inBodyPoint, throwDir, offsetLength, norm, ETF_RI)
      
      
      offsetLength -= 0.1

      launchDesc.vel = rotTm * launchDesc.vel
      launchTm[3] = inBodyPoint + throwDir * offsetLength

    if is_server()
      if explTime == 0.f
        
        explTime = launchDesc.atTime

      create_shell_entity(entPropsPhysTemplName, launchTm, launchDesc.vel, grenadeOwner, launchDesc.shellId, launchDesc.gunPropsId,
                          launchDesc.atTime, explTime,  true,  false, grenadeRethrower, gunEid)
    
    
    
    
    
    
    
    
    
    

    
    
    

    
    
    
    
    
    
    


[es(on_appear)]
def shell_created_es(evt : Event;
                     eid : EntityId;
                     shell__expl_node : string;
                     animchar : AnimcharBaseComponent;
                     var shell__explNodeIdx : int&)
  shell__explNodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(shell__expl_node)
  if shell__explNodeIdx < 0
    logerr("{getEntityTemplateName(eid)} shell.explNodeIdx < 0 (shell__expl_node={shell__expl_node})")
    destroyEntity(eid)

[es(tag=(server, net), no_order)]
def shell_explode_server_es(info : UpdateStageInfoAct;
                            shell__shell_id__shell_id : PropsId;
                            shell__explTime : float;
                            shell__owner : EntityId;
                            shell__explNodeIdx : int;
                            animchar : AnimcharBaseComponent;
                            shell_trigger__active : bool = true;
                            var active : bool&;
                            var entity_destroyer__destroyAtTime : float&;
                            shell__destroyDelay = 1.)
  if info.curTime < shell__explTime || !active || !shell_trigger__active || shell__explTime <= 0.
    return
  active = false
  let pos = *animchar.nodeTree |> geomtree_getNodeWpos(shell__explNodeIdx)
  entity_destroyer__destroyAtTime = info.curTime + shell__destroyDelay
  do_explosion(pos, shell__shell_id__shell_id, shell__owner)


[es(tag=gameClient, before=shell_explode_server_es)]
def shell_explode_client_es(info : UpdateStageInfoAct;
                            shell__explosionFx : string;
                            shell__shell_id__shell_id : PropsId;
                            shell__explTime : float;
                            shell__owner : EntityId;
                            shell__explNodeIdx : int;
                            animchar : AnimcharBaseComponent;
                            shell_trigger__active : bool = true;
                            var animchar_render__enabled : bool&;
                            var active : bool&;
                            var entity_destroyer__destroyAtTime : float&;
                            shell__explosionFxTime = 5.;
                            shell__destroyDelay = 1.)
  if info.curTime < shell__explTime || !active || !shell_trigger__active || shell__explTime <= 0.
    return
  active = false
  animchar_render__enabled = false
  entity_destroyer__destroyAtTime = info.curTime + shell__destroyDelay

  let pos = *animchar.nodeTree |> geomtree_getNodeWpos(shell__explNodeIdx)
  var fxTm = IDENT_TM
  fxTm[3] = pos
  createEntity(shell__explosionFx) <| $(var init : ComponentsInitializer)
    set(init, "transform", fxTm)
    set(init, "entity_destroyer__destroyAtTime", info.curTime + shell__explosionFxTime)

  do_explosion(pos, shell__shell_id__shell_id, shell__owner)
