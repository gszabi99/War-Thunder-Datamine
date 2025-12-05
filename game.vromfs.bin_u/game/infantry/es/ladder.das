require ecs
require DngHuman
require DagorMath
require gameObject
require math.ang
require math.base
require DagorMathUtils
require %game.events


def is_suitable_ladder_angle(human_ladder__ladderTm : float3x4;
                             humanTransform : float3x4;
                             human_net_phys__ladderUseMinCos : float)
  let ladderUp = normalize(human_ladder__ladderTm[1])
  let tempDir = humanTransform[3] - human_ladder__ladderTm[3]
  let toLadderDir = normalize(basis_aware_x0z(tempDir, ladderUp))
  let c = dot(toLadderDir, normalize(human_ladder__ladderTm[0]))
  return c > human_net_phys__ladderUseMinCos

let SIN_COS_45 = 0.70710678118

def set_ladder_for_attach(eid : EntityId)
  var res = false
  query(eid) <| $ [es] (var human_ladder__ladderTm : float3x4&;
                        var human_ladder__numSteps : int&;
                        human_net_phys : HumanActor;
                        human_net_phys__isClimbing : bool;
                        human_net_phys__ladderBottomForwardTracePos : float3;
                        human_net_phys__ladderBottomBackwardTracePos : float3;
                        human_net_phys__ladderTracePos : float3 = float3(0, 1, 0);
                        human_net_phys__ladderTraceDist : float = 1.0;
                        human_net_phys__ladderUseMinCos : float = 0.0;
                        human_to_ladder_animation : Tag const?)
    assume state = human_net_phys.phys.currentState
    let canClimbLadders = (int(StateFlag.ST_CRAWL | StateFlag.ST_DOWNED) & int(state.states)) == 0
    if !canClimbLadders || state.isDetachedFromLadder || human_net_phys__isClimbing
      return
    var humanTransform : float3x4
    location_toTM(state.location, humanTransform)

    var dir = human_net_phys.phys.appliedCT.wishLookDir
    if dir.y < 0.0
      assume orientDir = human_net_phys.phys.currentState.bodyOrientDir
      dir = float3(orientDir.x, 0.0, orientDir.y)
    elif dir.y > SIN_COS_45
      assume orientDir = human_net_phys.phys.currentState.bodyOrientDir
      dir = float3(orientDir.x * SIN_COS_45, SIN_COS_45, orientDir.y * SIN_COS_45)

    let traceDist = sqrt(square(dir.y) + square(human_net_phys__ladderTraceDist))
    let fromPos = humanTransform * human_net_phys__ladderTracePos
    let toPos = fromPos + dir * traceDist

    res = find_ladder(fromPos, toPos, human_ladder__ladderTm, human_ladder__numSteps)
    
    res = res && is_suitable_ladder_angle(human_ladder__ladderTm, humanTransform, human_net_phys__ladderUseMinCos)
    if res
      return

    if human_to_ladder_animation == null && !human_net_phys__isClimbing
      let fromBottomPosForward = humanTransform * human_net_phys__ladderBottomForwardTracePos
      let fromBottomPosBackward = humanTransform * human_net_phys__ladderBottomBackwardTracePos
      let horzRay = normalize(basis_aware_x0z(dir, human_net_phys.phys.currentState.vertDirection)) * human_net_phys__ladderTraceDist
      let toBottomPosForward = fromBottomPosForward + horzRay
      let toBottomPosBackward = fromBottomPosBackward - horzRay
      res = (find_ladder(fromBottomPosForward, toBottomPosForward, human_ladder__ladderTm, human_ladder__numSteps)
          || find_ladder(fromBottomPosBackward, toBottomPosBackward, human_ladder__ladderTm, human_ladder__numSteps))
      res = res && is_suitable_ladder_angle(human_ladder__ladderTm, humanTransform, human_net_phys__ladderUseMinCos)
      if res
        res = false
        addSubTemplate(eid, "human_to_ladder_animation")
  return res


[es(after=( before_net_phys_sync), before=after_net_phys_sync,
    REQUIRE_NOT=deadEntity)]
def human_ladder_check_attach(evt : CmdPostPhysUpdate;
                              eid : EntityId;
                              possessedByPlr : EntityId;
                              beh_tree__enabled : bool = false;
                              beh_tree__usingLadders : bool = false;
                              var human_ladder__attached : bool&)
  if !human_ladder__attached && (possessedByPlr != INVALID_ENTITY_ID || (beh_tree__enabled && beh_tree__usingLadders))
    human_ladder__attached = set_ladder_for_attach(eid)

