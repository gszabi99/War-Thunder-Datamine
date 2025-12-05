require ecs
require HumanPhys
require DngHuman
require %game.events


[es(before=after_net_phys_sync)]
def drain_stamina_on_breath_hold_es(evt : CmdPostPhysUpdate;
                                    var human_net_phys : HumanActor;
                                    human_net_phys__drainStaminaSpeedOnHoldBreath : float)
  let stamina = human_net_phys.phys.currentState.stamina
  if is_hold_breath(human_net_phys.phys.currentState)
    human_net_phys.phys.currentState.stamina = max(stamina - human_net_phys__drainStaminaSpeedOnHoldBreath * evt.dt, 0.f)
    if human_net_phys.phys.currentState.stamina <= 0.f
      set_is_hold_breath(human_net_phys.phys.currentState, false)
      human_net_phys.phys.currentState.breathShortness = 1.

[es(before=after_net_phys_sync, REQUIRE=drainBreathOnLowStamina)]
def drain_breath_on_low_stamina_hold_es(evt : CmdPostPhysUpdate; var human_net_phys : HumanActor)
  let wasStamina = human_net_phys.phys.previousState.stamina

  assume stamina = human_net_phys.phys.currentState.stamina
  assume breathShortness = human_net_phys.phys.currentState.breathShortness
  if wasStamina > 0. && stamina <= 0. && breathShortness <= 0.
    breathShortness = 1.
    stamina = 0.

def breath_shortness_block_stamina_restoration(var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState
  if currentState.breathShortness > 0.
    currentState.restoreStaminaMult = 0.0

[es(tag=netClient, REQUIRE=hero, after=entity_mods_appliers_client_es)]
def breath_shortness_block_stamina_restoration_local(info : ParallelUpdateFrameDelayed;
                                                     var human_net_phys : HumanActor&)
  breath_shortness_block_stamina_restoration(human_net_phys)

[es(tag=server, after=entity_mods_appliers_server_es)]
def breath_shortness_block_stamina_restoration_server(info : ParallelUpdateFrameDelayed;
                                                      var human_net_phys : HumanActor&)
  breath_shortness_block_stamina_restoration(human_net_phys)
