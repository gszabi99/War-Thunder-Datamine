require ecs
require HumanPhys
require DngHuman
require %game.events

[es(on_appear)]
def entity_stamina_boost_mult_applier(evt : Event;
                                      var human_net_phys : HumanActor;
                                      entity_mods__staminaBoostMult : float)
  human_net_phys.phys.currentState.staminaBoostMult = entity_mods__staminaBoostMult

[es(after=entity_stamina_boost_mult_applier, on_appear)]
def human_update_stamina_on_spawn(evt : Event;
                                  var human_net_phys : HumanActor)
  human_phys_state_reset_stamina(human_net_phys.phys.currentState, human_net_phys.phys.maxStamina)














[es(on_appear, track=(human_net_phys__maxStamina, human_net_phys__maxStaminaMult, human_net_phys__staminaBoostMult))]
def human_update_total_max_stamina(evt : Event;
                                   human_net_phys__maxStamina : float;
                                   human_net_phys__maxStaminaMult : float;
                                   human_net_phys__staminaBoostMult : float;
                                   var human__totalMaxStamina : float&)
  human__totalMaxStamina = human_net_phys__maxStamina * human_net_phys__maxStaminaMult * human_net_phys__staminaBoostMult