def human_ladder_check_detach(possessedByPlr : EntityId;
                              beh_tree__enabled : bool = false;
                              beh_tree__usingLadders : bool = false;
                              var human_ladder__attached : bool&;
                              var human_net_phys : HumanActor;
                              human_ladder__curLadderTm : float3x4;
                              human_ladder__ladderTm : float3x4)
  if human_ladder__attached
    
    if possessedByPlr == INVALID_ENTITY_ID && beh_tree__enabled && !beh_tree__usingLadders
      human_ladder__attached = false
      human_net_phys.phys.currentState |> human_phys_state_set_detachedFromLadder(true)
      return

    
    assume ct = human_net_phys.phys.appliedCT
    if ct |> is_control_bit_set(HumanPhysControlType.HCT_JUMP)
      human_ladder__attached = false
      human_net_phys.phys.currentState |> human_phys_state_set_detachedFromLadder(true)
      return

    
    let ladderWidth = length(human_ladder__ladderTm[2])
    let toLadderDist = length(human_ladder__ladderTm[0]) + human_net_phys.phys.collRad
    let maxAngle = atan2(ladderWidth / 2.0f + 0.1f, toLadderDist)
    let lookDir = ct.wishLookDir
    let up = normalize(human_ladder__ladderTm[1])
    let toLadderDir = human_ladder__ladderTm[3] - float3(human_net_phys.phys.currentState.location.P)
    let curAngle = angle(toLadderDir - dot(toLadderDir, up) * up, lookDir - dot(lookDir, up) * up)
    if curAngle > maxAngle
      human_ladder__attached = false
      human_net_phys.phys.currentState |> human_phys_state_set_detachedFromLadder(true)
      return

    
    if distance_sq(human_ladder__curLadderTm[3], human_ladder__ladderTm[3]) < FLT_EPSILON
      let itm = inverse(human_ladder__ladderTm)
      let localPos = itm * float3(human_net_phys.phys.currentState.location.P)
      let walkDir = dot(human_net_phys.phys.currentState.velocity, human_ladder__curLadderTm[1])
      let down = walkDir < -0.01f
      if down && localPos.y < IDENT_BBOX.boxMin.y
        human_ladder__attached = false
        human_net_phys.phys.currentState |> human_phys_state_set_detachedFromLadder(true)
        return

[es(tag=server, after=( before_net_phys_sync, check_other_ladder), before=after_net_phys_sync,
    REQUIRE_NOT=deadEntity)]
def human_ladder_check_detach_server(evt : CmdPostPhysUpdate;
                                     possessedByPlr : EntityId;
                                     beh_tree__enabled : bool = false;
                                     beh_tree__usingLadders : bool = false;
                                     var human_ladder__attached : bool&;
                                     var human_net_phys : HumanActor;
                                     human_ladder__curLadderTm : float3x4;
                                     human_ladder__ladderTm : float3x4)
  human_ladder_check_detach(possessedByPlr, beh_tree__enabled, beh_tree__usingLadders, human_ladder__attached,
    human_net_phys, human_ladder__curLadderTm, human_ladder__ladderTm)


[es(tag=gameClient, after=( before_net_phys_sync, check_other_ladder), before=after_net_phys_sync,
    REQUIRE_NOT=deadEntity, REQUIRE=hero)]
def human_ladder_check_detach_client(evt : CmdPostPhysUpdate;
                                     possessedByPlr : EntityId;
                                     var human_ladder__attached : bool&;
                                     var human_net_phys : HumanActor;
                                     human_ladder__curLadderTm : float3x4;
                                     human_ladder__ladderTm : float3x4)
  human_ladder_check_detach(possessedByPlr, false, false, human_ladder__attached,
    human_net_phys, human_ladder__curLadderTm, human_ladder__ladderTm)


[es(track=human_net_phys__isClimbing )]
def on_ladder_climb(evt : Event;
                    var human_ladder__attached : bool&;
                    human_net_phys__isClimbing : bool)
  if human_ladder__attached && human_net_phys__isClimbing
    human_ladder__attached = false


