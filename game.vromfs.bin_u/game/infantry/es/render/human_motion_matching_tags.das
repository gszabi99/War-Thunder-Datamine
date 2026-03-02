require ecs
require ecs.common
require AnimV20
require DngHuman
require HumanAnim
require DngHumanAnim
require DagorSystem
require MotionMatching
require danetlibs.motion_matching.es.tags_common
require %game.events


def need_enable_motion_matching(human_anim__lowerStateLowerSprint : int;
                                human_anim__lowerStateRun : int;
                                human_anim__lowerStateWalk : int;
                                human_anim__lowerStateStand : int;
                                human_anim__lowerStateRotateLeft : int;
                                human_anim__lowerStateRotateRight : int;
                                human_anim__comboStateFullBodyWalk : int;
                                human_anim__comboStateFullBodyRun : int;
                                from_crawl_transition_state_id : int;
                                anim_state_id : int)
  return (anim_state_id == human_anim__lowerStateLowerSprint || anim_state_id == human_anim__lowerStateRun ||
    anim_state_id == human_anim__lowerStateWalk || anim_state_id == human_anim__lowerStateStand ||
    anim_state_id == human_anim__lowerStateRotateLeft || anim_state_id == human_anim__lowerStateRotateRight ||
    anim_state_id == human_anim__comboStateFullBodyWalk || anim_state_id == human_anim__comboStateFullBodyRun ||
    anim_state_id == from_crawl_transition_state_id)

enum WishStandState
  STAND
  CROUCH

def update_mm_tags_from_human_state(human_anim__lowerStateLowerSprint : int;
                                    human_anim__lowerStateRun : int;
                                    human_anim__lowerStateWalk : int;
                                    human_anim__lowerStateStand : int;
                                    human_anim__lowerStateRotateLeft : int;
                                    human_anim__lowerStateRotateRight : int;
                                    human_anim__comboStateFullBodyWalk : int;
                                    human_anim__comboStateFullBodyRun : int;
                                    prev_anim_state_id : int;
                                    next_anim_state_id : int;
                                    from_crawl_transition_state_id : int;
                                    applied_ct : HumanControlState;
                                    wish_to_move : bool;
                                    motion_matching__dataBaseEid : EntityId;
                                    var motion_matching__controller : MotionMatchingController)
  query(motion_matching__dataBaseEid) <| $ [es] (mm_tag_id__sprint : int;
                                                 mm_tag_id__walk : int;
                                                 mm_tag_id__stand : int;
                                                 mm_tag_id__crouch : int;
                                                 mm_tag_id__turnOnSpot : int;
                                                 mm_tag_id__fullBodyMovement : int)
    remove_tag(motion_matching__controller, mm_tag_id__sprint)
    remove_tag(motion_matching__controller, mm_tag_id__walk)
    remove_tag(motion_matching__controller, mm_tag_id__stand)
    remove_tag(motion_matching__controller, mm_tag_id__crouch)
    remove_tag(motion_matching__controller, mm_tag_id__turnOnSpot)
    remove_tag(motion_matching__controller, mm_tag_id__fullBodyMovement)

    
    
    let wishStandState = (applied_ct.is_control_bit_set(HumanPhysControlType.HCT_CROUCH) ? WishStandState.CROUCH : WishStandState.STAND)

    if next_anim_state_id == human_anim__lowerStateLowerSprint
      set_tag(motion_matching__controller, mm_tag_id__sprint, true)
      if wish_to_move
        set_tag(motion_matching__controller, mm_tag_id__stand, false)
    elif next_anim_state_id == human_anim__lowerStateRun || next_anim_state_id == human_anim__lowerStateWalk
      if wishStandState == WishStandState.STAND
        set_tag(motion_matching__controller, mm_tag_id__walk, true)
        if wish_to_move
          set_tag(motion_matching__controller, mm_tag_id__stand, false)
      elif wishStandState == WishStandState.CROUCH
        set_tag(motion_matching__controller, mm_tag_id__crouch, true)
    elif (next_anim_state_id == human_anim__lowerStateStand ||
          next_anim_state_id == human_anim__lowerStateRotateLeft ||
          next_anim_state_id == human_anim__lowerStateRotateRight ||
          next_anim_state_id == from_crawl_transition_state_id)
      if wishStandState == WishStandState.STAND
        set_tag(motion_matching__controller, mm_tag_id__stand, true)
      elif wishStandState == WishStandState.CROUCH
        set_tag(motion_matching__controller, mm_tag_id__crouch, true)
        if (next_anim_state_id == human_anim__lowerStateRotateLeft ||
            next_anim_state_id == human_anim__lowerStateRotateRight ||
            prev_anim_state_id == human_anim__lowerStateRotateLeft ||
            prev_anim_state_id == human_anim__lowerStateRotateRight)
          set_tag(motion_matching__controller, mm_tag_id__turnOnSpot, true)
    elif next_anim_state_id == human_anim__comboStateFullBodyWalk || next_anim_state_id == human_anim__comboStateFullBodyRun
      set_tag(motion_matching__controller, mm_tag_id__fullBodyMovement, true)

