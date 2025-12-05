require app
require ecs
require WTInput
require %game.input.input_events

require %appGame.wt_events
require %appGame.infantry.es.context_command_common
require %appGame.infantry.es.squad_personal_order_common
require %appGame.infantry.input.human_context_command_point_common
require %appGame.infantry.client.destroyable_wall_client_common
require %appGame.squad_order_enums


let SELECT_SOLDIER_ACTION_COUNT = 5


[es(tag=input, on_appear)]
def human_context_command_input_on_create(evt : Event;
                                          var human_context_command__selectSoldierActions : IntList&)
  human_context_command__selectSoldierActions |> resize(SELECT_SOLDIER_ACTION_COUNT)
  human_context_command__selectSoldierActions[0] = int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND_SELECT_SOLDIER_1)
  human_context_command__selectSoldierActions[1] = int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND_SELECT_SOLDIER_2)
  human_context_command__selectSoldierActions[2] = int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND_SELECT_SOLDIER_3)
  human_context_command__selectSoldierActions[3] = int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND_SELECT_SOLDIER_4)
  human_context_command__selectSoldierActions[4] = int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND_SELECT_SOLDIER_5)

[es(tag=input, track=(isAlive, human_context_command__menuIsOpen), REQUIRE=human_context_command__menuIsOpen)]
def human_context_command_menu_marker_create_destroy(evt : Event; eid aka human_eid : EntityId; isAlive : bool;
                                                     human_context_command__menuIsOpen : bool;
                                                     human_context_command__menuMarkerTemplate : string;
                                                     var human_context_command__menuMarkerEid : EntityId&)
  if (isAlive && human_context_command__menuIsOpen) != (human_context_command__menuMarkerEid != INVALID_ENTITY_ID)
    if !human_context_command__menuMarkerEid
      human_context_command__menuMarkerEid = createEntity(human_context_command__menuMarkerTemplate) <| $(var init : ComponentsInitializer)
        var grenadePos = float3()
        var grenadeDir = float3()
        var grenadeAltPos = float3()
        let canThrowGrenade = human_context_command_menu_trace_throw_grenade(human_eid, grenadePos, grenadeDir, grenadeAltPos)
        init |> set("human_context_command_marker__canThrowGrenade", canThrowGrenade)
        init |> set("human_context_command_marker__canThrowGrenadeToPos", grenadePos)
    else
      destroyEntity(human_context_command__menuMarkerEid)
      human_context_command__menuMarkerEid = INVALID_ENTITY_ID

[es(tag=input, REQUIRE=controlledHero)]
def human_context_command_input_on_action(evt : EventOnKeyDown;
                                          eid : EntityId;
                                          input__enabled : bool = true;
                                          squad_member__squad : EntityId;
                                          squad_member__isPersonalContextCommandMode : bool;
                                          human_context_command__pointOrder : int;
                                          var human_context_command__menuIsOpen : bool&;
                                          var human_context_command__aimInputStartTime : float&;
                                          var personal_bot_order__currentBotEid : EntityId&;
                                          human_mining_wall__isReassemblingAvailable : bool = false)
  if !input__enabled
    return

  if int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND)
    if human_context_command__menuIsOpen
      sendEvent(eid, CmdCloseSquadOrdersMenu())
      human_context_command__menuIsOpen = false
    elif squad_member__isPersonalContextCommandMode
      if human_context_command__pointOrder == int(HumanPointOrderType.NOT_POINT_ORDER)
        
        
        
        
        
        
        
        
        
        
        
        
        sendEvent(eid, RqPersonalContextCommand())
  elif int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND_NEXT_POSE)
    if squad_member__isPersonalContextCommandMode
      if human_context_command__pointOrder == int(HumanPointOrderType.POINT_TAKE_POSITION)
        human_point_order_change_to_next_or_prev_pose(eid, false)
  elif int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_SELECT_PREV_SOLDIER) && !human_mining_wall__isReassemblingAvailable
    query(squad_member__squad) <| $ [es] (squad__leader : EntityId; squad__allMembers : EidList)
      let wasEid = personal_bot_order__currentBotEid
      var setEid = personal_bot_order__currentBotEid
      var newEid = find_next_bot_for_personal_order(squad__leader, squad_member__squad, wasEid)
      var numTries = length(squad__allMembers)
      while newEid != wasEid && numTries-- > 0
        setEid = newEid
        newEid = find_next_bot_for_personal_order(squad__leader, squad_member__squad, newEid)
      personal_bot_order__currentBotEid = setEid
  elif int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_AIM)
    human_context_command__aimInputStartTime = get_sync_time()

[es(tag=input, REQUIRE=controlledHero)]
def human_context_command_change_current_bot(evt : EventOnKeyDown;
                                             human_context_command__selectSoldierActions : IntList;
                                             squad_member__squad : EntityId;
                                             var personal_bot_order__currentBotEid : EntityId&)
  
  let contextCommandHold = is_shortcut_down(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND)
  if contextCommandHold
    if int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND_NEXT_SOLDIER)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
        personal_bot_order__currentBotEid = find_next_bot_for_personal_order(squad__leader, squad_member__squad, personal_bot_order__currentBotEid)

    query(squad_member__squad) <| $ [es] (squad__leader : EntityId; squad__allMembers : EidList)
      let numMembersInSquad = length(squad__allMembers)
      for i in range(0, min(numMembersInSquad, SELECT_SOLDIER_ACTION_COUNT))
        if int(evt.eventId) == human_context_command__selectSoldierActions[i]
          let botEid = squad__allMembers[i]
          if is_bot_valid_for_personal_order(squad__leader, botEid)
            personal_bot_order__currentBotEid = botEid


[es(tag=input, REQUIRE=controlledHero)]
def human_context_command_input_on_action_term(evt : EventOnKeyUp;
                                               eid : EntityId;
                                               input__enabled : bool = true;
                                               squad_member__isPersonalContextCommandMode : bool;
                                               human_context_command__pointOrder : int;
                                               human_context_command__aimInputStartTime : float;
                                               var human_context_command__orderType : int&;
                                               var human_context_command__orderPosition : float3&;
                                               var human_context_command__orderUseEntity : EntityId&)
  if !input__enabled
    return

  if int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_SHOOT)
    if is_human_point_order_await_shoot_accept(human_context_command__pointOrder)
      sendEventImmediate(eid, RqContextCommandPointOrder(pointOrderStrID = "accept"))
      return
  if int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_AIM) 
    if is_human_point_order_await_shoot_accept(human_context_command__pointOrder)
      sendEventImmediate(eid, RqContextCommandPointOrder(pointOrderStrID = "cancel"))
      return
    let aimInputDuration = get_sync_time() - human_context_command__aimInputStartTime
    if is_human_point_order_cancellable(human_context_command__pointOrder)
      if aimInputDuration < 0.2 
        human_point_order_cancel(eid)
        return

  if int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_CONTEXT_COMMAND)
    if human_context_command__pointOrder == int(HumanPointOrderType.POINT_TAKE_POSITION)
      if squad_member__isPersonalContextCommandMode
        human_context_command__orderType = int(ContextCommand.ECC_END_POINT_ORDER)
        human_context_command__orderUseEntity = INVALID_ENTITY_ID
        human_context_command__orderPosition = float3()
        sendEventImmediate(eid, RqPersonalContextCommand())
      human_point_order_cancel(eid)
