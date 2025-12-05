require ecs
require HumanPhys
require DngHuman
require RendInst
require DagorMath
require CollRes
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.door_operations_common
require soundEvent


def get_sound_pos(ri_extra : RiExtraComponent;
                  transform : float3x4)
  if riex_isRiGenExtraValid(ri_extra.handle)
    let bbox = getRIGenBBox(RendInstDesc(ri_extra.handle))
    return transform * bbox.center

  return transform[3]


[es(tag=gameClient, REQUIRE=hero)]
def push_door_es(info : ParallelUpdateFrameDelayed;
                 eid : EntityId;
                 isAlive : bool;
                 human_use_object__selectedObject : EntityId;
                 human_net_phys : HumanActor;
                 collres : CollisionResource;
                 transform : float3x4;
                 human_push_door__minAngleDot : float = 0.525;
                 human_push_door__extrapolatePosTime : float = 0.2)
  let isSprinting = (int(human_net_phys.phys.currentState.states) & int(StateFlag.ST_SPRINT)) != 0
  if !isAlive || !isSprinting
    return

  let humanEid = eid
  let humanBox = BBox3(collres.vFullBBox)
  var humanTm := transform

  query(human_use_object__selectedObject) <| $ [es(REQUIRE=isDoor)] (eid : EntityId;
                                                                     door_operations__state : int;
                                                                     door_operations__openedAngle : float;
                                                                     door_operations__closedAngle : float;
                                                                     door_operations__omniRotate : bool = false;
                                                                     var door_sound_operations__isPushing : bool&;
                                                                     ri_extra : RiExtraComponent;
                                                                     transform : float3x4)
    if !ri_extra.valid
      return
    if door_operations__state != int(DoorState.CLOSED)
      door_sound_operations__isPushing = false
      return
    let doorDir = transform[2]
    let openerDir = humanTm[0]
    let angleDot = dot(doorDir, openerDir)
    if abs(angleDot) < human_push_door__minAngleDot
      return
    if !door_operations__omniRotate && angleDot * (door_operations__openedAngle - door_operations__closedAngle) > 0.0
      return
    let riType = handle_to_ri_type(ri_extra.handle)
    let doorCollres = get_ri_gen_extra_collres(int(riType))
    if doorCollres == null
      return

    humanTm[3] += human_net_phys.phys.currentState.velocity * max(info.dt, human_push_door__extrapolatePosTime)
    let doorBox = BBox3(doorCollres.vFullBBox)
    if check_bbox3_intersection(humanBox, humanTm, doorBox, transform)
      sendEvent(humanEid, HumanUseObjectRequest(objectEid = eid))
      query(eid) <| $ [es] (rotating_door_sound__pushPath : string;
                            transform : float3x4)
        if door_sound_operations__isPushing
          return
        var handle = soundEvent::play("", rotating_door_sound__pushPath, get_sound_pos(ri_extra, transform))
        set_var(handle, "velocity", 1.)
        abandon(handle)
        door_sound_operations__isPushing = true
    else
      door_sound_operations__isPushing = false
