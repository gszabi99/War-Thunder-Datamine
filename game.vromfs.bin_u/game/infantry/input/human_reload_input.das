require ecs
require app
require WTInput
require DngHuman
require DngWeapon
require %game.input.input_events
























let RELOAD_DELTA_T = 0.1f


[es(tag=input, REQUIRE=controlledHero)]
def human_reload_input_on_action_triggered(evt : EventOnKeyDown;
                                           human_input__doubleClickPeriod : float;
                                           human_use_object__selectedObject : EntityId;
                                           var human_reload_input__lastKeyDownTime : float&;
                                           var human_reload_input__isNeedHctReloadReset : bool&;
                                           var human_net_phys : HumanActor&)
  if int(evt.eventId) != int(ShortcutEventId.ID_HUMAN_RELOAD)
    return
  if is_shortcut_down(ShortcutEventId.ID_HUMAN_USE) && human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  let curTime = get_sync_time()
  let isDoubleClick = (curTime - human_reload_input__lastKeyDownTime) < human_input__doubleClickPeriod
  human_reload_input__lastKeyDownTime = curTime

  assume ct = human_net_phys.phys.producedCT
  human_control_state_set_control_bit(ct, HumanPhysControlType.HCT_RELOAD, true)
  human_control_state_set_dodge_state(ct, DodgeState.Left)
  setQuickReloadState(ct, isDoubleClick)
  human_reload_input__isNeedHctReloadReset = true


[es(tag=input, REQUIRE=controlledHero)]
def human_reload_input_on_action_terminated(evt : EventOnKeyUp;
                                            var human_reload_input__isNeedHctReloadReset : bool&;
                                            var human_reload_input__reloadCommited : bool&;
                                            var human_net_phys : HumanActor&)
  if int(evt.eventId) != int(ShortcutEventId.ID_HUMAN_RELOAD)
    return

  assume ct = human_net_phys.phys.producedCT
  if human_reload_input__isNeedHctReloadReset
    human_control_state_set_control_bit(ct, HumanPhysControlType.HCT_RELOAD, false)
    human_control_state_set_dodge_state(ct, DodgeState.No)
    setQuickReloadState(ct, false)
    human_reload_input__isNeedHctReloadReset = false
    human_reload_input__reloadCommited = true


[es(tag=input, no_order, REQUIRE=controlledHero)]
def human_reload_input_reset(evt : UpdateStageUpdateInput;
                             human_input__inspectAfterTime : float;
                             human_reload_input__lastKeyDownTime : float;
                             human_weap__reloadFinishTime : float;
                             var human_reload_input__isNeedHctReloadReset : bool&;
                             var human_reload_input__reloadCommited : bool&;
                             var human_net_phys : HumanActor&)
  if get_sync_time() > human_weap__reloadFinishTime
    human_reload_input__reloadCommited = false

  if !human_reload_input__reloadCommited && human_reload_input__isNeedHctReloadReset && get_sync_time() - human_reload_input__lastKeyDownTime > human_input__inspectAfterTime
    human_net_phys.phys.producedCT |> human_control_state_set_dodge_state(DodgeState.No)
  if human_reload_input__isNeedHctReloadReset && get_sync_time() - human_reload_input__lastKeyDownTime > human_input__inspectAfterTime + RELOAD_DELTA_T
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_RELOAD, false)
    human_net_phys.phys.producedCT |> setQuickReloadState(false)
    human_net_phys.phys.producedCT |> human_control_state_set_dodge_state(DodgeState.No)
    human_reload_input__isNeedHctReloadReset = false
