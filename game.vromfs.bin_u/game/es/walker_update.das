require ecs
require walkerai
require DngWalkerai
require DagorDataBlock

require BehNodes


def set_walker_agent_shoot_time(var beh_tree : BehaviourTree&; combatShootTime, combatCooldownTime : float2)
  beh_tree.blackBoard |> set("shootTime", combatShootTime)
  beh_tree.blackBoard |> set("cooldownTime", combatCooldownTime)

[es(tag=server, on_appear, track=human_weap__currentGunEid)]
def track_walker_shoot_time(evt : Event; isAlive : bool; human_weap__currentGunEid : EntityId; var beh_tree : BehaviourTree&)
  if !isAlive
    return
  var found = false
  query(human_weap__currentGunEid) <| $ [es] (combatShootTime, combatCooldownTime : float2)
    set_walker_agent_shoot_time(beh_tree, combatShootTime, combatCooldownTime)
    found = true
  if !found
    set_walker_agent_shoot_time(beh_tree, float2(-1), float2(-1))

[es(tag=server, on_appear)]
def created_weapon_set_walker_shoot_time(evt : Event; gun__owner : EntityId; combatShootTime, combatCooldownTime : float2)
  query(gun__owner) <| $ [es] (var beh_tree : BehaviourTree&)
    set_walker_agent_shoot_time(beh_tree, combatShootTime, combatCooldownTime)

[es(tag=server, no_order)]
def track_walker_human_velocity(act : UpdateStageInfoAct; human_net_phys__velocity : float3; human_anim__vehicleSelected : EntityId; var walker_agent : EntityAgent)
  walker_agent.velocity = get_Point3(human_anim__vehicleSelected, "net_phys__currentStateVelocity") ?? human_net_phys__velocity