[es(tag=gameClient, after=(human_anim_es, force_anim_state_es, wait_motion_matching_job_es), before=(anim_state_es, update_tag_changes_es))]
def update_human_mm_tags_es(evt : ParallelUpdateFrameDelayed;
                            animchar__animState : Object;
                            animchar__animStateDirty : bool;
                            human_anim__lowerStateLowerSprint : int;
                            human_anim__lowerStateRun : int;
                            human_anim__lowerStateWalk : int;
                            human_anim__lowerStateStand : int;
                            human_anim__lowerStateRotateLeft : int;
                            human_anim__lowerStateRotateRight : int;
                            human_anim__comboStateFullBodyWalk : int;
                            human_anim__comboStateFullBodyRun : int;
                            human_anim__fromCrawlTransitionAnimId : int;
                            human_net_phys : HumanActor;
                            motion_matching__dataBaseEid : EntityId;
                            var motion_matching__prevLowerAnimState : int&;
                            var motion_matching__prevControlState : int&;
                            var motion_matching__enabled : bool&;
                            var motion_matching__controller : MotionMatchingController)
  assume phys = human_net_phys.phys
  assume curState = phys.currentState
  if (motion_matching__dataBaseEid == INVALID_ENTITY_ID ||
      (!animchar__animStateDirty && motion_matching__prevLowerAnimState >= 0 &&
       int(phys.appliedCT.packedState) == motion_matching__prevControlState) &&
       phys.previousState.isWishToMove == phys.currentState.isWishToMove)
    return

  for state in animchar__animState
    if state.key == "lower"
      let nextLowerStateId = get_int(state.value) ?? 0
      update_mm_tags_from_human_state(human_anim__lowerStateLowerSprint,
                                      human_anim__lowerStateRun,
                                      human_anim__lowerStateWalk,
                                      human_anim__lowerStateStand,
                                      human_anim__lowerStateRotateLeft,
                                      human_anim__lowerStateRotateRight,
                                      human_anim__comboStateFullBodyWalk,
                                      human_anim__comboStateFullBodyRun,
                                      motion_matching__prevLowerAnimState,
                                      nextLowerStateId,
                                      human_anim__fromCrawlTransitionAnimId,
                                      phys.appliedCT,
                                      curState.isWishToMove,
                                      motion_matching__dataBaseEid,
                                      motion_matching__controller)
      motion_matching__prevLowerAnimState = nextLowerStateId
      motion_matching__prevControlState = int(phys.appliedCT.packedState)
      motion_matching__enabled = (need_enable_motion_matching(human_anim__lowerStateLowerSprint,
                                                              human_anim__lowerStateRun,
                                                              human_anim__lowerStateWalk,
                                                              human_anim__lowerStateStand,
                                                              human_anim__lowerStateRotateLeft,
                                                              human_anim__lowerStateRotateRight,
                                                              human_anim__comboStateFullBodyWalk,
                                                              human_anim__comboStateFullBodyRun,
                                                              human_anim__fromCrawlTransitionAnimId,
                                                              nextLowerStateId) &&
        hasAvailableAnimations(*motion_matching__controller.dataBase, motion_matching__controller.currentTags))

