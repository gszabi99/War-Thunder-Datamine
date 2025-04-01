require ecs
require ecs.safe
require ecs.common
require app
require DagorSystem
require AnimV20
require CollRes



require %appGame.es.spawn_soldier_common






def get_sync_time() 
  return float(get_app().usefulTotalTime)

require GeomNodeTree
require DagorMath
def get_seat_attach_tm(seat_eid : EntityId;
                       animchar : AnimcharBaseComponent;
                       collres : CollisionResource;
                       transform : float3x4;
                       var out_tm : float3x4)
  var res = false
  query(seat_eid) <| $ [es] (seats_attach_nodes__nodeId : int;
                             seats_attach_nodes__collNodeId : int;
                             seats_attach_nodes__ignoreAttachNodeRotation : bool;
                             seats_attach_nodes__nodeItm : float3x4;
                             seats_attach_nodes__attachTm : float3x4)
    if seats_attach_nodes__nodeId >= 0
      geomtree_getNodeWtmScalar(*animchar.nodeTree, seats_attach_nodes__nodeId, out_tm)
    elif seats_attach_nodes__collNodeId >= 0
      collres_get_collision_node_tm(collres, seats_attach_nodes__collNodeId,
                                    transform, null, out_tm)
    else
      out_tm = transform

    if seats_attach_nodes__ignoreAttachNodeRotation
      let nodePos = out_tm[3]
      out_tm = out_tm * seats_attach_nodes__nodeItm
      out_tm[3] = nodePos
    elif det(out_tm) < 0.0f
      orthonormalize(out_tm)

    out_tm = out_tm * seats_attach_nodes__attachTm
    res = true
  return res

[event(unicast)]
struct SoldierSpawnEquipmentCreated {}

[event(unicast)]
struct FinalizeSoldierCreation
  spawnerEid : EntityId

[cpp_event(unicast)]
struct CmdEquipItemDirect
  itemEid : ecs::EntityId
  slot : string
  allowReorderSlots : bool
  dropPrevItem : bool

let
  RECURSIVE = true
  NON_RECURSIVE = false

def create_additional_equipment(item_eid : EntityId; spawner_eid : EntityId; use_vehicle : bool)
  var equipmentLeftToCreate = 0
  query(item_eid) <| $ [es] (item__additionalSlotTemplates : Object)
    using() <| $(var subequipment : Object)
      for it in item__additionalSlotTemplates
        let subitemTemplate = it.value ?? ""
        subequipment |> set(subitemTemplate, it.key)
        using() <| $(var emptyObj : Object)
          equipmentLeftToCreate += create_equipment(spawner_eid, subequipment, emptyObj, use_vehicle, NON_RECURSIVE)
  return equipmentLeftToCreate

def create_equipment(spawner_eid : EntityId; equipment : Object; equipment_components : Object; use_vehicle : bool; is_recursive : bool)
  var equipmentToCreateCount = 0
  for kv in equipment
    let gametempate = kv.key
    let slot := get_string(kv.value, "")

    let itemTemplate = get_item_template_for_equipment(gametempate, use_vehicle)
    if empty(itemTemplate)
      continue
    equipmentToCreateCount++

    let finalizeCreation <- @ <| (itemEid : EntityId)
      query(spawner_eid) <| $ [es] (var equipmentEids : Object; var equipmentLeftToCreate : int&)
        set(equipmentEids, slot, itemEid)
        equipmentLeftToCreate -= 1
        if is_recursive
          equipmentLeftToCreate += create_additional_equipment(itemEid, spawner_eid, use_vehicle)
        if equipmentLeftToCreate <= 0
          sendEvent(spawner_eid, [[SoldierSpawnEquipmentCreated]])

    createEntity(itemTemplate, finalizeCreation) <| $(var init : ComponentsInitializer)
      let components = get_ecs_object(equipment_components, gametempate)
      if components != null
        let tpl = getTemplateByName(gametempate)
        for comp in *components
          let keyHash = ecs_hash(comp.key)
          if tpl != null && templateHasComponent(*tpl, comp.key, keyHash)
            set(init, comp.key, keyHash, comp.value)
  return equipmentToCreateCount

