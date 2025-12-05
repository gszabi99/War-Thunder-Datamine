require ecs
require net
require DagorMath
require DngHuman
require %game.events

[es]
def human_weapon_hold_breath(evt : CmdPostPhysUpdate;
                             eid : EntityId;
                             human_hold_breath__holdDuration : float;
                             human_hold_breath__restoreDuration : float;
                             human_hold_breath__startLevel : float = 1.0;
                             entity_mods__breathRestoreMult : float = 1.0;
                             entity_mods__holdBreathDrainMult : float = 1.0;
                             isDowned : bool = false;
                             var human_hold_breath__isAvailable : bool&;
                             var human_hold_breath__progressUi : float&;
                             var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState
  assume appliedCT = human_net_phys.phys.appliedCT
  let stoppedHoldBreath = (currentState.breathShortness >= 1.0
    || (!is_hold_breath(currentState) && currentState.breathShortness > 1.0 - human_hold_breath__startLevel))
  let isAiming = (human_phys_state_can_aim(currentState)
    && is_control_bit_set(appliedCT, HumanPhysControlType.HCT_AIM)
    && currentState.weapEquipState.curState != HUWeaponEquipState.EES_DOWN
    && !human_phys_state_get_isClimbing(currentState)
    && !isDowned)

  human_hold_breath__isAvailable = isAiming && !stoppedHoldBreath

  query(eid) <| $ [es] (var human_hold_breath__showHintUi : bool&)
    if (human_hold_breath__isAvailable && !is_hold_breath(currentState)) != human_hold_breath__showHintUi
      human_hold_breath__showHintUi = human_hold_breath__isAvailable && !is_hold_breath(currentState)

  currentState |> set_is_hold_breath(appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT) && human_hold_breath__isAvailable)
  if is_hold_breath(currentState)
    let drain = safediv(1.0, human_hold_breath__holdDuration)
    currentState.breathShortness += evt.dt * drain * entity_mods__holdBreathDrainMult
  else
    let restore = safediv(1.0, human_hold_breath__restoreDuration)
    currentState.breathShortness -= evt.dt * restore * entity_mods__breathRestoreMult

  currentState.breathShortness = saturate(currentState.breathShortness)
  human_hold_breath__progressUi = 1.0 - currentState.breathShortness
