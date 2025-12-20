
require ecs
require net
require inventory
require DngHuman
require WTInput
require %game.input.input_events

require %appGame.wt_events


def find_grenade_ammo_item_id(item_container : EidList; grenade_type : string)
  var itemId = INVALID_ITEM_ID

  for itemEid in item_container
    query(itemEid) <| $ [es(REQUIRE=hand_grenade)] (item__grenadeType : string; item__id : int)
      if grenade_type == "" || grenade_type == item__grenadeType
        itemId = item__id
        return

    if itemId != INVALID_ITEM_ID
      break

  return itemId

def try_quick_throw_grenade_slot(eid : EntityId; item_container : EidList; grenade_type : string)
  let grenadeAmmoId = find_grenade_ammo_item_id(item_container, grenade_type)
  if grenadeAmmoId != INVALID_ITEM_ID
    send_net_event(eid, RequestQuickThrowGrenade(grenade_ammo_id = grenadeAmmoId))

def set_throwbit(var ct : HumanControlState&;
                 action : ShortcutEventId)
  ct |> human_control_state_set_throw_state(false, HumanControlThrowSlot.HCTS_EMPTY)
  if is_shortcut_down(action)
    ct |> human_control_state_set_throw_state(true, HumanControlThrowSlot.HCTS_EMPTY)

[es(tag=input, REQUIRE=hero)]
def human_grenade_input_action_triggered_es(evt : EventOnKeyDown;
                                            eid : EntityId;
                                            human_weap__throwMode : bool;
                                            human_weap__grenadeThrowModeServer : bool;
                                            input__enabled : bool = true;
                                            itemContainer : EidList)
  if !input__enabled
    return
  if evt.eventId != int(ShortcutEventId.ID_HUMAN_THROW)
    return
  if human_weap__throwMode || human_weap__grenadeThrowModeServer
    return
  try_quick_throw_grenade_slot(eid, itemContainer, "")


[es(tag=input, REQUIRE=hero, before=human_grenade_input_action_triggered_es)]
def human_grenade_input_es(info : UpdateStageUpdateInput;
                           var human_net_phys : HumanActor&)
  assume ct = human_net_phys.phys.producedCT
  ct |> set_throwbit(ShortcutEventId.ID_HUMAN_THROW)

[es(tag=input, before=human_common_input_action_triggered_es)]
def human_throw_back_grenade_es(evt : EventOnKeyDown;
                                input__enabled : bool = true;
                                grenade_rethrow__grenadeEid : EntityId;
                                var human_net_phys : HumanActor&)
  if input__enabled && evt.eventId == int(ShortcutEventId.ID_HUMAN_USE) && !!grenade_rethrow__grenadeEid
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, true)

[es(tag=input)]
def human_cancel_throw_back_grenade_es(evt : EventOnKeyUp;
                                       input__enabled : bool = true;
                                       var human_net_phys : HumanActor&)
  if input__enabled && evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, false)

[es(tag=input, before=human_common_input_action_triggered_es)]
def downed_human_throw_grenade_es(evt : EventOnKeyDown;
                                  isDowned : bool;
                                  input__enabled : bool = true;
                                  var human_net_phys : HumanActor&)
  if input__enabled && isDowned && evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, true)

[es(tag=input)]
def downed_human_cancel_throw_grenade_es(evt : EventOnKeyUp;
                                         isDowned : bool;
                                         input__enabled : bool = true;
                                         var human_net_phys : HumanActor&)
  if input__enabled && isDowned && evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, false)

