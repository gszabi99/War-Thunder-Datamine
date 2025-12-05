require ecs
require math
require AnimV20
require HumanPhys
require DngHuman
require Dacoll
require GeomNodeTree
require %appGame.infantry.es.hitpoints_common
require PropsManager

require %appGame.wt_events

def update_breath(dt : float;
                  underwater : bool;
                  eid : EntityId;
                  var human_breath__timer : float&;
                  var human_breath__asphyxiationTimer : float&;
                  transform : float3x4;
                  human_breath__maxHoldBreathTime : float;
                  human_breath__recoverBreathMult : float;
                  human_breath__damagePerTick : float;
                  human_breath__damageTick : float)
  if underwater
    human_breath__timer = min(human_breath__timer + dt, human_breath__maxHoldBreathTime)
  else
    human_breath__timer = max(human_breath__timer - dt * human_breath__recoverBreathMult, 0.0)
  if human_breath__timer >= human_breath__maxHoldBreathTime
    human_breath__asphyxiationTimer = human_breath__asphyxiationTimer + dt
    if human_breath__asphyxiationTimer > human_breath__damageTick
      human_breath__asphyxiationTimer = human_breath__asphyxiationTimer - human_breath__damageTick
      
      let invalidProps = props_pack_for_net(PropsId())
      sendEvent(eid, CmdApplyDamage(offender = eid, damageType = int(DamageType.DM_HOLD_BREATH), shellId = invalidProps, gunPropsId = invalidProps, deltaHp = human_breath__damagePerTick, hitPos = transform[3]))
      

[es(tag=server, REQUIRE_NOT=(disableUpdate, deadEntity), no_order)]
def human_breath_is_under_water_es(info : UpdateStageInfoAct;
                                   animchar : AnimcharBaseComponent;
                                   human_net_phys : HumanActor;
                                   breath_node__nodeId : int;
                                   var human_breath__isUnderWater : bool&)
  if (breath_node__nodeId < 0)
    return

  let isNotSwimming = human_net_phys.phys.currentState.standState != HUStandState.ESS_SWIM
  if isNotSwimming
    let pos = geomtree_getNodeWpos(*animchar.nodeTree, breath_node__nodeId)
    if !is_valid_water_height(traceht_water_at_time(pos, 5.f, info.curTime, human_breath__isUnderWater))
      human_breath__isUnderWater = false
  else
    human_breath__isUnderWater = human_phys_state_get_is_underwater(human_net_phys.phys.currentState)

[es(tag=server, REQUIRE_NOT=(disableUpdate, deadEntity), after=human_breath_is_under_water_es)]
def human_breath_timer_es(act : UpdateStageInfoAct;
                          eid : EntityId;
                          var human_breath__timer : float&;
                          var human_breath__asphyxiationTimer : float&;
                          human_breath__maxHoldBreathTime : float;
                          transform : float3x4;
                          human_breath__recoverBreathMult : float = 2.0;
                          human_breath__damagePerTick : float = 2.0;
                          human_breath__damageTick : float = 1.0;
                          human_breath__isUnderWater : bool)
  update_breath(act.dt, human_breath__isUnderWater, eid, human_breath__timer, human_breath__asphyxiationTimer,
                transform, human_breath__maxHoldBreathTime, human_breath__recoverBreathMult,
                human_breath__damagePerTick, human_breath__damageTick)