[es(tag=server, on_appear)]
def spawn_soldier(evt : Event;
                  eid : EntityId;
                  useVehicle : EntityId = INVALID_ENTITY_ID;
                  var soldierComponents : Object;
                  var equipmentLeftToCreate : int&)
  var equipmentPtr = getRW_ecs_object(soldierComponents, "human_equipment__initialEquip")
  assume equipment = *equipmentPtr
  var equipmentComponentsPtr = getRW_ecs_object(soldierComponents, "human_equipment__initialEquipComponents")
  assume equipmentComponents = *equipmentComponentsPtr

  equipmentLeftToCreate = length(equipment)
  equipmentLeftToCreate = create_equipment(eid, equipment, *equipmentComponentsPtr, !!useVehicle, RECURSIVE)

  clear(equipment)
  clear(equipmentComponents)

def init_item_container(eid)
  ecs::query(eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (var item__lastOwner : EntityId&; var item__ownerEid : EntityId&)
        item__lastOwner = eid
        item__ownerEid = eid

[es(tag=server, on_event=SoldierSpawnEquipmentCreated, REQUIRE=soldierComponents)]
def spawn_soldier_done(evt : Event;
                       eid : EntityId;
                       soldierTemplate : string;
                       soldierComponents : Object const?) 
  let spawnerEid = eid
  let finalizeCreation <- @ <| (soldierEid : EntityId)
    
    query(spawnerEid) <| $ [es] (equipmentEids : Object;
                                 useVehicle : EntityId;
                                 soldierIndexInSquad : int;
                                 squadEid : EntityId;
                                 playerEid : EntityId)
      for item in equipmentEids
        let itemEid = *get_Eid(item.value)
        sendEventImmediate(soldierEid, [[CmdEquipItemDirect itemEid=itemEid, slot=item.key, allowReorderSlots=false, dropPrevItem=true]])
        ecs::query(itemEid) <| $ [es] (var skeleton_attach__attached : bool&;
                                       var slot_attach__attachedTo : EntityId&;
                                       var skeleton_attach__attachedTo : EntityId&)
          slot_attach__attachedTo = soldierEid
          skeleton_attach__attached = true
          skeleton_attach__attachedTo  = soldierEid
        ecs::query(itemEid) <| $ [es] (footprintType : int)
          let itemFootprintType = footprintType
          ecs::query(soldierEid) <| $ [es] (var footprintType : int&)
            footprintType = itemFootprintType
      init_item_container(soldierEid)

      if !!useVehicle
        var seatsOffset = soldierIndexInSquad
        query(playerEid) <| $ [es] (respawner__mobileRespawnEid : EntityId)
          if respawner__mobileRespawnEid == useVehicle
            seatsOffset = -1
            query(useVehicle) <| $ [es] (var mobile_respawn__nextSpawnTimer : float&;
                                         var mobile_respawn__reservedPlayerEid : EntityId&;
                                         var active : bool&;
                                         vehicle_seats__seatEids : EidList;
                                         mobile_respawn__spawnCooldown : float)
              for seatNo in range(length(vehicle_seats__seatEids))
                query(vehicle_seats__seatEids[seatNo]) <| $ [es] (seat__ownerEid : EntityId; seat__isOwnerAlive : bool; seats_order__canPlaceOnlyOwner : bool = false)
                  if (!seat__ownerEid || !seat__isOwnerAlive) && !seats_order__canPlaceOnlyOwner
                    seatsOffset = seatNo
                if seatsOffset != -1
                  break
              mobile_respawn__nextSpawnTimer = get_sync_time() + mobile_respawn__spawnCooldown
              active = false
              if mobile_respawn__reservedPlayerEid == playerEid
                mobile_respawn__reservedPlayerEid = INVALID_ENTITY_ID
        if seatsOffset < 0
          let templ = getEntityTemplateName(useVehicle)
          logerr("No free seats in mobile respawn {templ}, player {playerEid}")
          return
        use_vehicle_on_spawn(soldierEid, squadEid, playerEid, useVehicle, seatsOffset)

  let baseTemplateName = split_template(soldierTemplate)[0]
  let tpl = getTemplateByName(baseTemplateName)
  let soldierEid : EntityId = createEntity(soldierTemplate, finalizeCreation) <| $(var init : ComponentsInitializer)
    if tpl == null || !init_soldier_tpl_deps(*tpl,  init, soldierComponents)
      logerr("Can't create a list of entities for instantiation for '{soldierTemplate}'")

    for comp in *soldierComponents
      let keyHash = ecs_hash(comp.key)
      if tpl != null && templateHasComponent(*tpl, comp.key, keyHash)
        set(init, comp.key, keyHash, comp.value)
  sendEvent(soldierEid, [[FinalizeSoldierCreation spawnerEid=eid]])














def use_vehicle_on_spawn(possessed : EntityId; squad : EntityId; player_eid : EntityId; vehicle : EntityId; seat_order_no : int)
  query(vehicle) <| $ [es] (vehicle_seats__seatEids : EidList;
                            animchar : AnimcharBaseComponent;
                            collres : CollisionResource;
                            transform aka vehicle_transform : float3x4)
    if seat_order_no >= length(vehicle_seats__seatEids)
      logerr("Seats order index is out of range ({seat_order_no} >= {length(vehicle_seats__seatEids)})")
      return

    var isPlayer = false
    let seatNo = get_int(vehicle_seats__seatEids[seat_order_no], "seats_order__seatNo") ?? -1
    query(possessed) <| $ [es] (possessedByPlr : ecs::EntityId;
                                var transform aka human_transform : float3x4&;
                                var isInVehicle : bool&;
                                var disable_collision : bool&;
                                var human_anim__vehicleSelected : ecs::EntityId&;
                                var human_vehicle__occupiedSeatEid : ecs::EntityId&;
                                var human_vehicle__lastKnownSeatEid : ecs::EntityId?;
                                var vehicle__lastEid : ecs::EntityId&;
                                var vehicle__lastTime : float&;
                                var vehicle__localSeatTm : float3x4&;
                                var vehicle__globalSeatTm : float3x4&)
      if seatNo >= 0
        human_vehicle__occupiedSeatEid = vehicle_seats__seatEids[seatNo]
        if human_vehicle__lastKnownSeatEid != null
          *human_vehicle__lastKnownSeatEid = human_vehicle__occupiedSeatEid
        if get_seat_attach_tm(human_vehicle__occupiedSeatEid, animchar, collres, vehicle_transform, vehicle__globalSeatTm)
          let inverseTm = inverse(vehicle_transform);
          vehicle__localSeatTm = inverseTm * vehicle__globalSeatTm
          human_transform = vehicle__globalSeatTm

      isPlayer = possessedByPlr != INVALID_ENTITY_ID
      isInVehicle = true
      disable_collision = true
      human_anim__vehicleSelected = vehicle
      vehicle__lastEid = vehicle
      vehicle__lastTime = get_sync_time()

    if seatNo < 0
      return

    query(vehicle_seats__seatEids[seatNo]) <| $ [es] (seat__component : int;
                                                      var seat__isPlayer : bool&;
                                                      var seat__isOwnerAlive : bool&;
                                                      var seat__ownerEid : EntityId&;
                                                      var seat__playerEid : EntityId&;
                                                      var seat__squadEid : EntityId&)
      set(possessed, "", uint(seat__component), true)
      seat__isOwnerAlive = true
      seat__isPlayer = isPlayer
      seat__ownerEid = possessed
      seat__playerEid = player_eid
      seat__squadEid = squad




