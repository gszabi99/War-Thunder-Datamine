require ecs
require GeomNodeTree
require EffectorData
require DngHuman
require PhysVars
require math.base
require DagorMath
require DagorMathUtils
require %game.events


def set_current_ladder_for_anim(human_eid : EntityId)
  query(human_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (human_ladder__ladderTm : float3x4&;
                                                      human_ladder__numSteps : int;
                                                      var human_ladder__curLadderTm : float3x4&;
                                                      var human_ladder__curNumSteps : int&)
    human_ladder__curLadderTm = human_ladder__ladderTm
    human_ladder__curNumSteps = human_ladder__numSteps


def set_hero_draw_above_geometry(human_eid : EntityId; mode : bool)
  query(human_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (var hero__isDrawAboveGeometry : bool&)
    hero__isDrawAboveGeometry = mode


[es(tag=gameClient, REQUIRE=human_on_ladder_animation, after=update_phys_es, before=animchar_es)]
def human_ladder_update_animation(info : ParallelUpdateFrameDelayed;
                                  game_effect__attachedTo : EntityId)
  assume attachedTo = game_effect__attachedTo
  query(attachedTo) <| $ [es(REQUIRE_NOT=deadEntity)] (human_anim__ladderProgressVarId : int;
                                                       human_net_phys : HumanActor;
                                                       var animchar_effectors__effectorsState : Object;
                                                       human_ladder__curLadderTm : float3x4;
                                                       human_ladder__curNumSteps : int;
                                                       transform : float3x4&;
                                                       var phys_vars : PhysVars;
                                                       human_anim__ladder__handToLegsOffset : float3&;
                                                       human_anim__ladder__effectorOffset : float3&;
                                                       animchar__visible = true;
                                                       human_ladder__attached : bool;
                                                       animchar__actWhenInvisible = false;
                                                       human_anim__ladder__handSidesOffset : float  = 0.35f)
    if (!animchar__visible && !animchar__actWhenInvisible) || !human_ladder__attached
      return
    var rightHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "r.hand")
    var leftHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "l.hand")

    let d_wofs = geomtree_calc_optimal_wofs(transform[3])
    let isQuickDescending = human_phys_state_get_isLadderQuickMovingDown(human_net_phys.phys.currentState)

    let ladderItm = inverse(human_ladder__curLadderTm)
    let ladderZScale = length(human_ladder__curLadderTm[2])
    let ladderZSign = sign(dot(human_ladder__curLadderTm[2], transform[2]))
    let ladderWidth = length(human_ladder__curLadderTm[0])
    let ladderUp = normalize(human_ladder__curLadderTm[1])
    let tempDir = human_ladder__curLadderTm[3] - transform[3]
    let toLadderDir = normalize(basis_aware_x0z(tempDir, ladderUp))
    let handSidesOffset = isQuickDescending ? 1.0 : human_anim__ladder__handSidesOffset
    let lhandZposInLadderTransform = ladderZSign * handSidesOffset * safeinv(ladderZScale) * 0.5f
    let rhandZposInLadderTransform = -ladderZSign * handSidesOffset * safeinv(ladderZScale) * 0.5f
    let topHandPos = transform[3] + human_anim__ladder__handToLegsOffset + ladderWidth / 2.f * toLadderDir
    let posInLadderTransform = ladderItm * topHandPos
    let vertPosInLadderTransform = posInLadderTransform.y + 0.5f
    var ladderProgress = vertPosInLadderTransform * float(human_ladder__curNumSteps - 1) * 0.5f 

    let step = safeinv(float(human_ladder__curNumSteps - 1))
    let rHandPosY = (floor(ladderProgress) * 2.0 + 1.0) * step - 0.5
    let lHandPosY = (floor(ladderProgress) * 2.0) * step - 0.5
    let rHandPos = float3(0.f, isQuickDescending ? posInLadderTransform.y : rHandPosY, rhandZposInLadderTransform)
    let lHandPos = float3(0.f, isQuickDescending ? posInLadderTransform.y : lHandPosY, lhandZposInLadderTransform)

    ladderProgress -= floor(ladderProgress)
    setVar(phys_vars, human_anim__ladderProgressVarId, isQuickDescending ? 0.0 : ladderProgress)

    var normLadderTm = human_ladder__curLadderTm
    if posInLadderTransform.x < 0.f
      normLadderTm[0] = -normLadderTm[0]
    orthonormalize(normLadderTm)
    let worldOffset = normLadderTm |> rotate(human_anim__ladder__effectorOffset)

    var tm = IDENT_TM
    tm[0] = normLadderTm[1]
    tm[2] = transform[2]
    tm[1] = -cross(tm[2], tm[0])

    rightHandEffector.position = human_ladder__curLadderTm * rHandPos - d_wofs + worldOffset
    rightHandEffector.wtm = tm
    rightHandEffector.wtm[3] = rightHandEffector.position
    rightHandEffector.weight = (isQuickDescending
                              ? 1.0
                              : saturate(2.f * sin((ladderProgress - 0.5f) * TWOPI)))

    leftHandEffector.position = human_ladder__curLadderTm * lHandPos - d_wofs + worldOffset
    leftHandEffector.wtm = tm
    leftHandEffector.wtm[3] = leftHandEffector.position
    leftHandEffector.weight = (isQuickDescending
                             ? 1.0
                             : saturate(2.f * sin(ladderProgress * TWOPI)))


