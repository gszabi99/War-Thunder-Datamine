require ecs
require AnimV20
require GeomNodeTree
require EffectorData
require DngHumanAnim
require DngHuman
require PhysVars
require math.base
require DagorMath
require DagorMathUtils
require %appGame.infantry.es.human_common
require %game.events


[es(on_appear)]
def human_to_ladder_anim_on_appear(evt : Event;
                                   human_net_phys : HumanActor;
                                   human_ladder__ladderTm : float3x4;
                                   human_to_ladder_animation__animationVelocity : float;
                                   var human_to_ladder_animation__startPos : float3&;
                                   var human_to_ladder_animation__startOrient : float3&;
                                   var human_to_ladder_animation__wishPos : float3&;
                                   var human_to_ladder_animation__wishOrient : float3&;
                                   var human_to_ladder_animation__duration : float&)
  let startPos = float3(human_net_phys.phys.currentState.location.P)
  let wishPos = startPos - float3(0.0, human_net_phys.phys.standingHeight, 0.0)

  human_to_ladder_animation__startPos = startPos
  human_to_ladder_animation__startOrient = human_net_phys.phys.currentState.gunDir
  human_to_ladder_animation__wishPos = wishPos
  human_to_ladder_animation__wishOrient = -human_ladder__ladderTm[0]
  human_to_ladder_animation__duration = length(wishPos - startPos) / human_to_ladder_animation__animationVelocity


[es( before=after_net_phys_sync, REQUIRE_NOT=deadEntity)]
def human_to_ladder_anim_transfer_to_ladder_pos(evt : CmdPostPhysUpdate;
                                                human_to_ladder_animation__startPos : float3;
                                                human_to_ladder_animation__wishPos : float3;
                                                human_to_ladder_animation__duration : float;
                                                var human_to_ladder_animation__lastTimePos : float&;
                                                var human_net_phys : HumanActor)
  if human_to_ladder_animation__lastTimePos >= human_to_ladder_animation__duration
    return

  let interpK = float3(safediv(human_to_ladder_animation__lastTimePos, human_to_ladder_animation__duration))
  let curPos = lerp(human_to_ladder_animation__startPos, human_to_ladder_animation__wishPos, interpK)
  move_human_to_wish_pos(human_net_phys, curPos)

  human_to_ladder_animation__lastTimePos += evt.dt


[es(no_order )]
def human_to_ladder_anim_transfer_to_ladder_orient(info : UpdateStageInfoAct;
                                                   eid : EntityId;
                                                   human_to_ladder_animation__startOrient : float3;
                                                   human_to_ladder_animation__wishOrient : float3;
                                                   human_to_ladder_animation__duration : float;
                                                   human_to_ladder_animation__lastTimePos : float;
                                                   var human_to_ladder_animation__lastTimeOrient : float&;
                                                   var human_ladder__attached : bool&;
                                                   var human_net_phys : HumanActor)
  if human_to_ladder_animation__lastTimeOrient >= human_to_ladder_animation__duration
    if human_to_ladder_animation__lastTimePos >= human_to_ladder_animation__duration
      human_ladder__attached = true
      removeSubTemplate(eid, "human_to_ladder_animation")
    return

  let interpK = safediv(human_to_ladder_animation__lastTimeOrient, human_to_ladder_animation__duration)
  let q = slerp(dir_to_quat(human_to_ladder_animation__startOrient), dir_to_quat(human_to_ladder_animation__wishOrient), interpK)
  human_control_state_set_wish_look_dir(human_net_phys.phys.producedCT, quat_get_forward(q))
  human_control_state_set_wish_shoot_dir(human_net_phys.phys.producedCT, quat_get_forward(q))

  human_to_ladder_animation__lastTimeOrient += info.dt
