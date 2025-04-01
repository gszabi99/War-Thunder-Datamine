require ecs
require %game.dm.dm_events
require Weapon
require WTDamageModel
require DngHuman
require WTPhysActor
require PhysMat
require PropsManager
require app
require Unit
require net
require %appGame.es.team_common
require %game.events

[cpp_event(unicast)]
struct EventOnPhysImpulse
  atTime : float
  nodeId : int
  pos : float3
  impulse : float3

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventNotifyServerOnHitEntity
  impactRes : int
  offender : EntityId
  projPropsId : uint
  pos : float3
  dir : float3
  norm : float3
  damage : float
  collNodeId : int


[es(on_appear)]
def init_hit_fx_material(evt : Event;
                         entity__hitFxMaterialName : string;
                         var entity__hitFxMaterialId : int&)
  entity__hitFxMaterialId = get_material_id(entity__hitFxMaterialName)

def apply_damage(victimEid : EntityId;
                 offender_eid : EntityId;
                 proj_props_id : PropsId;
                 damage : float;
                 collNodeId : int)
  query(victimEid) <| $ [es] (dm_parts__dmgMult : FloatList;
                              var hitpoints__hp : float&;
                              var offenderEid : EntityId&;
                              var offenderProjPropsId : PropsId&;
                              var isAlive : bool&)
    let partDmgMult = dm_parts__dmgMult[collNodeId]
    let resDamage = damage * partDmgMult
    hitpoints__hp = max(0., hitpoints__hp - resDamage)
    if hitpoints__hp <= 0.
      offenderEid = offender_eid
      offenderProjPropsId = proj_props_id
      isAlive = false


[es(tag=server, REQUIRE=human)]
def on_entity_collision_damage(evt : EventGroundModelCollision;
                               eid : EntityId;
                               team aka victim_team : int;
                               isAlive : bool;
                               human__enemyImpulseToDamageMul = 0.08;
                               human__friendlyImpulseToDamageMul = 0.04)
  if isAlive
    query(evt.offender) <| $ [es(REQUIRE=vehicle_net_phys)] (team aka offender_team : int = -1)
      let friendly = is_teams_friendly(victim_team, offender_team)
      let impulseToDamage = friendly ? human__friendlyImpulseToDamageMul : human__enemyImpulseToDamageMul
      let damage = evt.impulse * impulseToDamage
      apply_damage(eid, evt.offender, PropsId(), damage, 0)

[es(tag=server)]
def on_entity_hit_notify(evt : EventNotifyServerOnHitEntity;
                         eid : EntityId;
                         isAlive : bool)
  if isAlive
    apply_damage(eid, evt.offender, props_unpack_from_net(evt.projPropsId), evt.damage, evt.collNodeId)

def notify_server_about_entity_hit(eid : EntityId;
                                   evt : EventOnHitEntity)
  send_net_event(eid, [[EventNotifyServerOnHitEntity impactRes = evt.impactRes,
                                                     offender = evt.offender,
                                                     projPropsId = props_pack_for_net(PropsId(evt.packedProjPropsId)),
                                                     pos = evt.pos,
                                                     dir = evt.dir,
                                                     norm = evt.norm,
                                                     damage = evt.damage, 
                                                     collNodeId =evt.collNodeId]])
[es]
def on_entity_hit(var evt : EventOnHitEntity&;
                  eid : EntityId;
                  isAlive : bool;
                  team aka victim_team = TEAM_UNASSIGNED)
  if eid == evt.offender
    return

  evt.impactRes = int(ImpactResult.PENETRATE) 

  query(evt.bullet) <| $ [es] (bullet_component : Bullet)

    let projBallistics = get_proj_ballistics(*bullet_component.bProp)
    let mass = projBallistics.mass
    let vel = bullet_component.vel
    sendEvent(eid, [[EventOnPhysImpulse atTime=get_sync_time(), nodeId=evt.collNodeId, pos=evt.pos, impulse=vel * mass]])

  if !isAlive
    return

  query(evt.offender) <| $ [es] (unit__ref : UnitRef;
                                 team aka offender_team = TEAM_UNASSIGNED)
    let unit = unit__ref.unit
    let authority = (uint(unit.role) & uint(NetRole URF_AUTHORITY)) != 0u
    let controlled = (uint(unit.role) & uint(NetRole URF_LOCAL_CONTROL)) != 0u

    let friendly = is_teams_friendly(victim_team, offender_team)
    if friendly
      evt.impactRes = int(ImpactResult.PENETRATE)
      return

    if !controlled
      return

    if authority
      apply_damage(eid, evt.offender, PropsId(evt.packedProjPropsId), evt.damage, evt.collNodeId)
    else
      notify_server_about_entity_hit(eid, evt)

[es(tag=server)]
def on_splash_entity_hit(var evt : EventSplashHitEntity&;
                         eid : EntityId;
                         isAlive : bool;
                         team aka victim_team = TEAM_UNASSIGNED)
  let damage = evt.splashDamage + evt.shatterDamage

  
  let impulseK = 100.
  let impulse = evt.dir * damage * impulseK
  sendEvent(eid, [[EventOnPhysImpulse atTime=get_sync_time(), nodeId=0, pos=evt.pos, impulse=impulse]])

  if !isAlive
    return

  query(evt.offender) <| $ [es] (unit__ref : UnitRef;
                                 team aka offender_team = TEAM_UNASSIGNED)
    let unit = unit__ref.unit
    let authority = (uint(unit.role) & uint(NetRole.URF_AUTHORITY)) != 0u
    if !authority
      return

    let friendly = is_teams_friendly(victim_team, offender_team)
    if friendly
      return

    apply_damage(eid, evt.offender, PropsId(evt.packedProjPropsId), damage, 0)


[es(tag=server)]
def on_shatter_entity_hit(var evt : EventShatterHitEntity&;
                          eid : EntityId;
                          isAlive : bool;
                          team aka victim_team = TEAM_UNASSIGNED)
  
  let impulseK = 0.1
  let impulse = evt.dir * evt.damage * impulseK
  sendEvent(eid, [[EventOnPhysImpulse atTime=get_sync_time(), nodeId=evt.collNodeId, pos=evt.pos, impulse=impulse]])

  if !isAlive
    return

  query(evt.offender) <| $ [es] (unit__ref : UnitRef;
                                 team aka offender_team = TEAM_UNASSIGNED)
    let unit = unit__ref.unit
    let authority = (uint(unit.role) & uint(NetRole.URF_AUTHORITY)) != 0u
    if !authority
      return

    let friendly = is_teams_friendly(victim_team, offender_team)
    if friendly
      return

    apply_damage(eid, evt.offender, PropsId(evt.packedProjPropsId), evt.damage, evt.collNodeId)
