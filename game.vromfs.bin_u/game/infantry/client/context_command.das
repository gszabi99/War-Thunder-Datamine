require ecs
require DagorMath
require Dacoll
require math.base
require %game.events

require %appGame.wt_events
require %appGame.infantry.input.human_context_command_point_common
require %appGame.infantry.input.human_context_command_camera_common
require %appGame.infantry.es.context_command_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require net

def get_alive_num_in_squad(squad_eid : EntityId) : int
  return get_int(squad_eid, "squad__numAliveMembers") ?? 0

[es(tag=gameClient, REQUIRE=human_context_command_input, no_order)]
def human_pre_context_command(act : ParallelUpdateFrameDelayed; squad_member__squad : EntityId; isInVehicle : bool;
                              human_context_command__nextUpdateTime : float;
                              human_context_command__pointOrder : int;
                              var human_context_command__orderType : int&)
  if act.curTime >= human_context_command__nextUpdateTime
    if !isInVehicle && get_alive_num_in_squad(squad_member__squad) > 1
      human_context_command__orderType = int(ContextCommand.ECC_NONE)
    else
      human_context_command__orderType = int(ContextCommand.ECC_DISABLED)

    if human_context_command__pointOrder > int(HumanPointOrderType.NOT_POINT_ORDER)
      human_context_command__orderType = int(ContextCommand.ECC_END_POINT_ORDER)

[es(tag=gameClient, REQUIRE=human_context_command_input, after=human_context_command_point_order)]
def human_post_context_command(act : ParallelUpdateFrameDelayed;
                               human_context_command__updateInterval : float;
                               var human_context_command__nextUpdateTime : float&)
  if act.curTime >= human_context_command__nextUpdateTime
    human_context_command__nextUpdateTime = act.curTime + human_context_command__updateInterval


[es(tag=gameClient, REQUIRE=human_context_command_input, after=human_pre_context_command)]
def human_revive_context_command(act : ParallelUpdateFrameDelayed; isDowned, isAlive : bool;
                                 human_context_command__nextUpdateTime : float;
                                 var human_context_command__orderType : int&)
  if act.curTime >= human_context_command__nextUpdateTime && human_context_command__orderType == int(ContextCommand.ECC_NONE)
    if isAlive && isDowned
      human_context_command__orderType = int(ContextCommand.ECC_REVIVE)















def is_valid_contruction_command_target(eid : EntityId)
  return has(eid, "buildByPlayer") && (has(eid, "builder_preview") || has(eid, "building_destroy__timeToDestroy"))

[es(tag=gameClient, REQUIRE=human_context_command_input)] 
def human_context_command_construction(act : ParallelUpdateFrameDelayed;
                                       human_context_command__nextUpdateTime : float;
                                       human_use_object__selectedBuilding : EntityId;
                                       var human_context_command__orderType : int&;
                                       var human_context_command__orderUseEntity : EntityId&)
  if act.curTime >= human_context_command__nextUpdateTime && human_context_command__orderType == int(ContextCommand.ECC_NONE)
    if is_valid_contruction_command_target(human_use_object__selectedBuilding)
      human_context_command__orderType = int(ContextCommand.ECC_BUILD)
      human_context_command__orderUseEntity = human_use_object__selectedBuilding

[es(tag=gameClient, REQUIRE=human_context_command_input, after=human_context_command_construction, after=human_weap_update_es, REQUIRE=watchedByPlr)]
def human_context_command_point_order(act : ParallelUpdateFrameDelayed;
                                      eid aka human_eid : EntityId;
                                      human_context_command__pointOrder : int;
                                      human_context_command__nextUpdateTime : float;
                                      var human_context_command__orderType : int&;
                                      var human_context_command__orderPosition : float3&;
                                      var human_context_command__orderUseEntity : EntityId&)
                                      
                                      
  if act.curTime >= human_context_command__nextUpdateTime && human_context_command__orderType == int(ContextCommand.ECC_NONE)
    var tracePos, traceDir : float3
    if !get_human_context_command_trace_pos_dir(human_eid, tracePos, traceDir)
      return

    
    
    
    
    
    
    
    
    
    
    
    
    

    var new_orderPosition : float3
    let activeTracing = false
    query() <| $ [es(REQUIRE=human_context_point_order_common)] (var trace_mesh_faces : TraceMeshFaces?)
      if !trace_human_context_command_order_pos(new_orderPosition, human_eid, tracePos, traceDir, activeTracing, trace_mesh_faces)
        return

    if human_context_command__pointOrder <= int(HumanPointOrderType.NOT_POINT_ORDER)
      human_context_command__orderType = int(ContextCommand.ECC_START_POINT_OVERWATCH_ORDER)
      human_context_command__orderUseEntity = INVALID_ENTITY_ID
      human_context_command__orderPosition = new_orderPosition