[es(tag=gameClient, track=human_ladder__attached)]
def human_ladder_end_animation(evt : Event;
                               human_ladder__attached : bool;
                               var animchar_effectors__effectorsState : Object)
  if !human_ladder__attached
    var rightHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "r.hand")
    var leftHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "l.hand")

    rightHandEffector.weight = 0.f
    leftHandEffector.weight = 0.f


[es(tag=gameClient, on_appear, REQUIRE=human_on_ladder_animation)]
def human_ladder_start_animation(evt : Event; game_effect__attachedTo : EntityId)
  set_current_ladder_for_anim(game_effect__attachedTo)


[es(tag=gameClient, after=(human_look_dir_camera_es, human_to_ladder_anim_transfer_to_ladder_orient), REQUIRE=watchedByPlr)]
def human_to_ladder_anim_update_camera_on_transfer(info : UpdateStageInfoAct;
                                                   human_to_ladder_animation__startOrient : float3;
                                                   human_to_ladder_animation__wishOrient : float3;
                                                   human_to_ladder_animation__lastTimeOrient : float;
                                                   human_to_ladder_animation__duration : float;
                                                   var human_input__aimAngle : float2&)
  let interpK = safediv(human_to_ladder_animation__lastTimeOrient, human_to_ladder_animation__duration)
  let q = slerp(dir_to_quat(human_to_ladder_animation__startOrient), dir_to_quat(human_to_ladder_animation__wishOrient), interpK)
  human_input__aimAngle = dir_to_angles(quat_get_forward(q))


[es(tag=gameClient, before=anim_phys_init_es, on_appear)]
def human_ladder_quick_descent_on_appear(evt : Event;
                                         human_anim__ladderQuickDescentProgressVar : string;
                                         var human_anim__ladderQuickDescentProgressVarId : int&;
                                         var phys_vars : PhysVars&)
  human_anim__ladderQuickDescentProgressVarId = phys_vars |> registerVar(human_anim__ladderQuickDescentProgressVar, float(0.0))


[es(tag=gameClient, on_appear, REQUIRE=human_on_ladder_quick_descent_animation)]
def human_ladder_quick_descent_start_animation(evt : Event; game_effect__attachedTo : EntityId)
  set_current_ladder_for_anim(game_effect__attachedTo)
  set_hero_draw_above_geometry(game_effect__attachedTo, false)


[es(tag=gameClient, on_disappear, REQUIRE=human_on_ladder_quick_descent_animation)]
def human_ladder_quick_descent_stop_animation(evt : Event; game_effect__attachedTo : EntityId)
  set_hero_draw_above_geometry(game_effect__attachedTo, true)


[es(tag=gameClient, REQUIRE=human_on_ladder_quick_descent_animation)]
def human_ladder_quick_descent_update_animation(info : ParallelUpdateFrameDelayed;
                                                game_effect__attachedTo : EntityId)
  assume attachedTo = game_effect__attachedTo
  query(attachedTo) <| $ [es(REQUIRE_NOT=deadEntity)] (human_ladder__curLadderTm : float3x4;
                                                       human_anim__ladder__handSidesOffset : float;
                                                       human_anim__ladderQuickDescentProgressVarId : int;
                                                       var phys_vars : PhysVars)
    let ladderWidth = length(human_ladder__curLadderTm[2]) + human_anim__ladder__handSidesOffset * 0.5
    setVar(phys_vars, human_anim__ladderQuickDescentProgressVarId, ladderWidth)
