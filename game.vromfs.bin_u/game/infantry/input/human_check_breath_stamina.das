require ecs
require HumanPhys
require DngHuman
require %game.input.input_events
require DagorConsole

[es(tag=input, after=human_input_es, before=before_net_phys_sync)]
def check_hold_breath_stamina_therhold_es(evt : UpdateStageUpdateInput;
                                          human_net_phys__minStaminaLevelToHoldBreath : float;
                                          var human_net_phys : HumanActor)
  let stamina = human_net_phys.phys.currentState.stamina
  let maxStamina = human_net_phys.phys.maxStamina
  let staminaLevel = clamp(safediv(stamina, maxStamina), 0., 1.)
  let isSprinting = (int(human_net_phys.phys.currentState.states) & int(StateFlag.ST_SPRINT)) != 0
  let isHoldBreath = (is_control_bit_set(human_net_phys.phys.producedCT, HumanPhysControlType.HCT_AIM) &&
                      is_control_bit_set(human_net_phys.phys.producedCT, HumanPhysControlType.HCT_SPRINT))
  if (staminaLevel < human_net_phys__minStaminaLevelToHoldBreath &&
      isHoldBreath &&
      !isSprinting &&
      !is_hold_breath(human_net_phys.phys.currentState))
    human_control_state_set_control_bit(human_net_phys.phys.producedCT, HumanPhysControlType.HCT_SPRINT, false)
    return