[es(tag=gameClient, REQUIRE=human_context_command_input, after=human_context_command_construction, after=human_weap_update_es, REQUIRE=watchedByPlr)]
def human_context_command_point_order_stop(act : ParallelUpdateFrameDelayed; eid aka human_eid : EntityId;
                                           human_context_command__pointOrder : int;
                                           human_context_command__pointOrderTimeout : float;
                                           human_context_command__nextUpdateTime : float;
                                           human_context_command__orderType : int)
  if human_context_command__pointOrder <= int(HumanPointOrderType.NOT_POINT_ORDER)
    return
  if act.curTime < human_context_command__pointOrderTimeout
    if human_context_command__orderType == int(ContextCommand.ECC_NONE)
      return
    if human_context_command__orderType == int(ContextCommand.ECC_END_POINT_ORDER)
      return
    if human_context_command__orderType == int(ContextCommand.ECC_START_POINT_OVERWATCH_ORDER)
      return
    if act.curTime < human_context_command__nextUpdateTime
      return
  human_point_order_cancel(human_eid)

[es(tag=gameClient, on_disappear)]
def human_context_command_point_order_off(evt : Event; var human_context_command__pointObjEid : EntityId&)
  destroyEntity(human_context_command__pointObjEid)
  human_context_command__pointObjEid = INVALID_ENTITY_ID

[es(tag=gameClient, no_order)]
def human_context_command_point_order_update(info : UpdateStageInfoAct; eid aka human_eid : EntityId;
                                             personal_bot_order__currentBotEid : EntityId;
                                             human_context_command__pointOrder : int)
  if human_context_command__pointOrder <= int(HumanPointOrderType.NOT_POINT_ORDER)
    return
  if human_point_order_update(human_eid, personal_bot_order__currentBotEid)
    human_point_order_obj_update(human_eid)

[es(tag=gameClient, no_order)]
def human_context_command_point_order_anim(info : UpdateStageInfoAct; eid : EntityId;
                                           squad_point_animator__objectEid : EntityId;
                                           squad_point_animator__sourcePos : float3;
                                           squad_point_animator__targetPos : float3;
                                           squad_point_animator__animTime : float2)
  let endTime = squad_point_animator__animTime.x + squad_point_animator__animTime.y
  if info.curTime > endTime
    destroyEntity(squad_point_animator__objectEid)
    destroyEntity(eid)
    return
  query(squad_point_animator__objectEid) <| $ [es] (var transform : float3x4&)
    let ratio = cvt(info.curTime, squad_point_animator__animTime.x, endTime, 0.0, 1.0)
    let ratio2 = clamp(ratio < 0.5 ? (ratio * 2.0) : (1.0 - (ratio - 0.5) * 2.0), 0.0, 1.0)
    transform[3] = lerp(squad_point_animator__sourcePos, squad_point_animator__targetPos, ratio2)





























































