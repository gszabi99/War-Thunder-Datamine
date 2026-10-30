require ecs
require DngNet
require danetlibs.dm.dm_events
require vehicle_sounds_net.modules.vehicle_sounds_net_events


[es(tag=server, REQUIRE=helicopterHitNetSound)]
def helicopter_send_hit_sound_projectile(evt : EventOnHitByProjectile; eid : EntityId)
  send_net_event(eid, CmdPlayProjectileHitSound(
    localHitPos = evt.localHitPos,
    localNormal = evt.localNormal,
    caliber = evt.caliber,
    bulletTypeId = evt.bulletTypeId,
    nodeId = evt.nodeId,
    pierced = evt.pierced
  ))


[es(tag=server, REQUIRE=helicopterHitNetSound)]
def helicopter_send_ricochet_sound_projectile(evt : EventOnRicochet; eid : EntityId)
  send_net_event(eid, CmdPlayProjectileRicochetSound(
    localHitPos = evt.localHitPos,
    caliber = evt.caliber
  ))
