require ecs
require ecs.safe
require app
require net
require DaWeaponProps
require DngWeapon
require DngHuman
require %game.events
require AnimV20
require math.ang
require Dacoll
require math.base
require %appGame.infantry.es.human_gun_common
require %appGame.infantry.es.multiple_guns_slot_common
require %appGame.infantry.es.human_weap_common
require GeomNodeTree
require DagorSystem
require DagorMath
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.es.shell_fx_common
require PropsManager
require Weapon

require %appGame.wt_events
require WTFx


[es(on_appear)]
def projectile_trajectory_init_es(evt : Event;
                                  eid : EntityId;
                                  animchar : AnimcharBaseComponent;
                                  trajectory__startNodeName : string = "Bip01 Spine1";
                                  var trajectory__startNodeIdx : int&)
  trajectory__startNodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(trajectory__startNodeName)
  if trajectory__startNodeIdx < 0
    logerr("{eid} <{getEntityTemplateName(eid)}>: Can't find startNodeName node <{trajectory__startNodeName}>")

[es(tag=netClient, on_appear, before=projectile_replace_on_remote_appear_es)]
def client_side_projectile_es(evt : Event;
                              eid : EntityId;
                              var proj__ownerPlayerId : int&;
                              var proj__clientEntityId : uint&;
                              shell__owner : EntityId)
  let serverProjectileEid = eid
  query(shell__owner) <| $ [es] (var human_weap__localProjectilePhysEid : EntityId&)
    if human_weap__localProjectilePhysEid != INVALID_ENTITY_ID && serverProjectileEid != human_weap__localProjectilePhysEid
      proj__clientEntityId = uint(human_weap__localProjectilePhysEid)
      proj__ownerPlayerId = get_local_player_no()
      human_weap__localProjectilePhysEid = INVALID_ENTITY_ID

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
      let baseThrowPoint = human_net_phys.phys |> human_phys_calcGunPos(PrecomputedPresetMode.FPV,
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
    
    
    else
      let physTemp = getTemplateByName(entPropsPhysTemplName)
      if (human_net_phys != null && human_net_phys.isLocalControl &&
          physTemp != null && templateHasComponent(*physTemp, "proj__physObj"))
        
        query(grenadeOwner) <| $ [es] (var human_weap__localProjectilePhysEid : EntityId&)
          
          destroyEntity(human_weap__localProjectilePhysEid)

          
          if explTime == 0.f
            explTime = launchDesc.atTime + 1.f

          if explTime > launchDesc.atTime
            human_weap__localProjectilePhysEid = create_shell_entity(entPropsPhysTemplName, launchTm, launchDesc.vel,
                                                                     grenadeOwner, launchDesc.shellId, launchDesc.gunPropsId,
                                                                     launchDesc.atTime, explTime,  true,  true,
                                                                     grenadeRethrower)
          else
            human_weap__localProjectilePhysEid = INVALID_ENTITY_ID


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

[es(tag=server, on_appear)]
def launcher_add_timer_es(evt : Event;
                          explTimeAdd : float;
                          var shell__explTime : float&)
  shell__explTime += explTimeAdd

def create_shell_smoke_fx(shell__shell_id__shell_id : PropsId; pos : float3)
  proj_damage_fx_get_props(shell__shell_id__shell_id) <| $(dmgProps : ProjDamageFxProps)
    if dmgProps.smokeShell
      let fxName := get_name_by_type(dmgProps.smokeFxId)
      if empty(fxName)
        logerr("incorrect fx name for smoke grenade")
        return
      create_smoke(dmgProps.smokeActivateTime, dmgProps.smokeDeactivateTime,
        dmgProps.smokeTime, pos, dmgProps.smokeShellRad,
        49u,
        dmgProps.smokeExplosionFxId, false, fxName);


def clear_projectile_entity_impl(eid : EntityId;
                                 human_weap__grenadeThrower : EntityId;
                                 human_weap__gunEids : EidList;
                                 var human_weap__throwMode : bool?;
                                 var grenade_thrower__projectileEntity : EntityId&;
                                 var grenade_thrower : GrenadeThrower)
  let projEid = obtain_grenade_thrower_projectile_entity(grenade_thrower__projectileEntity)
  if projEid != INVALID_ENTITY_ID
    destroyEntity(projEid)
    grenade_thrower.state = GrenadeThrowState.GTS_READY
    grenade_thrower.throwProgress = 0.0
    query(eid) <| $ [es] (var human_net_phys : HumanActor)
      if human_weap__throwMode != null
        clear_throw_mode(eid, human_weap__grenadeThrower, human_weap__gunEids, *human_weap__throwMode, human_net_phys.phys)


def clear_projectile_entity(eid : EntityId;
                            proj_eid : EntityId)
  query(eid) <| $ [es] (human_weap__grenadeThrower : EntityId;
                        human_weap__gunEids : EidList;
                        var human_weap__throwMode : bool?)
    let gunEidsCount = length(human_weap__gunEids)
    for i in range(gunEidsCount)
      query(human_weap__gunEids[i]) <| $ [es] (var grenade_thrower__projectileEntity : EntityId&;
                                               var grenade_thrower : GrenadeThrower)
        if (grenade_thrower__projectileEntity == proj_eid)
          clear_projectile_entity_impl(eid, human_weap__grenadeThrower, human_weap__gunEids, human_weap__throwMode,
                                       grenade_thrower__projectileEntity, grenade_thrower)


[es(tag=(server, net), no_order)]
def shell_explode_server_es(info : UpdateStageInfoAct;
                            eid : EntityId;
                            shell__shell_id__shell_id : PropsId;
                            shell__explTime : float;
                            shell__owner : EntityId;
                            shell__rethrower : EntityId;
                            shell__explNodeIdx : int;
                            transform : float3x4;
                            shell_trigger__active : bool = true;
                            proj__velocity : float3 = float3();
                            var animchar : AnimcharBaseComponent;
                            var active : bool&;
                            var entity_destroyer__destroyAtTime : float&;
                            shell__destroyDelay = 1.;
                            animchar__turnDir = false;
                            animchar_attach__attachedTo : EntityId = INVALID_ENTITY_ID)
  if info.curTime < shell__explTime || !active || !shell_trigger__active || shell__explTime <= 0.
    return
  active = false
  if !animchar_attach__attachedTo
    var resultTm = transform
    if animchar__turnDir
      resultTm[0] = transform[2]
      resultTm[2] = -transform[0]
    animchar_set_tm(animchar, resultTm, true) 
    animchar |> animchar_recalc_wtm()
  let pos = *animchar.nodeTree |> geomtree_getNodeWpos(shell__explNodeIdx)
  entity_destroyer__destroyAtTime = info.curTime + shell__destroyDelay

  do_explosion(pos, shell__shell_id__shell_id, shell__owner)
  create_shell_smoke_fx(shell__shell_id__shell_id, pos)
  sendEvent(eid, EventShellExplodedServer(pos = pos, vel = proj__velocity))

  if shell__rethrower != INVALID_ENTITY_ID
    clear_projectile_entity(shell__rethrower, eid)
  elif shell__owner != INVALID_ENTITY_ID
    clear_projectile_entity(shell__owner, eid)

def get_explosion_fx_name_based_on_floor(pos : float3;
                                         fx_info_eid : EntityId;
                                         is_under_water : bool;
                                         var riex_handle : riex_handle_t&)
  var res : string
  query(fx_info_eid) <| $ [es] (shell_explosion_fx__traceLength : float;
                                shell_explosion_fx__default : string;
                                shell_explosion_fx__info : Object const?;
                                shell_explosion_fx__tracePosOffset : float = 0.0)
    let matName = is_under_water ? "water3d" : get_floor_material_name(pos + shell_explosion_fx__tracePosOffset * float3(0, 1, 0), shell_explosion_fx__traceLength, riex_handle)
    let obj = shell_explosion_fx__info?[matName] ?as Object
    res = obj?.fx ?? shell_explosion_fx__default
  return res

def spawn_effect(pos : float3;
                 fx_name : string)
  if empty(fx_name) || fx_name == "-"
    return
  var fxTm = IDENT_TM
  fxTm[3] = pos
  createEntity(fx_name) <| $(var init : ComponentsInitializer)
    set(init, "transform", fxTm)

def spawn_explosion_effect(fx_info_template : string; pos : float3)
  let fxInfoEid = getSingletonEntity(fx_info_template)
  var riExtraHandle : riex_handle_t
  var isUnderWater = false
  let posAdjusted = get_adjusted_pos_for_effect(pos, isUnderWater)
  let fxName = get_explosion_fx_name_based_on_floor(pos, fxInfoEid, isUnderWater, riExtraHandle)
  spawn_effect(posAdjusted, fxName)

[es(tag=gameClient, before=shell_explode_server_es)]
def shell_explode_client_es(info : UpdateStageInfoAct;
                            eid : EntityId;
                            shell__shell_id__shell_id : PropsId;
                            shell__explTime : float;
                            shell__owner : EntityId;
                            shell__rethrower : EntityId;
                            shell__explNodeIdx : int;
                            shell_explosion_fx__infoTemplate : string;
                            animchar : AnimcharBaseComponent;
                            shell_trigger__active : bool = true;
                            proj__velocity : float3 = float3();
                            clientSide : Tag const?;
                            var animchar_render__enabled : bool&;
                            var active : bool&;
                            var entity_destroyer__destroyAtTime : float&;
                            shell__destroyDelay = 1.)
  if info.curTime < shell__explTime || !active || !shell_trigger__active || shell__explTime <= 0.
    return
  active = false
  animchar_render__enabled = false
  entity_destroyer__destroyAtTime = info.curTime + shell__destroyDelay

  let pos = *animchar.nodeTree |> geomtree_getNodeWpos(shell__explNodeIdx)

  if clientSide == null
    spawn_explosion_effect(shell_explosion_fx__infoTemplate, pos)

  do_explosion(pos, shell__shell_id__shell_id, shell__owner)
  if is_server()
    sendEvent(eid, EventShellExplodedServer(pos = pos, vel = proj__velocity))
    create_shell_smoke_fx(shell__shell_id__shell_id, pos)

    if shell__rethrower != INVALID_ENTITY_ID
      clear_projectile_entity(shell__rethrower, eid)
    elif shell__owner != INVALID_ENTITY_ID
      clear_projectile_entity(shell__owner, eid)

[es(REQUIRE=shell__explodeOnContact, tag=server)]
def explode_shell_on_contact(evt : EventProjectilePhysContact;
                             eid : EntityId;
                             var shell__active : bool&;
                             var shell__launchTime : float&;
                             shell__owner : EntityId;
                             shell__shell_id__shell_id : PropsId;
                             var entity_destroyer__destroyAtTime : float&;
                             shell__destroyDelay = 0.5)
  if !shell__active
    return

  let curTime = get_sync_time()
  shell__active = false
  entity_destroyer__destroyAtTime = curTime + shell__destroyDelay

  if shell__launchTime < 0.0
    shell__launchTime = curTime

  send_net_event(eid,
                 EventShellExplodeNetClient(pos = evt.pos,
                                            shellId = props_pack_for_net(shell__shell_id__shell_id),
                                            shellOwner = shell__owner))

  do_explosion(evt.pos, shell__shell_id__shell_id, shell__owner)
  sendEvent(eid, EventShellExplodedServer(pos = evt.pos, vel = evt.vel))

[es(tag=netClient, REQUIRE=shell__explodeOnContact)]
def explode_shell_on_server_shell_contact(evt : EventShellExplodeNetClient)
  do_explosion(evt.pos, PropsId(evt.shellId), evt.shellOwner)

[es(tag=gameClient, REQUIRE=shell__explodeOnContact)]
def explode_fx_on_server_shell_contact(evt : EventShellExplodeNetClient;
                                       shell_explosion_fx__infoTemplate : string)
  spawn_explosion_effect(shell_explosion_fx__infoTemplate, evt.pos)
