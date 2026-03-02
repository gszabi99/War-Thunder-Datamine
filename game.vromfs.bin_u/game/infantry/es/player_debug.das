options no_aot

require ecs
require PropsManager
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.drone_common
require %appGame.infantry.es.net_console_macro

require %appGame.wt_events


[net_console_cmd(name="player.kill")]
def player_kill_cmd(@net_hero eid : EntityId)
  sendEvent(eid, CmdRequestSuicide())

[net_console_cmd(name="player.suicide")]
def player_suicide_cmd(@net_hero eid : EntityId)
  sendEvent(eid, CmdRequestSuicide())

[console_cmd(name="player.reanimate_player")]
def console_reanimate_player()
  let targetEid = get_controlled_hero_eid()
  query(targetEid) <| $ [es] (transform : float3x4)
    let pos = transform[3]
    send_net_event(targetEid, CmdRequestReanimation(pos = pos, reanimatedEid = targetEid))

[console_cmd(name="player.simulate_knockdown")]
def console_simulate_knockdown(death_timeout = 20.0)
  let heroEid = get_controlled_hero_eid()
  query(heroEid) <| $ [es] (hitpoints__hp : float;
                            var reanimation__numReanimations : int&;
                            var reanimation__available : bool&;
                            var reanimation__deathTimeout : float&)
    reanimation__numReanimations++
    reanimation__available = true
    reanimation__deathTimeout = death_timeout
    sendEvent(heroEid, CmdApplyDamage(offender = heroEid, damageType = int(DamageType.DM_PROJECTILE), shellId = props_pack_for_net(PropsId()), gunPropsId = props_pack_for_net(PropsId()), deltaHp = (hitpoints__hp + 1.0), hitPos = float3(0., 0., 0.)))


[net_console_cmd(name="player.refill_drone_launches")]
def console_refill_drone_launches(@net_hero eid : EntityId)
  refill_drone_launches(eid)