[es(tag=gameClient, after=wait_motion_matching_job_es, before=update_human_mm_tags_es)]
def update_mm_tag_turn_in_move(evt : ParallelUpdateFrameDelayed;
                               human_net_phys : HumanActor;
                               mm_trajectory__featureDirections : Point3List;
                               motion_matching__dataBaseEid : EntityId;
                               var motion_matching__controller : MotionMatchingController)
  if empty(mm_trajectory__featureDirections)
    return
  query(motion_matching__dataBaseEid) <| $ [es] (mm_tag_id__turnInMove : int)
    let angleThreshold = 0.866f 
    if (human_net_phys.phys.currentState.moveState == HUMoveState.EMS_RUN &&
        !human_net_phys.phys.appliedCT.is_control_bit_set(HumanPhysControlType.HCT_CROUCH) &&
        dot(mm_trajectory__featureDirections[0], back(mm_trajectory__featureDirections)) < angleThreshold)
      set_tag(motion_matching__controller, mm_tag_id__turnInMove, true)
    else
      remove_tag(motion_matching__controller, mm_tag_id__turnInMove)

[es(tag=gameClient, on_event=AnimationDataBaseAssigned, track=human_anim__isFpv)]
def set_mm_view_mode_tag_es(evt : Event;
                            human_anim__isFpv : bool;
                            human_anim__lowerStateLowerSprint : int;
                            human_anim__lowerStateRun : int;
                            human_anim__lowerStateWalk : int;
                            human_anim__lowerStateStand : int;
                            human_anim__lowerStateRotateLeft : int;
                            human_anim__lowerStateRotateRight : int;
                            human_anim__comboStateFullBodyWalk : int;
                            human_anim__comboStateFullBodyRun : int;
                            human_anim__fromCrawlTransitionAnimId : int;
                            animchar__animState : Object;
                            motion_matching__dataBaseEid : EntityId;
                            var motion_matching__enabled : bool&;
                            var motion_matching__controller : MotionMatchingController)
  query(motion_matching__dataBaseEid) <| $ [es] (mm_tag_id__1stPersonView : int; mm_tag_id__3rdPersonView : int)
    
    
    if human_anim__isFpv
      remove_tag(motion_matching__controller, mm_tag_id__1stPersonView)
      set_tag(motion_matching__controller, mm_tag_id__3rdPersonView, false)
    else
      remove_tag(motion_matching__controller, mm_tag_id__3rdPersonView)
      set_tag(motion_matching__controller, mm_tag_id__1stPersonView, false)
    for state in animchar__animState
      if state.key == "lower"
        let nextLowerStateId = get_int(state.value) ?? 0
        motion_matching__enabled = (need_enable_motion_matching(human_anim__lowerStateLowerSprint,
                                                                human_anim__lowerStateRun,
                                                                human_anim__lowerStateWalk,
                                                                human_anim__lowerStateStand,
                                                                human_anim__lowerStateRotateLeft,
                                                                human_anim__lowerStateRotateRight,
                                                                human_anim__comboStateFullBodyWalk,
                                                                human_anim__comboStateFullBodyRun,
                                                                human_anim__fromCrawlTransitionAnimId,
                                                                nextLowerStateId) &&
          hasAvailableAnimations(*motion_matching__controller.dataBase, motion_matching__controller.currentTags))

[es(tag=gameClient, on_event=AnimationDataBaseLoaded)]
def init_mm_tags_es(evt : Event;
                    dataBase : AnimationDataBase;
                    var mm_tag_id__sprint : int&;
                    var mm_tag_id__walk : int&;
                    var mm_tag_id__stand : int&;
                    var mm_tag_id__crouch : int&;
                    var mm_tag_id__turnOnSpot : int&;
                    var mm_tag_id__turnInMove : int&;
                    var mm_tag_id__1stPersonView : int&;
                    var mm_tag_id__3rdPersonView : int&;
                    var mm_tag_id__fullBodyMovement : int&)
  mm_tag_id__sprint = get_tag_index(dataBase, "sprint")
  mm_tag_id__walk = get_tag_index(dataBase, "walk")
  mm_tag_id__stand = get_tag_index(dataBase, "stand")
  mm_tag_id__crouch = get_tag_index(dataBase, "crouch")
  mm_tag_id__turnOnSpot = get_tag_index(dataBase, "turn_on_spot")
  mm_tag_id__turnInMove = get_tag_index(dataBase, "turn_in_move")
  mm_tag_id__1stPersonView = get_tag_index(dataBase, "1st_person_view")
  mm_tag_id__3rdPersonView = get_tag_index(dataBase, "3rd_person_view")
  mm_tag_id__fullBodyMovement = get_tag_index(dataBase, "full_body_movement")