[es(tag=gameClient, REQUIRE=human_context_command_input)]
def human_context_command_req(evt : RqContextCommand; eid, squad_member__squad : EntityId;
                              human_context_command__calledForHelp : bool;
                              human_context_command__orderType : int;
                              human_context_command__orderPosition : float3;
                              human_context_command__orderUseEntity : EntityId)
  if human_context_command__orderType == int(ContextCommand.ECC_CANCEL)
    send_net_event(squad_member__squad, RequestSquadOrder(orderType = SquadOrder.ESO_FOLLOW_ME, orderPosition = float3(), orderUseEntity = INVALID_ENTITY_ID))
  elif human_context_command__orderType == int(ContextCommand.ECC_DEFEND_POINT)
    var orderType = SquadOrder.ESO_DEFEND_POINT
    var orderPosition = human_context_command__orderPosition
    let orderUseEntity = human_context_command__orderUseEntity
    if orderUseEntity != INVALID_ENTITY_ID
      let targetTM = get_TMatrix(orderUseEntity, "transform")
      if targetTM != null
        orderPosition = (*targetTM)[3]
      if has(orderUseEntity, "vehicle_seats__seats")
        orderType = SquadOrder.ESO_USE_VEHICLE
    send_net_event(squad_member__squad, RequestSquadOrder(orderType = orderType, orderPosition = orderPosition, orderUseEntity = orderUseEntity))
  elif human_context_command__orderType == int(ContextCommand.ECC_REVIVE)
    send_net_event(squad_member__squad, RequestSquadMateOrder(orderType = SquadMateOrder.ESMO_HEAL, orderPosition = float3(), orderUseEntity = INVALID_ENTITY_ID))
  elif human_context_command__orderType == int(ContextCommand.ECC_BUILD)
    send_net_event(squad_member__squad, RequestSquadMateOrder(orderType = SquadMateOrder.ESMO_BUILD, orderPosition = float3(), orderUseEntity = human_context_command__orderUseEntity))
  elif human_context_command__orderType == int(ContextCommand.ECC_PLANT_BOMB)
    send_net_event(squad_member__squad, RequestSquadMateOrder(
      orderType = SquadMateOrder.ESMO_PLANT_BOMB,
      orderPosition = human_context_command__orderPosition,
      orderUseEntity = human_context_command__orderUseEntity
    ))
  elif human_context_command__orderType == int(ContextCommand.ECC_DEFUSE_BOMB)
    send_net_event(squad_member__squad, RequestSquadMateOrder(
      orderType = SquadMateOrder.ESMO_DEFUSE_BOMB,
      orderPosition = human_context_command__orderPosition,
      orderUseEntity = human_context_command__orderUseEntity
    ))
  elif human_context_command__orderType == int(ContextCommand.ECC_ATTACK_TARGET)
    let orderType = SquadMateOrder.ESMO_ATTACK_TARGET
    var orderPosition = human_context_command__orderPosition
    let orderUseEntity = human_context_command__orderUseEntity
    if orderUseEntity != INVALID_ENTITY_ID
      let targetTM = get_TMatrix(orderUseEntity, "transform")
      if targetTM != null
        orderPosition = (*targetTM)[3]
    send_net_event(squad_member__squad, RequestSquadMateOrder(orderType = orderType, orderPosition = orderPosition, orderUseEntity = orderUseEntity))
  elif human_context_command__orderType == int(ContextCommand.ECC_DISABLED) && get_alive_num_in_squad(squad_member__squad) <= 1
    if !human_context_command__calledForHelp
      send_net_event(eid, CmdHeroLogEvent(event = "squad_order_canceled", text = "context_command/no_alive_squadmates"))

[es(tag=gameClient, REQUIRE=human_context_command_input)]
def human_context_command_all_cancel_req(evt : RqCancelContextCommand; eid, squad_member__squad : EntityId)
  let squadEid = squad_member__squad
  var hasGlobalOrder = false
  query(squad_member__squad) <| $ [es] (squad__orderType : int)
    hasGlobalOrder = squad__orderType != int(SquadOrder.ESO_FOLLOW_ME)
  var hasOrder = hasGlobalOrder
  if !hasOrder && evt.include_personal_orders
    find_query() <| $ [es] (squad_member__squad : EntityId; isAlive : bool; squad_member__orderType : int)
      hasOrder = squadEid == squad_member__squad && isAlive && squad_member__orderType != int(SquadOrder.ESO_FOLLOW_ME)
      return hasOrder
  if hasGlobalOrder
    send_net_event(squad_member__squad, RequestSquadOrder(orderType = SquadOrder.ESO_FOLLOW_ME, orderPosition = float3(), orderUseEntity = INVALID_ENTITY_ID))
  if evt.include_personal_orders
    send_net_event(squad_member__squad, RequestSquadMateOrder(orderType = SquadMateOrder.ESMO_NO_ORDER, orderPosition = float3(), orderUseEntity = INVALID_ENTITY_ID))
  if hasOrder
    send_net_event(eid, CmdHeroLogEvent(event = "squad_order_canceled", text = "context_command/all_orders_canceled"))


def private human_context_command_menu_pos_order_trace_and_start(human_eid : EntityId; order_type : int; def_pos : float3)
  var traced = HumanPointOrderTraced()
  if !human_point_order_trace(human_eid, order_type, traced)
    traced.pos = def_pos
  human_point_order_start(human_eid, traced.pos, traced.kind, traced.eid, order_type, INVALID_ENTITY_ID)

