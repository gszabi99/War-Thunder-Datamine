require ecs
require %appGame.infantry.es.hitpoints_common

require %appGame.wt_events
require math
require app
require PropsManager


[es(tag=server, track=burning__isBurning)]
def fire_damage_track_burning(evt : Event;
                              burning__isBurning : bool;
                              var burning__nextDamageAtTime : float&;
                              burning__updateInterval : float)
  burning__nextDamageAtTime = burning__isBurning ? get_sync_time() + burning__updateInterval : -1.0

[es(tag=server, no_order)]
def fire_damage(info : UpdateStageInfoAct;
                eid : EntityId;
                transform : float3x4;
                var burning__isBurning : bool&;
                var burning__force : float&;
                var burning__tickIncrement : float&;
                var burning__nextDamageAtTime : float&;
                burning__decrease : float;
                burning__damagePerSecond : float;
                burning__maxForce : float;
                burning__isPuttingOut : bool;
                burning__putOutDamageMult : float;
                burning__updateInterval : float;
                entity_mods__fireDamageMult : float = 1.0;
                burning__offender : EntityId = INVALID_ENTITY_ID;
                burning__offenderGunPropsId : PropsId const?;
                burning__offenderShellId  : PropsId const?)
  if burning__nextDamageAtTime < 0.f || info.curTime < burning__nextDamageAtTime
    return

  burning__nextDamageAtTime += burning__updateInterval
  let dt = burning__updateInterval

  let increment = burning__tickIncrement
  burning__tickIncrement = 0.0

  let pos = transform[3]
  var damagePerSecond = burning__damagePerSecond
  if burning__isPuttingOut
    damagePerSecond *= burning__putOutDamageMult
  let offender = burning__offender != INVALID_ENTITY_ID ? burning__offender : eid
  let damage = dt * damagePerSecond * entity_mods__fireDamageMult
  if damage > 0f

    var gunPropsId = PropsId()
    if burning__offenderGunPropsId != null
      gunPropsId = *burning__offenderGunPropsId
    var shellId = PropsId()
    if burning__offenderShellId != null
      shellId = *burning__offenderShellId
    sendEvent(eid, CmdApplyDamage(offender = offender, damageType = int(DamageType.DM_FIRE), shellId = props_pack_for_net(shellId), gunPropsId = props_pack_for_net(gunPropsId), deltaHp = damage, hitPos = pos))

  let burningForce = burning__force + increment - dt * burning__decrease
  burning__force = min(burning__maxForce, burningForce)
  if burning__force <= 0.0
    burning__force = 0.0
    burning__isBurning = false
