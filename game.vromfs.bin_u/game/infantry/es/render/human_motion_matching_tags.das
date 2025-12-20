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


def need_enable_motion_matching(states : HumanAnimState; from_crawl_transition_state_id : int; anim_state_id : int)
  return (anim_state_id == states.lowerState.lowerSprint || anim_state_id == states.lowerState.run ||
    anim_state_id == states.lowerState.walk || anim_state_id == states.lowerState.stand ||
    anim_state_id == states.lowerState.rotateLeft || anim_state_id == states.lowerState.rotateRight ||
    anim_state_id == from_crawl_transition_state_id)

enum WishStandState
  STAND
  CROUCH

def update_mm_tags_from_human_state(states : HumanAnimState;
                                    prev_anim_state_id : int;
                                    next_anim_state_id : int;
                                    from_crawl_transition_state_id : int;
                                    applied_ct : HumanControlState;
                                    wish_to_move : bool;
                                    var motion_matching__controller : MotionMatchingController)

  if prev_anim_state_id < 0 || prev_anim_state_id == states.lowerState.lowerSprint
    remove_tag(motion_matching__controller, "sprint")
    remove_tag(motion_matching__controller, "stand")
  elif prev_anim_state_id == states.lowerState.run || prev_anim_state_id == states.lowerState.walk
    remove_tag(motion_matching__controller, "walk")
    remove_tag(motion_matching__controller, "crouch")
  elif (prev_anim_state_id == states.lowerState.stand ||
        prev_anim_state_id == states.lowerState.rotateLeft ||
        prev_anim_state_id == states.lowerState.rotateRight ||
        prev_anim_state_id == from_crawl_transition_state_id)
    remove_tag(motion_matching__controller, "stand")
    remove_tag(motion_matching__controller, "crouch")
    remove_tag(motion_matching__controller, "turn_on_spot")

  
  
  let wishStandState = (applied_ct.is_control_bit_set(HumanPhysControlType.HCT_CROUCH) ? WishStandState.CROUCH : WishStandState.STAND)

  if next_anim_state_id == states.lowerState.lowerSprint
    set_tag(motion_matching__controller, "sprint", true)
    if wish_to_move
      set_tag(motion_matching__controller, "stand", false)
  elif next_anim_state_id == states.lowerState.run || next_anim_state_id == states.lowerState.walk
    if wishStandState == WishStandState.STAND
      set_tag(motion_matching__controller, "walk", true)
    elif wishStandState == WishStandState.CROUCH
      set_tag(motion_matching__controller, "crouch", true)
  elif (next_anim_state_id == states.lowerState.stand ||
        next_anim_state_id == states.lowerState.rotateLeft ||
        next_anim_state_id == states.lowerState.rotateRight ||
        next_anim_state_id == from_crawl_transition_state_id)
    if wishStandState == WishStandState.STAND
      set_tag(motion_matching__controller, "stand", true)
    elif wishStandState == WishStandState.CROUCH
      set_tag(motion_matching__controller, "crouch", true)
      if (next_anim_state_id == states.lowerState.rotateLeft ||
          next_anim_state_id == states.lowerState.rotateRight ||
          prev_anim_state_id == states.lowerState.rotateLeft ||
          prev_anim_state_id == states.lowerState.rotateRight)
        set_tag(motion_matching__controller, "turn_on_spot", true)

[es(tag=gameClient, after=(human_anim_es, force_anim_state_es, wait_motion_matching_job_es), before=(anim_state_es, update_tag_changes_es))]
def update_human_mm_tags_es(evt : ParallelUpdateFrameDelayed;
                            animchar__animState : Object;
                            animchar__animStateDirty : bool;
                            human_anim : HumanAnimCtx;
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
      update_mm_tags_from_human_state(human_anim.animState, motion_matching__prevLowerAnimState, nextLowerStateId,
        human_anim__fromCrawlTransitionAnimId, phys.appliedCT, curState.isWishToMove, motion_matching__controller)
      motion_matching__prevLowerAnimState = nextLowerStateId
      motion_matching__prevControlState = int(phys.appliedCT.packedState)
      motion_matching__enabled = (need_enable_motion_matching(human_anim.animState, human_anim__fromCrawlTransitionAnimId, nextLowerStateId) &&
        hasAvailableAnimations(*motion_matching__controller.dataBase, motion_matching__controller.currentTags))

[es(tag=gameClient, after=wait_motion_matching_job_es, before=update_human_mm_tags_es)]
def update_mm_tag_turn_in_move(evt : ParallelUpdateFrameDelayed;
                               human_net_phys : HumanActor;
                               let mm_trajectory__featureDirections : Point3List;
                               var motion_matching__controller : MotionMatchingController)
  if motion_matching__controller.dataBase == null || empty(mm_trajectory__featureDirections)
    return
  let angleThreshold = 0.866f 
  if (human_net_phys.phys.currentState.moveState == HUMoveState.EMS_RUN &&
      !human_net_phys.phys.appliedCT.is_control_bit_set(HumanPhysControlType.HCT_CROUCH) &&
      dot(mm_trajectory__featureDirections[0], back(mm_trajectory__featureDirections)) < angleThreshold)
    set_tag(motion_matching__controller, "turn_in_move", true)
  else
    remove_tag(motion_matching__controller, "turn_in_move")

[es(tag=gameClient, on_event=AnimationDataBaseAssigned, track=human_anim__isFpv)]
def set_mm_view_mode_tag_es(evt : Event;
                            human_anim__isFpv : bool;
                            human_anim : HumanAnimCtx;
                            human_anim__fromCrawlTransitionAnimId : int;
                            animchar__animState : Object;
                            var motion_matching__enabled : bool&;
                            var motion_matching__controller : MotionMatchingController)
  if motion_matching__controller.dataBase == null
    return
  
  
  if human_anim__isFpv
    remove_tag(motion_matching__controller, "1st_person_view")
    set_tag(motion_matching__controller, "3rd_person_view", false)
  else
    remove_tag(motion_matching__controller, "3rd_person_view")
    set_tag(motion_matching__controller, "1st_person_view", false)
  for state in animchar__animState
    if state.key == "lower"
      let nextLowerStateId = get_int(state.value) ?? 0
      motion_matching__enabled = (need_enable_motion_matching(human_anim.animState, human_anim__fromCrawlTransitionAnimId, nextLowerStateId) &&
        hasAvailableAnimations(*motion_matching__controller.dataBase, motion_matching__controller.currentTags))