def private human_context_command_menu_send_throw_grenade_ctx_order(human_eid : EntityId; order_type : SquadOrder)
  var grenadePos = float3()
  var grenadeDir = float3()
  var grenadeAltPos = float3()
  if human_context_command_menu_trace_throw_grenade(human_eid, grenadePos, grenadeDir, grenadeAltPos)
    query(human_eid) <| $ [es] (squad_member__squad : EntityId)
      send_net_event(squad_member__squad, RequestSquadOrder(orderType = order_type, orderPosition = grenadePos, orderDirection = grenadeDir, orderAltPosition = grenadeAltPos))
  else
    send_net_event(human_eid, CmdHeroLogEvent(event = "squad_order_canceled", text = "squad_orders/failed_to_determine_point_to_throw_grenade"))

def private human_context_command_menu_send_attack_vehicle_ctx_order(human_eid : EntityId; order_type : SquadOrder)
  query(human_eid) <| $ [es] (human_context_command__menuCtxEid : EntityId;
                              squad_member__squad : EntityId)
    send_net_event(squad_member__squad, RequestSquadOrder(orderType = order_type, orderUseEntity = human_context_command__menuCtxEid))

[es(tag=gameClient, REQUIRE=human_context_command_input)]
def human_context_command_point_order_req(evt : RqContextCommandPointOrder;
                                          eid : EntityId;
                                          transform : float3x4;
                                          squad_member__squad : EntityId;
                                          human_context_command__pointOrder : int;
                                          human_context_command__pointOrderPos : float3;
                                          human_context_command__pointOrderDir : float3)
  let orderType = human_context_command__pointOrder

  if orderType != int(HumanPointOrderType.NOT_POINT_ORDER)
    if evt.pointOrderStrID == "accept" && is_human_point_order_await_shoot_accept(orderType)
      human_point_order_complete_simple(eid)
      let orderPos = human_context_command__pointOrderPos
      let orderDir = human_context_command__pointOrderDir
      if orderType == int(HumanPointOrderType.POINT_THROW_FRAG_GRENADE)
        send_net_event(squad_member__squad, RequestSquadOrder(orderType = SquadOrder.ESO_AUTO_THROW_FRAG_GRENADE, orderPosition = orderPos, orderDirection = orderDir))
      elif orderType == int(HumanPointOrderType.POINT_THROW_SMOKE_GRENADE)
        send_net_event(squad_member__squad, RequestSquadOrder(orderType = SquadOrder.ESO_AUTO_THROW_SMOKE_GRENADE, orderPosition = orderPos, orderDirection = orderDir))
      elif orderType == int(HumanPointOrderType.POINT_THROW_FLASH_GRENADE)
        send_net_event(squad_member__squad, RequestSquadOrder(orderType = SquadOrder.ESO_AUTO_THROW_FLASH_GRENADE, orderPosition = orderPos, orderDirection = orderDir))
      else
        error("Human point order type {orderType} not supported in accept handler.")
      return
    human_point_order_cancel(eid)
    return

  if evt.pointOrderStrID == "frag_grenade_ctx"
    human_context_command_menu_send_throw_grenade_ctx_order(eid, SquadOrder.ESO_AUTO_THROW_FRAG_GRENADE)
    return
  if evt.pointOrderStrID == "smoke_grenade_ctx"
    human_context_command_menu_send_throw_grenade_ctx_order(eid, SquadOrder.ESO_AUTO_THROW_SMOKE_GRENADE)
    return
  if evt.pointOrderStrID == "flash_grenade_ctx"
    human_context_command_menu_send_throw_grenade_ctx_order(eid, SquadOrder.ESO_AUTO_THROW_FLASH_GRENADE)
    return

  if evt.pointOrderStrID == "frag_grenade"
    human_context_command_menu_pos_order_trace_and_start(eid, int(HumanPointOrderType.POINT_THROW_FRAG_GRENADE), transform[3])
    return
  if evt.pointOrderStrID == "smoke_grenade"
    human_context_command_menu_pos_order_trace_and_start(eid, int(HumanPointOrderType.POINT_THROW_SMOKE_GRENADE), transform[3])
    return
  if evt.pointOrderStrID == "flash_grenade"
    human_context_command_menu_pos_order_trace_and_start(eid, int(HumanPointOrderType.POINT_THROW_FLASH_GRENADE), transform[3])
    return

  if evt.pointOrderStrID == "attack_vehicle"
    human_context_command_menu_send_attack_vehicle_ctx_order(eid, SquadOrder.ESO_AUTO_ATTACK_VEHICLE)
    return

