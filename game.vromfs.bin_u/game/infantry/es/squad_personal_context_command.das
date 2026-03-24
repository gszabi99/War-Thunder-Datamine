require ecs

require %appGame.wt_events
require %appGame.infantry.es.squad_personal_order_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require %appGame.infantry.input.human_context_command_point_common
require %appGame.infantry.es.context_command_common
require net

[es(tag=gameClient, REQUIRE=human_context_command_input)]
def human_personal_context_command_req(evt : RqPersonalContextCommand;
                                       eid : EntityId;
                                       squad_member__squad : EntityId;
                                       human_context_command__orderType : int;
                                       var human_context_command__orderPosition : float3&;
                                       human_context_command__orderUseEntity : EntityId;
                                       human_context_command__pointOrder : int;
                                       human_context_command__pointOrderAck : int;
                                       human_context_command__pointOrderShowTime : float;
                                       var personal_bot_order__currentBotEid : EntityId&)
  var isOrdered = false
  if human_context_command__orderType == int(ContextCommand.ECC_SELECT_SQUAD_MATE)
    query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
      for memberEid in squad__allMembers
        if memberEid == human_context_command__orderUseEntity && memberEid != eid
          personal_bot_order__currentBotEid = human_context_command__orderUseEntity
          let overwatchOrder = int(HumanPointOrderType.POINT_TAKE_POSITION)
          var traced = HumanPointOrderTraced()
          if human_point_order_trace(eid, overwatchOrder, traced)
            human_context_command__orderPosition = traced.pos
            let orderKind = int(HumanPointTargetKind.HUMAN)
            let orderEid = personal_bot_order__currentBotEid
            human_point_order_start(eid, human_context_command__orderPosition, orderKind, orderEid, overwatchOrder, personal_bot_order__currentBotEid)
          break
  elif human_context_command__orderType == int(ContextCommand.ECC_START_POINT_OVERWATCH_ORDER)
    let overwatchOrder = int(HumanPointOrderType.POINT_TAKE_POSITION)
    var traced = HumanPointOrderTraced()
    if human_point_order_trace(eid, overwatchOrder, traced)
      human_context_command__orderPosition = traced.pos
      human_point_order_start(eid, human_context_command__orderPosition, traced.kind, traced.eid, overwatchOrder, personal_bot_order__currentBotEid)
  elif human_context_command__orderType == int(ContextCommand.ECC_END_POINT_ORDER)
    if human_context_command__pointOrder == int(HumanPointOrderType.POINT_TAKE_POSITION)
      if human_context_command__pointOrderShowTime < 0.0
        var order = -1
        var pos : float3
        var dir : float3
        var posTo : float3
        var dirTo : float3
        if human_point_order_complete(eid, order, pos, dir, posTo, dirTo)
          isOrdered = human_context_command__pointOrderAck > 0
          query(personal_bot_order__currentBotEid) <| $ [es] (transform : float3x4)
            if transform[3] == pos
              isOrdered = false
          if human_context_command__pointOrderAck > 0
            send_net_event(personal_bot_order__currentBotEid, RequestPersonalSquadMateOrder(orderType = order, orderPosition = pos, orderByDirection = dir, orderToPosition = posTo, orderToDirection = dirTo))
  elif human_context_command__orderType == int(ContextCommand.ECC_DEFEND_POINT)
    var orderType = SquadMateOrder.ESMO_DEFEND_POINT
    var orderPosition = human_context_command__orderPosition
    let orderUseEntity = human_context_command__orderUseEntity
    query(orderUseEntity) <| $ [es] (transform : float3x4)
      orderPosition = transform[3]
    if has(orderUseEntity, "vehicle")
      orderType = SquadMateOrder.ESMO_USE_VEHICLE
    isOrdered = true
    send_net_event(personal_bot_order__currentBotEid, RequestPersonalSquadMateOrder(orderType = int(orderType), orderPosition = orderPosition, orderUseEntity = orderUseEntity))
  elif human_context_command__orderType == int(ContextCommand.ECC_BUILD)
    isOrdered = true
    send_net_event(personal_bot_order__currentBotEid, RequestPersonalSquadMateOrder(orderType = int(SquadMateOrder.ESMO_BUILD), orderPosition = float3(), orderUseEntity = human_context_command__orderUseEntity))
  elif human_context_command__orderType == int(ContextCommand.ECC_ATTACK_TARGET)
    let orderType = SquadMateOrder.ESMO_ATTACK_TARGET
    let orderUseEntity = human_context_command__orderUseEntity
    if orderUseEntity != INVALID_ENTITY_ID
      isOrdered = true
      send_net_event(personal_bot_order__currentBotEid, RequestPersonalSquadMateOrder(orderType = int(orderType), orderPosition = float3(), orderUseEntity = orderUseEntity))
  elif human_context_command__orderType == int(ContextCommand.ECC_PLANT_BOMB)
    send_net_event(personal_bot_order__currentBotEid, RequestPersonalSquadMateOrder(
      orderType = int(SquadMateOrder.ESMO_PLANT_BOMB),
      orderPosition = human_context_command__orderPosition,
      orderUseEntity = human_context_command__orderUseEntity
    ))
  elif human_context_command__orderType == int(ContextCommand.ECC_DEFUSE_BOMB)
    send_net_event(personal_bot_order__currentBotEid, RequestPersonalSquadMateOrder(
      orderType = int(SquadMateOrder.ESMO_DEFUSE_BOMB),
      orderPosition = human_context_command__orderPosition,
      orderUseEntity = human_context_command__orderUseEntity
    ))
  else
    sendEvent(eid, RqContextCommand())

  if isOrdered
    personal_bot_order__currentBotEid = find_spare_bot_for_personal_order(eid, squad_member__squad, personal_bot_order__currentBotEid)