[es(before=check_other_ladder, after=human_ladder_check_attach)]
def human_ladder_update_current(evt : CmdPostPhysUpdate;
                                transform : float3x4;
                                human_ladder__attached : bool;
                                human_anim__ladder__handToLegsOffset : float3&;
                                human_ladder__ladderTm : float3x4&;
                                human_ladder__numSteps : int;
                                var human_ladder__curLadderTm : float3x4&;
                                var human_ladder__curNumSteps : int&)
  if !human_ladder__attached
    return
  if distance_sq(human_ladder__curLadderTm[3], human_ladder__ladderTm[3]) > FLT_EPSILON
    let checkedDir = human_ladder__ladderTm[3] - transform[3]
    let dir = x0z(checkedDir)
    let pos = transform[3] + human_anim__ladder__handToLegsOffset + length(human_ladder__ladderTm[0]) * normalize(dir)
    if abs(inverse(human_ladder__ladderTm) * pos).y <= IDENT_BBOX.boxMax.y
      human_ladder__curLadderTm = human_ladder__ladderTm
      human_ladder__curNumSteps = human_ladder__numSteps


[es(no_order )]
def check_other_ladder(evt : CmdPostPhysUpdate;
                       var human_ladder__ladderTm : float3x4&;
                       human_ladder__curLadderTm : float3x4;
                       var human_ladder__numSteps : int&;
                       human_ladder__attached : bool;
                       human_net_phys : HumanActor)
  let toNextLadder = human_ladder__ladderTm[3] - human_ladder__curLadderTm[3]
  let walkDir = dot(human_net_phys.phys.currentState.velocity, human_ladder__curLadderTm[1])
  if ((length_sq(toNextLadder) > FLT_EPSILON && (abs(walkDir) < FLT_EPSILON ||
      walkDir * dot(toNextLadder, human_ladder__curLadderTm[1]) >= 0.0f))
      || !human_ladder__attached)
    return
  var humanTransform : float3x4
  location_toTM(human_net_phys.phys.currentState.location, humanTransform)
  let itm = inverse(human_ladder__curLadderTm)
  let ladderHeight = length(human_ladder__curLadderTm[1])
  assume standingHeight = human_net_phys.phys.standingHeight
  let localHeight = (itm * humanTransform[3]).y * ladderHeight
  let up = walkDir > 0.0f || (length_sq(toNextLadder) < FLT_EPSILON && abs(walkDir) < FLT_EPSILON)
  let down = walkDir < 0.0f
  if localHeight + standingHeight > ladderHeight / 2.0f && up
    human_ladder__ladderTm = human_ladder__curLadderTm
    let ladderUp = normalize(human_ladder__curLadderTm[1])
    let fromPos = human_ladder__curLadderTm * float3(0., IDENT_BBOX.boxMax.y, 0.) + 0.1f * ladderUp
    let toPos = fromPos + ladderUp * standingHeight
    find_ladder(fromPos, toPos, human_ladder__ladderTm, human_ladder__numSteps)
  elif localHeight < -ladderHeight / 2.0f && down 
    human_ladder__ladderTm = human_ladder__curLadderTm
    let ladderUp = normalize(human_ladder__curLadderTm[1])
    let fromPos = human_ladder__curLadderTm * float3(0., IDENT_BBOX.boxMin.y, 0.) - 0.1f * ladderUp
    let toPos = fromPos - ladderUp * standingHeight
    find_ladder(fromPos, toPos, human_ladder__ladderTm, human_ladder__numSteps)



[es(tag=gameClient, track=(human_ladder__attached, human_net_phys__isClimbing, human_net_phys__isLadderQuickMovingDown))]
def human_attach_and_climb_track(evt : Event;
                                 eid : EntityId;
                                 human_ladder__attached : bool;
                                 human_net_phys__isClimbing : bool;
                                 human_net_phys__isLadderQuickMovingDown : bool;
                                 var human_on_ladder__animation : EntityId&)
  if human_ladder__attached && !human_net_phys__isClimbing
    destroyEntity(human_on_ladder__animation)
    let animTemplate = (human_net_phys__isLadderQuickMovingDown
                     ? "human_on_ladder_quick_descent_animation"
                     : "human_on_ladder_animation")
    human_on_ladder__animation = createEntity(animTemplate) <| $(var init)
      set(init, "game_effect__attachedTo", eid)
  elif ((human_net_phys__isClimbing || !human_ladder__attached) &&
        human_on_ladder__animation != INVALID_ENTITY_ID)
    destroyEntity(human_on_ladder__animation)
    human_on_ladder__animation = INVALID_ENTITY_ID