[es(tag=gameClient, REQUIRE=human_context_command_input)]
def human_context_command_point_order_menu_req(evt : RqMenuContextCommandPointOrder;
                                               eid : EntityId)
  human_context_command_menu_init_context(eid)
  sendEvent(eid, RqContextCommandPointOrder(pointOrderStrID = evt.pointOrderStrID))

[es(tag=gameClient, REQUIRE=(human_context_command_input, watchedByPlr))]
def human_context_command_point_order_update_context(act : ParallelUpdateFrameDelayed;
                                                     eid : EntityId;
                                                     human_weap__traceIntersectedEid : EntityId;
                                                     human_context_command__menuCtxEid : EntityId;
                                                     human_context_command__ctxLastTracedStableTime : float;
                                                     human_context_command__ctxLookPosStableTime : float;
                                                     human_context_command__ctxCheckRetraceConeAngle : float;
                                                     human_context_command__ctxDefaultTracedLookDist : float = 50.0f;
                                                     var human_context_command__ctxCheckRetraceLookPos : float3&;
                                                     var human_context_command__ctxContextTracedLookPos : float3&;
                                                     var human_context_command__hasContext : bool&;
                                                     var human_context_command__lastTracedEid : EntityId&;
                                                     var human_context_command__wasStableLastTracedEidAtInitContext : EntityId&;
                                                     var human_context_command__ctxLastTracedStableTimer : float&;
                                                     var human_context_command__ctxLookPosStableTimer : float&)
  var retrace = false
  if human_context_command__hasContext
    if human_context_command__lastTracedEid != human_weap__traceIntersectedEid
      human_context_command__ctxLastTracedStableTimer = 0.0
    else
      human_context_command__ctxLastTracedStableTimer += act.dt
    human_context_command__lastTracedEid = human_weap__traceIntersectedEid

    if human_context_command__ctxLastTracedStableTimer >= human_context_command__ctxLastTracedStableTime
      if human_context_command__menuCtxEid != human_context_command__lastTracedEid && human_context_command__lastTracedEid != human_context_command__wasStableLastTracedEidAtInitContext
        retrace = true

  var traceFromPos, traceDir : float3
  if !get_human_context_command_trace_pos_dir(eid, traceFromPos, traceDir)
    return
  if !retrace
    let coneAngleCos = cos(deg_to_rad(human_context_command__ctxCheckRetraceConeAngle))
    let lookPos = traceFromPos + traceDir

    if human_context_command__hasContext
      let contextDir = normalize(human_context_command__ctxContextTracedLookPos - traceFromPos)
      if dot(traceDir, contextDir) < coneAngleCos
        human_context_command__hasContext = false
        human_context_command__ctxCheckRetraceLookPos = lookPos
        human_context_command__ctxLookPosStableTimer = 0.0

    if !human_context_command__hasContext
      if human_context_command__ctxCheckRetraceLookPos == float3() || dot(human_context_command__ctxCheckRetraceLookPos - traceFromPos, traceDir) < coneAngleCos
        human_context_command__ctxCheckRetraceLookPos = lookPos
        human_context_command__ctxLookPosStableTimer = 0.0
      else
        human_context_command__ctxLookPosStableTimer += act.dt
        if human_context_command__ctxLookPosStableTimer >= human_context_command__ctxLookPosStableTime
          retrace = true

  if retrace
    human_context_command_menu_init_context(eid)
    retrace = false
    human_context_command__hasContext = true
    var dist = human_context_command__ctxDefaultTracedLookDist
    query(eid) <| $ [es] (human_context_command__menuCtxPos : float3)
      dist = human_context_command__menuCtxPos == float3() ? human_context_command__ctxDefaultTracedLookDist : distance(human_context_command__menuCtxPos, traceFromPos)
    human_context_command__ctxContextTracedLookPos = traceFromPos + traceDir * dist
    if human_context_command__ctxLastTracedStableTimer >= human_context_command__ctxLastTracedStableTime
      human_context_command__wasStableLastTracedEidAtInitContext = human_context_command__lastTracedEid
    else
      human_context_command__wasStableLastTracedEidAtInitContext = INVALID_ENTITY_ID