[es(tag=gameClient, REQUIRE_NOT=hero)]
def human_personal_context_command_cancel_req(evt : RqCancelPersonalContextCommand;
                                              eid : EntityId;
                                              squad_member__squad : EntityId;
                                              squad_member__isPersonalOrder : bool)
  if squad_member__isPersonalOrder
    send_net_event(eid, RequestPersonalSquadMateOrder(orderType = int(SquadMateOrder.ESMO_NO_ORDER), orderPosition = float3(), orderUseEntity = INVALID_ENTITY_ID))
    send_net_event(eid, CmdHeroLogEvent(event = "squad_order_canceled", text = "context_command/personal_order_canceled"))
  query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
    query(squad__leader) <| $ [es] (var personal_bot_order__currentBotEid : EntityId&)
      personal_bot_order__currentBotEid = find_next_bot_for_personal_order(squad__leader, squad_member__squad, personal_bot_order__currentBotEid)

[es(tag=gameClient, REQUIRE=hero)]
def human_personal_context_command_cancel_hero(evt : RqCancelPersonalContextCommand;
                                               eid : EntityId;
                                               squad_member__squad : EntityId;
                                               var personal_bot_order__currentBotEid : EntityId&)
  query(personal_bot_order__currentBotEid) <| $ [es] (squad_member__isPersonalOrder : bool)
    if squad_member__isPersonalOrder
      send_net_event(personal_bot_order__currentBotEid, RequestPersonalSquadMateOrder(orderType = int(SquadMateOrder.ESMO_NO_ORDER), orderPosition = float3(), orderUseEntity = INVALID_ENTITY_ID))
      send_net_event(personal_bot_order__currentBotEid, CmdHeroLogEvent(event = "squad_order_canceled", text = "context_command/personal_order_canceled"))
    personal_bot_order__currentBotEid = find_next_bot_for_personal_order(eid, squad_member__squad, personal_bot_order__currentBotEid)
